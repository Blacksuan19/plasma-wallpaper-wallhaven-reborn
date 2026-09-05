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
import "downloads.js" as Downloads
import org.kde.kirigami 2.20 as Kirigami
import org.kde.notification 1.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasma5support 2.0 as Plasma5Support
import org.kde.plasma.plasmoid
import "savedWallpapers.js" as SavedWallpapers
import "syncCoordinator.js" as SyncCoordinator
import "utils.js" as Utils

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
    property var currentWallpaperColors: []
    readonly property bool systemDarkMode: Kirigami.Theme.textColor.hsvValue > Kirigami.Theme.backgroundColor.hsvValue
    readonly property bool followSystemTheme: main.configuration.FollowSystemTheme
    readonly property bool synchronizeScreens: main.configuration.SynchronizeScreens === true
    readonly property string configuredSyncGroupId: main.configuration.SyncGroupId || ""
    readonly property string cacheDir: Utils.normalizePath(Platform.StandardPaths.writableLocation(Platform.StandardPaths.AppDataLocation)) + "/cache"
    readonly property string cacheFilePath: cacheDir + "/current-wallpaper.jpg"
    readonly property url cacheFileUrl: "file://" + cacheFilePath
    readonly property string savedWallpapersDir: Utils.normalizePath(Platform.StandardPaths.writableLocation(Platform.StandardPaths.AppDataLocation)) + "/wallhaven-saved"
    property var pendingDownloads: ({
    }) // Track pending downloads: {url: {thumbnail, entry}}
    property var shownSavedWallpapers: main.configuration.ShownSavedWallpapers || []
    property string syncInstanceId: ""
    property string activeSyncGroupId: ""
    property bool cacheCurrentImage: true
    property bool componentReady: false

    function log(msg) {
        console.log(`Wallhaven Wallpaper: ${msg}`);
    }

    function effectiveSyncGroupId() {
        return configuredSyncGroupId || "wallhaven-default-sync-group";
    }

    function scheduleNextRefresh() {
        refreshTimer.restart();
    }

    function unregisterFromSyncGroup() {
        if (syncInstanceId && activeSyncGroupId)
            SyncCoordinator.unregisterInstance(activeSyncGroupId, syncInstanceId);

        syncInstanceId = "";
        activeSyncGroupId = "";
    }

    function registerWithSyncGroup() {
        if (!synchronizeScreens) {
            unregisterFromSyncGroup();
            return null;
        }

        const groupId = effectiveSyncGroupId();
        if (syncInstanceId && activeSyncGroupId === groupId) {
            return {
                instanceId: syncInstanceId,
                hasSelection: SyncCoordinator.hasSelection(groupId)
            };
        }

        unregisterFromSyncGroup();
        const registration = SyncCoordinator.registerInstance(groupId, {
            "onSelection": function(selection) {
                applyWallpaperSelection(selection);
            }
        });
        activeSyncGroupId = groupId;
        syncInstanceId = registration.instanceId;
        if (registration.hasSelection)
            applyWallpaperSelection(registration.selection);
        return registration;
    }

    function handleSyncConfigurationChanged() {
        if (!componentReady)
            return;

        const registration = registerWithSyncGroup();
        if (!synchronizeScreens) {
            scheduleNextRefresh();
        } else if (registration && !registration.hasSelection) {
            Qt.callLater(refreshImage);
        } else {
            scheduleNextRefresh();
        }
    }

    function buildDownloadCtx() {
        return {
            "config": main.configuration,
            "savedDir": savedWallpapersDir,
            "cacheDir": cacheDir,
            "cacheFilePath": cacheFilePath,
            "pendingDownloads": pendingDownloads,
            "notify": showNotification,
            "writeConfig": function() {
                wallpaper.configuration.writeConfig();
            },
            "exec": function(cmd) {
                downloadExecutor.connectSource(cmd);
            },
            "disconnect": function(sourceName) {
                downloadExecutor.disconnectSource(sourceName);
            },
            "utils": Utils,
            "log": log
        };
    }

    function buildSavedCtx() {
        return {
            "config": main.configuration,
            "state": {
                "lastLoadedUrl": lastLoadedUrl
            },
            "notify": showNotification,
            "currentUrl": function() {
                return main.currentUrl ? main.currentUrl.toString() : "";
            },
            "thumbnail": function() {
                return main.configuration.currentWallpaperThumbnail || "";
            },
            "getShownList": function() {
                return shownSavedWallpapers || [];
            },
            "downloadWallpaper": function(url, thumb, isDark) {
                Downloads.queueDownload(buildDownloadCtx(), url, thumb, isDark);
            },
            "isDark": Utils.isColorsArrayDark(currentWallpaperColors),
            "systemDarkMode": systemDarkMode,
            "utils": Utils,
            "log": log
        };
    }

    function loadFallbackImage() {
        if (cacheFilePath !== "") {
            log("Using startup wallpaper cache");
            main.currentUrl = cacheFileUrl;
        } else if (lastValidImagePath !== "") {
            log("Using last valid image path");
            main.currentUrl = lastValidImagePath;
        } else {
            main.currentUrl = "blackscreen.jpg";
        }
        loadImage();
    }

    function loadStartupCache() {
        log("Trying startup wallpaper cache: " + cacheFileUrl);
        main.currentUrl = cacheFileUrl;
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
        SavedWallpapers.saveCurrentWallpaper(buildSavedCtx());
    }

    function showSavedNotifications(result) {
        (result.notifications || []).forEach((message) => {
            showNotification("Wallhaven Wallpaper", message, "plugin-wallpaper", false);
        });
    }

    function selectRemoteWallpaper(data) {
        if (!data.data || data.data.length === 0) {
            const query = data.meta && data.meta.query ? data.meta.query : main.configuration.Query;
            throw new Error("No images found for query: " + query);
        }

        let index = 0;
        if (main.configuration.Sorting !== "random") {
            index = main.currentIndex;
            if (index > 24) {
                main.currentPage += 1;
                main.currentIndex = 0;
                return null;
            }
            main.currentIndex += 1;
        } else {
            index = Math.floor(Math.random() * data.data.length);
        }
        if (index >= data.data.length)
            index = index % data.data.length;

        const imageObj = data.data[index] || ({});
        if (!imageObj.path)
            throw new Error("Wallhaven returned an image without a usable URL");

        return {
            kind: "remote",
            url: imageObj.path,
            thumbnail: imageObj.thumbs ? imageObj.thumbs.small : "",
            colors: imageObj.colors || [],
            currentPage: data.meta ? data.meta.current_page : main.currentPage,
            currentIndex: main.currentIndex,
            currentSearchTermIndex: main.currentSearchTermIndex,
            shownList: [],
            producerInstanceId: syncInstanceId
        };
    }

    function fetchRemoteSelection(reason) {
        if (reason) {
            log("Fetching from Wallhaven: " + reason);
            showNotification("Wallhaven Wallpaper", reason, "plugin-wallpaper", false);
        }

        return getImageData(main.retryRequestCount).then((data) => {
            const selection = selectRemoteWallpaper(data);
            if (selection)
                return selection;

            return fetchRemoteSelection("");
        });
    }

    function produceWallpaperSelection() {
        if (!main.configuration.UseSavedWallpapers)
            return fetchRemoteSelection("");

        const result = SavedWallpapers.selectSavedWallpaper(buildSavedCtx());
        showSavedNotifications(result);
        if (result.type === "fetch")
            return fetchRemoteSelection(result.reason);

        return Promise.resolve({
            kind: "saved",
            url: result.url,
            thumbnail: result.thumbnail,
            colors: [],
            currentPage: main.currentPage,
            currentIndex: main.currentIndex,
            currentSearchTermIndex: main.currentSearchTermIndex,
            shownList: result.shownList || [],
            producerInstanceId: syncInstanceId
        });
    }

    function applyWallpaperSelection(selection) {
        if (!selection || !selection.url)
            return;

        if (selection.currentPage !== undefined)
            main.currentPage = selection.currentPage;
        if (selection.currentIndex !== undefined)
            main.currentIndex = selection.currentIndex;
        if (selection.currentSearchTermIndex !== undefined)
            main.currentSearchTermIndex = selection.currentSearchTermIndex;

        currentWallpaperColors = selection.colors || [];
        shownSavedWallpapers = selection.shownList || [];
        main.configuration.ShownSavedWallpapers = shownSavedWallpapers;
        main.configuration.currentWallpaperThumbnail = selection.thumbnail || "";
        main.configuration.lastValidImagePath = selection.url;
        wallpaper.configuration.writeConfig();

        cacheCurrentImage = !synchronizeScreens || selection.producerInstanceId === syncInstanceId;
        isLoading = true;
        setWallpaperUrl(selection.url);
        scheduleNextRefresh();
    }

    function handleRefreshError(error) {
        log("Wallpaper refresh failed: " + error);
        showNotification("Wallhaven Wallpaper Error", "Failed to fetch: " + error, "dialog-error", true);
        loadFallbackImage();
        isLoading = false;
        scheduleNextRefresh();
    }

    function refreshImage() {
        if (isLoading) {
            log("Loading in progress - skipping refresh");
            return;
        }

        if (synchronizeScreens) {
            if (!syncInstanceId)
                registerWithSyncGroup();

            const started = SyncCoordinator.requestSelection(activeSyncGroupId, syncInstanceId, produceWallpaperSelection, handleRefreshError);
            if (started) {
                isLoading = true;
                log("Started synchronized wallpaper selection for group " + activeSyncGroupId);
            } else {
                log("Synchronized wallpaper selection already in progress for group " + activeSyncGroupId);
                scheduleNextRefresh();
            }
            return;
        }

        isLoading = true;
        produceWallpaperSelection().then(applyWallpaperSelection).catch(handleRefreshError);
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
            url += Utils.buildBinaryParameter(main.configuration, "categories", ["CategoryGeneral", "CategoryAnime", "CategoryPeople"]) + "&";
            url += Utils.buildBinaryParameter(main.configuration, "purity", ["PuritySFW", "PuritySketchy", "PurityNSFW"]) + "&";
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
            url += Utils.buildRatioParameter(main.configuration);
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

    // Helper function to build query parameter
    function buildQueryParameter() {
        const result = Utils.buildQueryParameter(main.configuration, systemDarkMode, main.currentSearchTermIndex);
        main.currentSearchTermIndex = result.nextIndex;
        showNotification("Wallhaven Wallpaper", "Fetching wallpaper: " + result.query, "plugin-wallpaper", false);
        return result.queryParam;
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

    function openWallpaperPage() {
        const currentUrlString = main.currentUrl ? main.currentUrl.toString() : "";
        const wallhavenId = Utils.extractWallhavenId(currentUrlString);
        if (!wallhavenId) {
            showNotification("Wallhaven Wallpaper Error", "Could not determine the wallpaper page for this image", "dialog-error", true);
            return ;
        }
        Qt.openUrlExternally(`https://wallhaven.cc/w/${wallhavenId}`);
    }

    anchors.fill: parent
    Component.onCompleted: {
        componentReady = true;
        loadStartupCache();
        const registration = registerWithSyncGroup();
        if (!synchronizeScreens || (registration && !registration.hasSelection))
            Qt.callLater(refreshImage);
        else
            scheduleNextRefresh();
    }
    Component.onDestruction: {
        componentReady = false;
        unregisterFromSyncGroup();
    }
    onCurrentUrlChanged: loadImage()
    onFillModeChanged: loadImage()
    onRefreshSignalChanged: refreshImage()
    onSynchronizeScreensChanged: Qt.callLater(handleSyncConfigurationChanged)
    onConfiguredSyncGroupIdChanged: {
        if (synchronizeScreens)
            Qt.callLater(handleSyncConfigurationChanged);
    }
    onSortingChanged: {
        if (sorting != "random") {
            currentPage = 1;
            currentIndex = 0;
        }
    }
    onSystemDarkModeChanged: {
        if (followSystemTheme) {
            log("System theme changed");
            if (main.configuration.UseSavedWallpapers) {
                // Reset shown list so the dark/light subset is re-cycled from scratch
                shownSavedWallpapers = [];
                main.configuration.ShownSavedWallpapers = [];
                wallpaper.configuration.writeConfig();
            }
            refreshImage();
        }
    }
    onFollowSystemThemeChanged: refreshImage()
    contextualActions: [
        PlasmaCore.Action {
            text: i18n("Open Wallpaper Page")
            icon.name: "link"
            onTriggered: openWallpaperPage()
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
        id: syncPollTimer

        interval: 250
        repeat: true
        running: componentReady && synchronizeScreens && syncInstanceId !== ""
        onTriggered: SyncCoordinator.pollInstance(activeSyncGroupId, syncInstanceId)
    }

    Timer {
        id: refreshTimer

        interval: main.configuration.WallpaperDelay * 60 * 1000
        repeat: false
        triggeredOnStart: false
        onTriggered: {
            log("refreshTimer triggered");
            Qt.callLater(refreshImage);
        }
    }

    Plasma5Support.DataSource {
        id: downloadExecutor

        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            Downloads.handleExecResult(buildDownloadCtx(), sourceName, data);
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
                        log("Error loading image: " + source);
                        if (source.toString() !== cacheFileUrl.toString())
                            showNotification("Wallhaven Wallpaper Error", "Failed to load image. Try refreshing or restart Plasma shell.", "dialog-error", true);

                        if (imageItem === main.pendingImage) {
                            main.pendingImage = null;
                            imageItem.destroy();
                        }
                        isLoading = false;
                    } else if (status === Image.Ready) {
                        log("Image loaded successfully");
                        if (Utils.isHttpUrl(source)) {
                            main.configuration.lastValidImagePath = source.toString();
                            wallpaper.configuration.writeConfig();
                            if (cacheCurrentImage)
                                Downloads.queueCacheDownload(buildDownloadCtx(), source.toString());
                        }
                        if (imageItem === main.pendingImage && root.currentItem !== imageItem) {
                            if (root.depth === 0)
                                root.push(imageItem);
                            else
                                root.replace(imageItem);
                        }
                        isLoading = false;
                    }
                }
                QQC2.StackView.onActivated: main.accentColorChanged()
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
