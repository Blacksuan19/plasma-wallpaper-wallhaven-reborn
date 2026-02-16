/*
    SPDX-FileCopyrightText: 2013 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2014 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2014 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2022 Link Dupont <link@sub-pop.net>
    SPDX-FileCopyrightText: 2024 Abubakar Yagoub <plasma@aolabs.dev>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import Qt.labs.platform 1.1 as Platform // For StandardPaths
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Window
import org.kde.kirigami 2.20 as Kirigami
import org.kde.notification 1.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasmoid

WallpaperItem {
    id: main

    property url currentUrl
    property int currentPage: 1
    property int currentIndex
    property int currentSearchTermIndex: -1
    readonly property int fillMode: main.configuration.FillMode
    readonly property bool refreshSignal: main.configuration.RefetchSignal
    readonly property string sorting: main.configuration.Sorting
    readonly property int retryRequestCount: main.configuration.RetryRequestCount
    readonly property int retryRequestDelay: main.configuration.RetryRequestDelay
    readonly property size sourceSize: Qt.size(main.width * Screen.devicePixelRatio, main.height * Screen.devicePixelRatio)
    property Item pendingImage
    readonly property string lastValidImagePath: main.configuration.lastValidImagePath || ""
    readonly property string userAgent: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
    property bool isLoading: false
    property string lastLoadedUrl: ""
    readonly property bool systemDarkMode: Kirigami.Theme.textColor.hsvValue > Kirigami.Theme.backgroundColor.hsvValue
    readonly property bool followSystemTheme: main.configuration.FollowSystemTheme

    function log(msg) {
        console.log(`Wallhaven Wallpaper: ${msg}`);
    }

    function isHttpUrl(url) {
        return url.toString().startsWith("http");
    }

    function loadFallbackImage() {
        if (lastValidImagePath !== "") {
            log("Using last valid cached image");
            main.currentUrl = lastValidImagePath;
        } else {
            main.currentUrl = "blackscreen.jpg";
        }
        loadImage();
    }

    function fetchFromWallhaven(reason) {
        log("Fetching from Wallhaven: " + reason);
        if (main.configuration.RefreshNotification)
            showNotification("Wallhaven Wallpaper", reason, "plugin-wallpaper");

        main.configuration.ShownSavedWallpapers = [];
        wallpaper.configuration.writeConfig();
        getImageData(main.retryRequestCount).then((data) => {
            pickImage(data);
        }).catch((e) => {
            log("getImageData Error: " + e);
            showNotification("Wallhaven Wallpaper Error", "Failed to fetch: " + e, "dialog-error", true);
            isLoading = false;
        });
    }

    function showNotification(title, text, iconName, isError) {
        const isErrorNotif = isError === true;
        if (isErrorNotif && !main.configuration.ErrorNotification)
            return ;

        if (!isErrorNotif && !main.configuration.RefreshNotification)
            return ;

        const note = notificationComponent.createObject(root, {
            "title": title,
            "text": text,
            "iconName": iconName
        });
        note.sendEvent();
    }

    function saveCurrentWallpaper() {
        if (!main.currentUrl || main.currentUrl.toString() === "" || main.currentUrl.toString() === "blackscreen.jpg") {
            showNotification("Wallhaven Wallpaper Error", "No valid wallpaper to save", "dialog-error", true);
            return ;
        }
        const urlString = main.currentUrl.toString();
        const thumbnailString = main.configuration.currentWallpaperThumbnail || "";
        // Store as "fullUrl|||thumbnailUrl" for fast preview loading
        const savedEntry = urlString + "|||" + thumbnailString;
        let currentList = main.configuration.SavedWallpapers || [];
        // Check if already saved (check both old format and new format)
        const alreadySaved = currentList.some((entry) => {
            return entry === urlString || entry.startsWith(urlString + "|||");
        });
        if (alreadySaved) {
            showNotification("Wallhaven Wallpaper Error", "Wallpaper already saved", "dialog-error", true);
            return ;
        }
        let newList = currentList.slice();
        newList.push(savedEntry);
        main.configuration.SavedWallpapers = newList;
        wallpaper.configuration.writeConfig();
        log("Saved wallpaper: " + urlString);
        showNotification("Wallhaven Wallpaper", "Wallpaper saved! Total: " + newList.length, "plugin-wallpaper", false);
    }

    function loadFromSavedWallpapers() {
        const savedList = main.configuration.SavedWallpapers || [];
        if (savedList.length === 0) {
            showNotification("Wallhaven Wallpaper", "No saved wallpapers found. Fetching from Wallhaven...", "plugin-wallpaper", false);
            getImageData(main.retryRequestCount).then((data) => {
                pickImage(data);
            }).catch((e) => {
                log("getImageData Error: " + e);
                showNotification("Wallhaven Wallpaper Error", "Failed to fetch: " + e, "dialog-error", true);
                loadFallbackImage();
                isLoading = false;
            });
            return ;
        }
        let shownList = main.configuration.ShownSavedWallpapers || [];
        if (shownList.length >= savedList.length) {
            // Continue execution to pick from saved list

            if (main.configuration.CycleSavedWallpapers) {
                // Cycle is enabled: reset and continue with saved wallpapers
                showNotification("Wallhaven Wallpaper", "Restarting saved wallpapers cycle", "plugin-wallpaper", false);
                main.configuration.ShownSavedWallpapers = [];
                wallpaper.configuration.writeConfig();
                shownList = [];
            } else {
                // Cycling disabled: fetch new from Wallhaven
                fetchFromWallhaven("All " + savedList.length + " saved wallpapers shown. Fetching new from Wallhaven...");
                return ;
            }
        }
        // Find unshown wallpapers
        let unshownWallpapers = savedList.filter((entry) => {
            return shownList.indexOf(entry) === -1;
        });
        let availableWallpapers = unshownWallpapers.filter((entry) => {
            // Parse entry to get full URL (backward compatible)
            const fullUrl = entry.includes("|||") ? entry.split("|||")[0] : entry;
            return fullUrl !== lastLoadedUrl;
        });
        // If no available wallpapers, try from all except current
        if (availableWallpapers.length === 0) {
            availableWallpapers = savedList.filter((entry) => {
                const fullUrl = entry.includes("|||") ? entry.split("|||")[0] : entry;
                return fullUrl !== lastLoadedUrl;
            });
            // Only one wallpaper exists
            if (availableWallpapers.length === 0) {
                if (main.configuration.CycleSavedWallpapers) {
                    // Just use the one wallpaper again
                    showNotification("Wallhaven Wallpaper", "Only one saved wallpaper available", "plugin-wallpaper", false);
                } else {
                    // Fetch new from Wallhaven
                    fetchFromWallhaven("Only one saved wallpaper. Fetching new from Wallhaven...");
                    return ;
                }
            }
            shownList = [];
        }
        // Select wallpaper (random or sequential based on shuffle setting)
        let selectedEntry;
        if (main.configuration.ShuffleSavedWallpapers) {
            // Random selection
            const randomIndex = Math.floor(Math.random() * availableWallpapers.length);
            selectedEntry = availableWallpapers[randomIndex];
        } else {
            // Sequential selection - use the first unshown wallpaper
            selectedEntry = availableWallpapers[0];
        }
        // Parse entry: "fullUrl|||thumbnailUrl" or just "fullUrl" (old format)
        const parts = selectedEntry.split("|||");
        const selectedUrl = parts[0];
        const thumbnailUrl = parts.length > 1 ? parts[1] : selectedUrl; // Fallback to full URL for old entries
        let newShownList = shownList.slice();
        newShownList.push(selectedEntry);
        main.configuration.ShownSavedWallpapers = newShownList;
        showNotification("Wallhaven Wallpaper", "Loading saved wallpaper " + newShownList.length + " of " + savedList.length, "plugin-wallpaper", false);
        main.currentUrl = selectedUrl;
        main.configuration.lastValidImagePath = selectedUrl;
        main.configuration.currentWallpaperThumbnail = thumbnailUrl;
        wallpaper.configuration.writeConfig();
        loadImage();
        isLoading = false;
    }

    function refreshImage() {
        if (isLoading) {
            log("Loading in progress - skipping refresh");
            return ;
        }
        isLoading = true;
        if (main.configuration.UseSavedWallpapers) {
            loadFromSavedWallpapers();
            return ;
        }
        getImageData(main.retryRequestCount).then((data) => {
            pickImage(data);
        }).catch((e) => {
            log("getImageData Error: " + e);
            showNotification("Wallhaven Wallpaper Error", "Failed to fetch: " + e, "dialog-error", true);
            loadFallbackImage();
            isLoading = false;
        });
    }

    function handleRequestError(retries, errorText, resolve, reject) {
        if (retries > 0) {
            let msg = `Retrying in ${main.retryRequestDelay} seconds...`;
            log(msg);
            showNotification("Wallhaven Wallpaper Error", msg, "dialog-error", true);
            retryTimer.retries = retries;
            retryTimer.resolve = resolve;
            retryTimer.reject = reject;
            retryTimer.start();
        } else {
            let msg = "Request failed" + (errorText ? ": " + errorText : "");
            showNotification("Wallhaven Wallpaper Error", msg, "dialog-error", true);
            reject(msg);
        }
    }

    function getImageData(retries) {
        return new Promise((res, rej) => {
            var url = `https://wallhaven.cc/api/v1/search?`;
            url += buildBinaryParameter("categories", ["CategoryGeneral", "CategoryAnime", "CategoryPeople"]) + "&";
            url += buildBinaryParameter("purity", ["PuritySFW", "PuritySketchy", "PurityNSFW"]) + "&";
            // sorting
            url += `sorting=${main.configuration.Sorting}&`;
            if (main.configuration.Sorting != "random")
                url += `page=${main.currentPage}&`;

            if (main.configuration.Sorting == "toplist")
                url += `topRange=${main.configuration.TopRange}&`;

            // dimensions
            url += `atleast=${main.configuration.ResolutionX}x${main.configuration.ResolutionY}&`;
            // Only filter colors if setting is ON and system is DARK
            if (main.configuration.FollowSystemTheme && systemDarkMode)
                url += "colors=000000,424153&";

            // Aspect ratios
            url += buildRatioParameter();
            // Query parameter
            url += buildQueryParameter();
            log('using url: ' + url);
            const xhr = new XMLHttpRequest();
            xhr.onload = () => {
                if (xhr.status != 200) {
                    handleRequestError(retries, xhr.responseText, res, rej);
                } else {
                    try {
                        let data = JSON.parse(xhr.responseText);
                        res(data);
                    } catch (e) {
                        let msg = "Invalid JSON response: " + xhr.responseText;
                        showNotification("Wallhaven Wallpaper Error", msg, "dialog-error", true);
                        rej(msg);
                    }
                }
            };
            xhr.onerror = () => {
                handleRequestError(retries, null, res, rej);
            };
            xhr.open('GET', url);
            xhr.setRequestHeader('X-API-Key', main.configuration.APIKey);
            xhr.setRequestHeader('User-Agent', 'wallhaven-wallpaper-kde-plugin');
            xhr.timeout = 5000;
            xhr.send();
        });
    }

    function buildBinaryParameter(paramName, configKeys) {
        let result = "";
        for (let i = 0; i < configKeys.length; i++) {
            result += main.configuration[configKeys[i]] ? "1" : "0";
        }
        return `${paramName}=${result}`;
    }

    function buildRatioParameter() {
        if (main.configuration.RatioAny)
            return "";

        var ratios = [];
        if (main.configuration.Ratio169)
            ratios.push("16x9");

        if (main.configuration.Ratio1610)
            ratios.push("16x10");

        if (main.configuration.RatioCustom)
            ratios.push(main.configuration.RatioCustomValue);

        return ratios.length > 0 ? `ratios=${ratios.join(',')}&` : "";
    }

    // Helper function to build query parameter
    function buildQueryParameter() {
        var user_q = main.configuration.Query;
        let qs = user_q.split(",");
        // select a random query from the array
        let term_index = Math.floor(Math.random() * qs.length);
        // avoid repeating the same query
        if (term_index == main.currentSearchTermIndex)
            term_index = (term_index + 1) % qs.length;

        main.currentSearchTermIndex = term_index;
        let final_q = qs[term_index].trim();
        if (main.configuration.FollowSystemTheme && systemDarkMode)
            final_q = (final_q ? final_q + "" : "") + "+dark";

        showNotification("Wallhaven Wallpaper", "Fetching wallpaper: " + final_q, "plugin-wallpaper", false);
        return `q=${encodeURIComponent(final_q)}`;
    }

    function pickImage(d) {
        if (d.data.length > 0) {
            var index = 0;
            if (main.configuration.Sorting != "random") {
                index = main.currentIndex;
                if (index > 24) {
                    main.currentPage += 1;
                    main.currentIndex = 0;
                    isLoading = false; // Reset loading state before restarting
                    refreshTimer.restart();
                    return ;
                }
                main.currentIndex += 1;
            } else {
                index = Math.floor(Math.random() * d.data.length);
            }
            if (index >= d.data.length)
                index = index % d.data.length;

            const imageObj = d.data[index] || {
            };
            const remoteUrl = imageObj.path;
            main.currentPage = d.meta.current_page;
            main.configuration.currentWallpaperThumbnail = imageObj.thumbs.small;
            wallpaper.configuration.writeConfig();
            setWallpaperUrl(remoteUrl);
        } else {
            let msg = "No images found for query: " + d.meta.query;
            showNotification("Wallhaven Wallpaper Error", msg, "dialog-error", true);
            log(msg);
            main.configuration.currentWallpaperThumbnail = "";
            wallpaper.configuration.writeConfig();
            loadFallbackImage();
            isLoading = false;
        }
    }

    function setWallpaperUrl(url) {
        if (url === lastLoadedUrl) {
            log("Already loaded, skipping");
            isLoading = false;
            return ;
        }
        main.currentUrl = url;
        main.configuration.lastValidImagePath = url;
        wallpaper.configuration.writeConfig();
    }

    function loadImage() {
        try {
            if (main.currentUrl.toString() === lastLoadedUrl && main.pendingImage) {
                log("Skipping duplicate load");
                isLoading = false;
                return ;
            }
            log("Loading: " + main.currentUrl.toString());
            lastLoadedUrl = main.currentUrl.toString();
            main.pendingImage = mainImage.createObject(root, {
                "source": main.currentUrl,
                "fillMode": main.fillMode,
                "sourceSize": main.sourceSize
            });
        } catch (e) {
            log("Error in loadImage: " + e);
            isLoading = false;
            main.currentUrl = "blackscreen.jpg";
            lastLoadedUrl = "blackscreen.jpg";
            main.pendingImage = mainImage.createObject(root, {
                "source": "blackscreen.jpg",
                "fillMode": main.fillMode,
                "sourceSize": main.sourceSize
            });
            root.replace(main.pendingImage);
        }
    }

    anchors.fill: parent
    Component.onCompleted: {
        refreshImage();
    }
    onCurrentUrlChanged: loadImage()
    onFillModeChanged: loadImage()
    onRefreshSignalChanged: refreshTimer.restart()
    onSortingChanged: {
        if (sorting != "random") {
            currentPage = 1;
            currentIndex = 0;
        }
    }
    onSystemDarkModeChanged: {
        if (followSystemTheme) {
            log("System theme changed");
            refreshTimer.restart();
        }
    }
    onFollowSystemThemeChanged: refreshTimer.restart()
    contextualActions: [
        PlasmaCore.Action {
            text: i18n("Open Wallpaper URL")
            icon.name: "link"
            onTriggered: Qt.openUrlExternally(main.currentUrl)
        },
        PlasmaCore.Action {
            text: i18n("Save Wallpaper")
            icon.name: "bookmark-new"
            onTriggered: saveCurrentWallpaper()
        },
        PlasmaCore.Action {
            text: i18n("Refresh Wallpaper")
            icon.name: "view-refresh"
            onTriggered: refreshImage()
        }
    ]

    Timer {
        id: retryTimer

        property int retries
        property var resolve
        property var reject

        interval: main.retryRequestDelay * 1000
        repeat: false
        onTriggered: {
            getImageData(retryTimer.retries - 1).then(retryTimer.resolve).catch(retryTimer.reject);
        }
    }

    Timer {
        id: refreshTimer

        interval: main.configuration.WallpaperDelay * 60 * 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            log("refreshTimer triggered");
            Qt.callLater(refreshImage);
        }
    }

    Component {
        id: notificationComponent

        Notification {
            componentName: "plasma_workspace"
            eventId: "notification"
            urgency: Notification.HighUrgency
            autoDelete: true
        }

    }

    QQC2.StackView {
        id: root

        anchors.fill: parent

        Component {
            id: mainImage

            Image {
                id: imageItem

                asynchronous: true
                cache: false
                autoTransform: true
                smooth: true
                onStatusChanged: {
                    if (status === Image.Error) {
                        log("Error loading image");
                        showNotification("Wallhaven Wallpaper Error", "Failed to load image. Try refreshing or restart Plasma shell.", "dialog-error", true);
                        if (imageItem === main.pendingImage) {
                            main.pendingImage = null;
                            imageItem.destroy();
                        }
                        isLoading = false;
                    } else if (status === Image.Ready) {
                        log("Image loaded successfully");
                        if (isHttpUrl(source)) {
                            main.configuration.lastValidImagePath = source.toString();
                            wallpaper.configuration.writeConfig();
                        }
                        if (imageItem === main.pendingImage && root.currentItem !== imageItem) {
                            if (root.depth === 0)
                                root.push(imageItem);
                            else
                                root.replace(imageItem);
                        }
                        main.accentColorChanged();
                        isLoading = false;
                    }
                }
                QQC2.StackView.onDeactivated: destroy()
                QQC2.StackView.onRemoved: destroy()
            }

        }

        replaceEnter: Transition {
            OpacityAnimator {
                id: replaceEnterOpacityAnimator

                from: 0
                to: 1
                duration: main.doesSkipAnimation ? 1 : Math.round(Kirigami.Units.longDuration * 2.5)
            }

        }

        // If we fade both at the same time you can see the background behind glimpse through
        replaceExit: Transition {
            PauseAnimation {
                duration: replaceEnterOpacityAnimator.duration
            }

        }

    }

}
