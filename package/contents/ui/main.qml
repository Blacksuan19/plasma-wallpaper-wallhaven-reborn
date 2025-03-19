/*
    SPDX-FileCopyrightText: 2013 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2014 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2014 Kai Uwe Broulik <kde@privat.broulik.de>
    SPDX-FileCopyrightText: 2022 Link Dupont <link@sub-pop.net>
    SPDX-FileCopyrightText: 2024 Abubakar Yagoub <plasma@blacksuan19.dev>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

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
    readonly property bool blur: main.configuration.Blur
    readonly property bool refreshSignal: main.configuration.RefetchSignal
    readonly property string sorting: main.configuration.Sorting
    readonly property int retryRequestCount: main.configuration.RetryRequestCount
    readonly property int retryRequestDelay: main.configuration.RetryRequestDelay
    readonly property size sourceSize: Qt.size(main.width * Screen.devicePixelRatio, main.height * Screen.devicePixelRatio)
    readonly property string aspectRatio: {
        var d = greatestCommonDenominator(main.width, main.height);
        return main.width / d + "x" + main.height / d;
    }
    property Item pendingImage

    function greatestCommonDenominator(a, b) {
        return (b == 0) ? a : greatestCommonDenominator(b, a % b);
    }

    function log(msg) {
        console.log("Wallhaven Wallpaper: " + msg);
    }

    function refreshImage() {
        getImageData(main.retryRequestCount).then((data) => {
            pickImage(data);
        }).catch((e) => {
            log("getImageData Error:" + e);
            sendFailureNotification("Failed to fetch a new wallpaper: " + e);
            main.currentUrl = "blackscreen.jpg";
            loadImage();
        });
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
            url += `atleast=${main.sourceSize.width}x${main.sourceSize.height}&`;
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
            main.currentUrl = imageObj.path;
            main.currentPage = d.meta.current_page;
            main.configuration.currentWallpaperThumbnail = imageObj.thumbs.small;
            main.configuration.currentWallpaperUrl = imageObj.url;
        } else {
            let msg = "No images found for given query " + d.meta.query + " with the current settings";
            sendFailureNotification(msg);
            log(msg);
            main.configuration.currentWallpaperThumbnail = "";
            main.configuration.currentWallpaperUrl = "";
            main.currentUrl = "blackscreen.jpg";
        }
        loadImage();
    }

    function loadImage() {
        if (pendingImage) {
            pendingImage.statusChanged.disconnect(replaceWhenLoaded);
            pendingImage.destroy();
            pendingImage = null;
        }
        pendingImage = mainImage.createObject(root, {
            "source": main.currentUrl,
            "fillMode": main.fillMode,
            "opacity": 0,
            "sourceSize": main.sourceSize,
            "width": main.width,
            "height": main.height
        });
        pendingImage.statusChanged.connect(replaceWhenLoaded);
        replaceWhenLoaded();
    }

    function replaceWhenLoaded() {
        if (pendingImage.status === Image.Loading)
            return ;

        pendingImage.statusChanged.disconnect(replaceWhenLoaded);
        root.replace(pendingImage, {
        }, QQC2.StackView.Transition);
        pendingImage = null;
    }

    onCurrentUrlChanged: Qt.callLater(loadImage)
    onFillModeChanged: Qt.callLater(loadImage)
    onBlurChanged: Qt.callLater(loadImage)
    onRefreshSignalChanged: refreshTimer.restart()
    onSortingChanged: {
        if (sorting != "random") {
            currentPage = 1;
            currentIndex = 0;
        }
    }
    anchors.fill: parent
    Component.onCompleted: refreshImage()
    contextualActions: [
        PlasmaCore.Action {
            text: i18n("Open Wallpaper URL")
            icon.name: "external-link-symbolic"
            onTriggered: Qt.openUrlExternally(main.currentUrl)
        },
        PlasmaCore.Action {
            text: i18n("Refresh Wallpaper")
            icon.name: "view-refresh"
            onTriggered: Qt.callLater(refreshImage)
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
                asynchronous: true
                cache: false
                autoTransform: true
                smooth: true
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
                duration: main.doesSkipAnimation ? 1 : Math.round(Kirigami.Units.veryLongDuration * 2.5)
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
