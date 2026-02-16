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
    // Let the Image's onStatusChanged add it when ready

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
    property bool isLoading: false // Consolidated loading flag
    property string lastLoadedUrl: ""
    property int lastFillMode: -1
    readonly property bool systemDarkMode: Kirigami.Theme.textColor.hsvValue > Kirigami.Theme.backgroundColor.hsvValue
    readonly property bool followSystemTheme: main.configuration.FollowSystemTheme
    readonly property bool useSavedWallpapers: main.configuration.UseSavedWallpapers
    readonly property var savedWallpapers: main.configuration.SavedWallpapers
    readonly property bool fallbackToWallhaven: main.configuration.FallbackToWallhaven

    function log(msg) {
        console.log(`Wallhaven Wallpaper: ${msg}`);
    }

    function saveCurrentWallpaper() {
        if (!main.currentUrl || main.currentUrl.toString() === "" || main.currentUrl.toString() === "blackscreen.jpg") {
            sendFailureNotification("No valid wallpaper to save");
            return ;
        }
        const urlString = main.currentUrl.toString();
        // Check if URL is already saved
        let currentList = main.configuration.SavedWallpapers || [];
        if (currentList.indexOf(urlString) !== -1) {
            sendFailureNotification("Wallpaper already saved");
            return ;
        }
        // Create a new array to trigger configuration save
        let newList = currentList.slice();
        newList.push(urlString);
        main.configuration.SavedWallpapers = newList;
        log("Saved wallpaper: " + urlString);
        if (main.configuration.RefreshNotification) {
            var note = refreshNotification.createObject(root);
            note.text = "Wallpaper saved! Total saved: " + newList.length;
            note.sendEvent();
        }
    }

    function loadFromSavedWallpapers() {
        const savedList = main.configuration.SavedWallpapers || [];
        if (savedList.length === 0) {
            sendFailureNotification("No saved wallpapers found. Add some using 'Save Wallpaper' context menu.");
            isLoading = false;
            return ;
        }
        // Get list of already shown wallpapers
        let shownList = main.configuration.ShownSavedWallpapers || [];
        // Check if we've shown all wallpapers
        if (shownList.length >= savedList.length) {
            log("All saved wallpapers have been shown in this cycle (" + savedList.length + " total)");
            // If fallback is enabled, fetch from Wallhaven
            if (fallbackToWallhaven) {
                log("Fallback to Wallhaven enabled - fetching new wallpaper");
                if (main.configuration.RefreshNotification) {
                    var note = refreshNotification.createObject(root);
                    note.text = "All saved wallpapers shown. Fetching from Wallhaven...";
                    note.sendEvent();
                }
                // Reset shown list for next cycle
                main.configuration.ShownSavedWallpapers = [];
                // Fetch from Wallhaven
                getImageData(main.retryRequestCount).then((data) => {
                    pickImage(data);
                }).catch((e) => {
                    log("getImageData Error:" + e);
                    sendFailureNotification("Failed to fetch from Wallhaven: " + e);
                    isLoading = false;
                });
                return ;
            } else {
                // No fallback - notify user and reset
                sendFailureNotification("All " + savedList.length + " saved wallpapers have been shown. Enable 'Fallback to Wallhaven' or add more wallpapers.");
                // Reset for next cycle
                main.configuration.ShownSavedWallpapers = [];
                isLoading = false;
                return ;
            }
        }
        // Find wallpapers that haven't been shown yet
        let unshownWallpapers = [];
        for (let i = 0; i < savedList.length; i++) {
            if (shownList.indexOf(savedList[i]) === -1)
                unshownWallpapers.push(savedList[i]);

        }
        // Prefer wallpapers different from the currently loaded one
        let availableWallpapers = unshownWallpapers.filter((url) => {
            return url !== lastLoadedUrl;
        });
        // If no unshown wallpapers available (except current), pick from all saved wallpapers
        if (availableWallpapers.length === 0) {
            // Try to pick from any saved wallpaper that isn't the current one
            availableWallpapers = savedList.filter((url) => {
                return url !== lastLoadedUrl;
            });
            // If still no options (only 1 wallpaper in total), handle exhaustion case
            if (availableWallpapers.length === 0) {
                log("Only one saved wallpaper exists");
                // Reset and try to fetch from Wallhaven if enabled
                if (fallbackToWallhaven) {
                    log("Fallback to Wallhaven enabled - fetching new wallpaper");
                    if (main.configuration.RefreshNotification) {
                        var note = refreshNotification.createObject(root);
                        note.text = "Only one saved wallpaper. Fetching from Wallhaven...";
                        note.sendEvent();
                    }
                    main.configuration.ShownSavedWallpapers = [];
                    getImageData(main.retryRequestCount).then((data) => {
                        pickImage(data);
                    }).catch((e) => {
                        log("getImageData Error:" + e);
                        sendFailureNotification("Failed to fetch from Wallhaven: " + e);
                        isLoading = false;
                    });
                    return ;
                } else {
                    sendFailureNotification("Only one saved wallpaper. Add more or enable 'Fallback to Wallhaven'.");
                    isLoading = false;
                    return ;
                }
            }
            // We're picking from already shown wallpapers, so reset the shown list
            log("All wallpapers shown, restarting cycle with different wallpaper");
            shownList = [];
        }
        // Pick a random wallpaper from available options
        const randomIndex = Math.floor(Math.random() * availableWallpapers.length);
        const selectedUrl = availableWallpapers[randomIndex];
        // Mark as shown - create new array to trigger configuration save
        let newShownList = shownList.slice();
        newShownList.push(selectedUrl);
        main.configuration.ShownSavedWallpapers = newShownList;
        log("Loading saved wallpaper (" + newShownList.length + "/" + savedList.length + "): " + selectedUrl);
        // Show notification
        if (main.configuration.RefreshNotification) {
            var note = refreshNotification.createObject(root);
            note.text = "Loading saved wallpaper " + newShownList.length + " of " + savedList.length;
            note.sendEvent();
        }
        main.currentUrl = selectedUrl;
        main.configuration.lastValidImagePath = selectedUrl;
        loadImage();
        isLoading = false;
    }

    function refreshImage() {
        // Don't refresh if already loading
        if (isLoading) {
            log("Loading in progress - skipping refresh request");
            return ;
        }
        isLoading = true;
        // Check if we should use saved wallpapers instead of fetching from API
        if (useSavedWallpapers) {
            log("Using saved wallpapers mode");
            loadFromSavedWallpapers();
            return ;
        }
        getImageData(main.retryRequestCount).then((data) => {
            pickImage(data);
        }).catch((e) => {
            log("getImageData Error:" + e);
            sendFailureNotification("Failed to fetch a new wallpaper: " + e);
            // Try to use the last valid cached image if available
            if (lastValidImagePath !== "" && isFileExists(lastValidImagePath)) {
                log("Using last valid cached image: " + lastValidImagePath);
                main.currentUrl = "file://" + lastValidImagePath;
            } else {
                main.currentUrl = "blackscreen.jpg";
            }
            loadImage();
            isLoading = false;
        });
    }

    function handleRequestError(retries, errorText, resolve, reject) {
        if (retries > 0) {
            let msg = `Request failed, retrying in ${main.retryRequestDelay} seconds...`;
            log(msg);
            sendFailureNotification(msg);
            retryTimer.retries = retries;
            retryTimer.resolve = resolve;
            retryTimer.reject = reject;
            retryTimer.start();
        } else {
            let msg = "Request failed, no more retries left" + (errorText ? ": " + errorText : "");
            sendFailureNotification(msg);
            reject(msg);
        }
    }

    function getImageData(retries) {
        return new Promise((res, rej) => {
            var url = `https://wallhaven.cc/api/v1/search?`;
            // Build URL parameters
            url += buildBinaryParameter("categories", {
                "CategoryGeneral": true,
                "CategoryAnime": true,
                "CategoryPeople": true
            }) + "&";
            url += buildBinaryParameter("purity", {
                "PuritySFW": true,
                "PuritySketchy": true,
                "PurityNSFW": true
            }) + "&";
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
                        let msg = "cannot parse response as JSON: " + xhr.responseText;
                        sendFailureNotification(msg);
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

    // Helper function to build binary parameters like categories and purity
    function buildBinaryParameter(paramName, configKeys) {
        let result = "";
        for (const key of Object.keys(configKeys)) {
            result += main.configuration[key] ? "1" : "0";
        }
        return `${paramName}=${result}`;
    }

    // Helper function to build ratio parameter
    function buildRatioParameter() {
        if (wallpaper.configuration.RatioAny)
            return "";

        var ratios = [];
        if (wallpaper.configuration.Ratio169)
            ratios.push("16x9");

        if (wallpaper.configuration.Ratio1610)
            ratios.push("16x10");

        if (wallpaper.configuration.RatioCustom)
            ratios.push(wallpaper.configuration.RatioCustomValue);

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
        // Only add tag if setting is ON and system is DARK
        if (main.configuration.FollowSystemTheme && systemDarkMode)
            final_q = (final_q ? final_q + "" : "") + "+dark";

        log("transformed query: " + final_q);
        sendRefreshNotification(final_q);
        return `q=${encodeURIComponent(final_q)}`;
    }

    function sendRefreshNotification(query) {
        if (!main.configuration.RefreshNotification)
            return ;

        var note = refreshNotification.createObject(root);
        note.text = "Fetching a new wallpaper with search term " + query;
        note.sendEvent();
    }

    function sendFailureNotification(msg) {
        if (!main.configuration.ErrorNotification)
            return ;

        var note = failureNotification.createObject(root);
        note.text = msg;
        note.sendEvent();
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
            downloadImageToCache(remoteUrl);
        } else {
            let msg = "No images found for given query " + d.meta.query + " with the current settings";
            sendFailureNotification(msg);
            log(msg);
            main.configuration.currentWallpaperThumbnail = "";
            // Try to use the last valid cached image if available
            if (lastValidImagePath !== "" && isFileExists(lastValidImagePath)) {
                log("Using last valid cached image: " + lastValidImagePath);
                main.currentUrl = "file://" + lastValidImagePath;
            } else {
                main.currentUrl = "blackscreen.jpg";
            }
            loadImage();
            isLoading = false; // Make sure to reset loading state
        }
    }

    function downloadImageToCache(remoteUrl) {
        if (remoteUrl === lastLoadedUrl) {
            log("URL already loaded, skipping: " + remoteUrl);
            isLoading = false;
            return ;
        }
        log("Loading image from: " + remoteUrl);
        main.currentUrl = remoteUrl;
        main.configuration.lastValidImagePath = remoteUrl;
    }

    function isFileExists(filePath) {
        // For URLs, assume they exist
        if (filePath.toString().startsWith("http"))
            return true;

        try {
            const cleanPath = filePath.replace(/^file:\/\//, '');
            if (!cleanPath)
                return false;

            const xhr = new XMLHttpRequest();
            xhr.open("GET", "exec:[ -s \"" + cleanPath + "\" ] && echo \"yes\" || echo \"no\"", false);
            xhr.send();
            return xhr.responseText.trim() === "yes";
        } catch (e) {
            return false;
        }
    }

    function loadImage() {
        try {
            // Skip if URL hasn't changed and we already have an image
            if (main.currentUrl.toString() === lastLoadedUrl && main.pendingImage) {
                log("Skipping duplicate load of: " + main.currentUrl);
                isLoading = false;
                return ;
            }
            log("Loading image with URL: " + main.currentUrl.toString());
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
    onCurrentUrlChanged: {
        loadImage();
    }
    onFillModeChanged: {
        if (lastFillMode !== fillMode) {
            lastFillMode = fillMode;
            loadImage();
        }
    }
    onRefreshSignalChanged: refreshTimer.restart()
    onSortingChanged: {
        if (sorting != "random") {
            currentPage = 1;
            currentIndex = 0;
        }
    }
    onSystemDarkModeChanged: {
        if (followSystemTheme) {
            log("System theme changed. Dark Mode: " + systemDarkMode);
            refreshTimer.restart();
        }
    }
    onFollowSystemThemeChanged: {
        refreshTimer.restart();
    }
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
        id: refreshNotification

        Notification {
            componentName: "plasma_workspace"
            eventId: "notification"
            title: "Wallhaven Wallpaper"
            text: "Fetching a new wallpaper with search term "
            iconName: "plugin-wallpaper"
            urgency: Notification.HighUrgency
            autoDelete: true
        }

    }

    Component {
        id: failureNotification

        Notification {
            componentName: "plasma_workspace"
            eventId: "notification"
            title: "Wallhaven Wallpaper Error"
            text: "Failed to fetch a new wallpaper"
            iconName: "dialog-error"
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
                        log("Error loading image: " + source);
                        sendFailureNotification("Failed to load image. This may be a network error. Try refreshing or restart Plasma shell if issue persists.");
                        // On error, destroy pending image and keep old wallpaper visible
                        if (imageItem === main.pendingImage) {
                            main.pendingImage = null;
                            imageItem.destroy();
                        }
                        isLoading = false;
                    } else if (status === Image.Ready) {
                        log("Image loaded successfully: " + source);
                        if (source.toString().startsWith("http"))
                            main.configuration.lastValidImagePath = source.toString();

                        // Add to stack now that image is loaded
                        if (imageItem === main.pendingImage) {
                            // Only add if not already in stack (check current item)
                            if (root.currentItem !== imageItem) {
                                log("Image ready, adding to stack");
                                // Use push for initial load (empty stack), replace for subsequent loads
                                if (root.depth === 0)
                                    root.push(imageItem);
                                else
                                    root.replace(imageItem);
                            }
                        }
                        main.accentColorChanged();
                        isLoading = false;
                    } else if (status === Image.Loading) {
                        log("Image loading in progress: " + source);
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
