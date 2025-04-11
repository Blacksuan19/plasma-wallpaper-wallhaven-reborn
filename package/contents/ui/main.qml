/*
    SPDX-FileCopyrightText: 2013 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2014 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2014 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2022 Link Dupont <link@sub-pop.net>
    SPDX-FileCopyrightText: 2024 Abubakar Yagoub <plasma@blacksuan19.dev>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import Qt.labs.platform 1.1 as Platform // For StandardPaths
import Qt.labs.settings 1.0 // Only need basic settings
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
    // Fix cache path to be absolute with permissions check
    property string lastValidImagePath: settings.lastValidImagePath || ""
    // Define a static UserAgent to use consistently
    readonly property string userAgent: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
    // Define properties to track loading and error states
    property bool loadingImage: false
    property bool networkErrorMode: false
    property bool hasShownRestartNotification: false
    // Track last used URL to prevent duplicate image loads
    property string lastLoadedUrl: ""
    // Prevent multiple simultaneous loads
    property bool loadingInProgress: false
    // Only reload if fillMode actually changed
    property int lastFillMode: -1

    // Restore normal logging but eliminate duplicates
    function log(msg) {
        // Add timestamp for debugging
        const timestamp = new Date().toISOString().substring(11, 23);
        console.log(`Wallhaven Wallpaper [${timestamp}]: ${msg}`);
    }

    // Add a simple runProcess function to replace the missing one
    function runProcess(cmd) {
        try {
            log("Running command: " + cmd);
            const xhr = new XMLHttpRequest();
            xhr.open("GET", "exec:" + cmd, false);
            xhr.send();
            return xhr.responseText || "";
        } catch (e) {
            log("Error running process: " + e);
            return "";
        }
    }

    // Modified refresh image function with improved error handling
    function refreshImage() {
        // Always check if we have a pending network error first
        if (networkErrorMode) {
            log("Network error mode active - suggesting shell restart");
            // Always show restart notification if we're in error mode
            if (!hasShownRestartNotification) {
                sendFailureNotification("HTTP/2 compression error detected. Please restart Plasma shell to recover.");
                hasShownRestartNotification = true;
            }
            // Offer to restart the shell directly
            emergencyRefresh();
            return ;
        }
        // Regular workflow for normal operation
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
        });
    }

    // Improved emergency refresh that uses KWin scripting
    function emergencyRefresh() {
        log("Restarting plasmashell to recover from network error");
        sendFailureNotification("Restarting Plasma shell now...");
        try {
            // Use KWin scripting which is more reliable than direct process call
            const script = `
                var command = "kquitapp5 plasmashell && sleep 2 && kstart5 plasmashell";
                var proc = new QProcess();
                proc.startDetached("bash", ["-c", command]);
            `;
            const scriptFile = "/tmp/restart-plasma-" + new Date().getTime() + ".js";
            const xhr = new XMLHttpRequest();
            xhr.open("GET", "exec:echo '" + script + "' > " + scriptFile, false);
            xhr.send();
            // Execute the script with kwin-script-console
            runProcess("kwin-script " + scriptFile);
            // Wait a moment before attempting to clean up
            runProcess("(sleep 5; rm " + scriptFile + ") &");
        } catch (e) {
            log("Error restarting plasmashell: " + e);
            sendFailureNotification("Failed to restart plasmashell. Please run 'plasmashell --replace' manually.");
        }
    }

    function getImageData(retries) {
        return new Promise((res, rej) => {
            var url = `https://wallhaven.cc/api/v1/search?`;
            // categories
            var categories = "";
            if (main.configuration.CategoryGeneral)
                categories += "1";
            else
                categories += "0";
            if (main.configuration.CategoryAnime)
                categories += "1";
            else
                categories += "0";
            if (main.configuration.CategoryPeople)
                categories += "1";
            else
                categories += "0";
            // purity
            url += `categories=${categories}&`;
            var purity = "";
            if (main.configuration.PuritySFW)
                purity += "1";
            else
                purity += "0";
            if (main.configuration.PuritySketchy)
                purity += "1";
            else
                purity += "0";
            if (main.configuration.PurityNSFW)
                purity += "1";
            else
                purity += "0";
            url += `purity=${purity}&`;
            // sorting
            url += `sorting=${main.configuration.Sorting}&`;
            if (main.configuration.Sorting != "random")
                url += `page=${main.currentPage}&`;

            if (main.configuration.Sorting == "toplist")
                url += `topRange=${main.configuration.TopRange}&`;

            // dimensions
            url += `atleast=${main.configuration.ResolutionX}x${main.configuration.ResolutionY}&`;
            if (!wallpaper.configuration.RatioAny) {
                var ratios = [];
                if (wallpaper.configuration.Ratio169)
                    ratios.push("16x9");

                if (wallpaper.configuration.Ratio1610)
                    ratios.push("16x10");

                if (wallpaper.configuration.RatioCustom)
                    ratios.push(wallpaper.configuration.RatioCustomValue);

                url += `ratios=${ratios.join(',')}&`;
            }
            /// query
            var user_q = main.configuration.Query;
            let qs = user_q.split(",");
            // select a random query from the array
            let term_index = Math.floor(Math.random() * qs.length);
            // avoid repeating the same query
            if (term_index == main.currentSearchTermIndex)
                term_index = (term_index + 1) % qs.length;

            main.currentSearchTermIndex = term_index;
            let final_q = qs[term_index];
            log("transformed query: " + final_q);
            sendRefreshNotification(final_q);
            url += `q=${encodeURIComponent(final_q)}`;
            log('using url: ' + url);
            const xhr = new XMLHttpRequest();
            xhr.onload = () => {
                if (xhr.status != 200) {
                    if (retries > 0) {
                        let msg = `Request failed, retrying in ${main.retryRequestDelay} seconds...`;
                        log(msg);
                        sendFailureNotification(msg);
                        retryTimer.retries = retries;
                        retryTimer.resolve = res;
                        retryTimer.reject = rej;
                        retryTimer.start();
                    } else {
                        sendFailureNotification("Request failed, no more retries left" + xhr.responseText);
                        return rej("request error: " + xhr.responseText);
                    }
                } else {
                    let data = {
                    };
                    try {
                        data = JSON.parse(xhr.responseText);
                    } catch (e) {
                        let msg = "cannot parse response as JSON: " + xhr.responseText;
                        sendFailureNotification(msg);
                        return rej(msg);
                    }
                    res(data);
                }
            };
            xhr.onerror = () => {
                if (retries > 0) {
                    let msg = `Request failed, retrying in ${main.retryRequestDelay} seconds...`;
                    log(msg);
                    sendFailureNotification(msg);
                    retryTimer.retries = retries;
                    retryTimer.resolve = res;
                    retryTimer.reject = rej;
                    retryTimer.start();
                } else {
                    sendFailureNotification("Request failed, no more retries left");
                    rej("failed to send request");
                }
            };
            xhr.open('GET', url);
            xhr.setRequestHeader('X-API-Key', main.configuration.APIKey);
            xhr.setRequestHeader('User-Agent', 'wallhaven-wallpaper-kde-plugin');
            xhr.timeout = 5000;
            xhr.send();
        });
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
            // Save remote URL but don't set as currentUrl yet - we'll download first
            const remoteUrl = imageObj.path;
            main.currentPage = d.meta.current_page;
            main.configuration.currentWallpaperThumbnail = imageObj.thumbs.small;
            main.configuration.currentWallpaperUrl = imageObj.url;
            // Download image to cache
            downloadImageToCache(remoteUrl);
        } else {
            let msg = "No images found for given query " + d.meta.query + " with the current settings";
            sendFailureNotification(msg);
            log(msg);
            main.configuration.currentWallpaperThumbnail = "";
            main.configuration.currentWallpaperUrl = "";
            // Try to use the last valid cached image if available
            if (lastValidImagePath !== "" && isFileExists(lastValidImagePath)) {
                log("Using last valid cached image: " + lastValidImagePath);
                main.currentUrl = "file://" + lastValidImagePath;
            } else {
                main.currentUrl = "blackscreen.jpg";
            }
            loadImage();
        }
    }

    // In downloadImageToCache, prevent redundant loads
    function downloadImageToCache(remoteUrl) {
        if (loadingImage || loadingInProgress) {
            log("Download already in progress, skipping");
            return ;
        }
        // Skip if URL hasn't changed
        if (remoteUrl === lastLoadedUrl) {
            log("URL already loaded, skipping: " + remoteUrl);
            return ;
        }
        loadingImage = true;
        log("Loading image from: " + remoteUrl);
        // Use direct Image element to load the remote URL
        main.currentUrl = remoteUrl;
        // Store the URL for future reference
        settings.lastValidImagePath = remoteUrl;
    }

    // Very simple file check - we just check if the URL is defined and not empty
    function isValidUrl(url) {
        return url && url.toString() !== "";
    }

    // Simplified file check
    function isFileExists(filePath) {
        // For URLs, assume they exist
        if (filePath.toString().startsWith("http"))
            return true;

        // For file paths, simple approach
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

    // Improved error detection
    function handleCompressionError(sourceUrl) {
        log("HTTP/2 compression error detected for: " + sourceUrl);
        // Set network error mode
        networkErrorMode = true;
        hasShownRestartNotification = false; // Reset so we can show the notification again
        sendFailureNotification("Network HTTP/2 compression error detected. Please restart the Plasma shell to recover.");
    }

    // Simplified loadImage function that lets Plasma handle transitions
    function loadImage() {
        try {
            // Skip if URL hasn't changed and we already have an image
            if (main.currentUrl.toString() === lastLoadedUrl && main.pendingImage) {
                log("Skipping duplicate load of: " + main.currentUrl);
                loadingImage = false;
                return ;
            }
            // Skip if already loading
            if (loadingInProgress) {
                log("Loading already in progress, skipping");
                return ;
            }
            loadingInProgress = true;
            const source = main.currentUrl.toString();
            log("Loading image with URL: " + source);
            lastLoadedUrl = source;
            // Clean up previous image
            if (main.pendingImage)
                main.pendingImage.destroy();

            // Create a new image element with simpler settings
            main.pendingImage = mainImage.createObject(root, {
                "source": source,
                "fillMode": main.fillMode,
                "sourceSize": main.sourceSize
            });
            // Let Plasma handle the transition
            root.replace(main.pendingImage);
            loadingInProgress = false;
            loadingImage = false;
        } catch (e) {
            log("Error in loadImage: " + e);
            loadingImage = false;
            loadingInProgress = false;
            // Create a fallback black image
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

    // Place the anchors and Component.onCompleted properties here, not duplicated
    anchors.fill: parent
    Component.onCompleted: {
        refreshImage();
    }
    // Fix double image loading caused by Qt.callLater
    onCurrentUrlChanged: {
        if (!loadingInProgress)
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
    contextualActions: [
        PlasmaCore.Action {
            text: i18n("Open Wallpaper URL")
            icon.name: "external-link-symbolic"
            onTriggered: Qt.openUrlExternally(main.currentUrl)
        },
        PlasmaCore.Action {
            // Always show a special icon and text when in network error mode
            text: networkErrorMode ? i18n("Restart Shell (Fix Error)") : i18n("Refresh Wallpaper")
            icon.name: networkErrorMode ? "system-reboot" : "view-refresh"
            onTriggered: networkErrorMode ? emergencyRefresh() : refreshImage()
        }
    ]

    // Storage for persistent settings - consider using QtCore.Settings in the future
    Settings {
        id: settings

        property string lastValidImagePath: ""

        category: "WallhavenWallpaper"
    }

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
                // Remove custom opacity handling and transitions

                id: imageItem

                asynchronous: true
                cache: false
                autoTransform: true
                smooth: true
                // Add error handling directly in the Image component
                onStatusChanged: {
                    if (status === Image.Error) {
                        log("Error loading image: " + source);
                        // If this is a remote URL, try to handle HTTP errors
                        if (source.toString().startsWith("http")) {
                            log("Network error detected for: " + source);
                            // If we can access main, notify it of the error
                            if (main && typeof main.handleCompressionError === "function")
                                main.handleCompressionError(source.toString());

                        }
                    } else if (status === Image.Ready) {
                        log("Image loaded successfully: " + source);
                        if (source.toString().startsWith("http")) {
                            // Store successful URLs as last valid URL
                            main.lastValidImagePath = source.toString();
                            settings.lastValidImagePath = source.toString();
                        }
                        main.accentColorChanged();
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
