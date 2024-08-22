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
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.wallpapers.image as Wallpaper

WallpaperItem {
    id: main

    property url currentUrl
    property int currentPage: 1
    property int currentIndex
    readonly property int fillMode: main.configuration.FillMode
    readonly property bool blur: main.configuration.Blur
    readonly property bool refreshSignal: main.configuration.RefetchSignal
    readonly property string sorting: main.configuration.Sorting
    readonly property size sourceSize: Qt.size(main.width * Screen.devicePixelRatio, main.height * Screen.devicePixelRatio)
    readonly property string aspectRatio: {
        var d = greatestCommonDenominator(main.width, main.height);
        return main.width / d + "x" + main.height / d;
    }
    property Item pendingImage

    function greatestCommonDenominator(a, b) {
        return (b == 0) ? a : greatestCommonDenominator(b, a % b);
    }

    function refreshImage() {
        getImageData().then(pickImage).catch((e) => {
            console.error("getImageData Error:" + e);
            main.configuration.ErrorText = e;
            main.currentUrl = "blackscreen.jpg";
            loadImage();
        });
    }

    function getImageData() {
        return new Promise((res, rej) => {
            var url = `https://wallhaven.cc/api/v1/search?`;
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
            url += `sorting=${main.configuration.Sorting}&`;
            if (main.configuration.Sorting != "random")
                url += `page=${main.currentPage}&`;

            url += `atleast=${main.sourceSize.width}x${main.sourceSize.height}&`;
            if (main.configuration.Sorting == "toplist")
                url += `topRange=${main.configuration.TopRange}&`;

            url += `ratios=${encodeURIComponent(main.aspectRatio)}&`;
            url += `q=${encodeURIComponent(main.configuration.Query)}`;
            console.error('using url: ' + url);
            const xhr = new XMLHttpRequest();
            xhr.onload = () => {
                if (xhr.status != 200)
                    return rej("request error: " + xhr.responseText);

                let data = {
                };
                try {
                    data = JSON.parse(xhr.responseText);
                } catch (e) {
                    return rej("cannot parse response as JSON: " + xhr.responseText);
                }
                res(data);
            };
            xhr.onerror = () => {
                rej("failed to send request");
            };
            xhr.open('GET', url);
            xhr.setRequestHeader('X-API-Key', main.configuration.APIKey);
            xhr.setRequestHeader('User-Agent', 'wallhaven-wallpaper-kde-plugin');
            xhr.timeout = 15000;
            xhr.send();
        });
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
            const imageObj = d.data[index] || {
            };
            main.currentUrl = imageObj.path;
            main.currentPage = d.meta.current_page;
            main.configuration.currentWallpaperThumbnail = imageObj.thumbs.small;
            main.configuration.currentWallpaperUrl = imageObj.url;
            main.configuration.ErrorText = "";
        } else {
            main.configuration.ErrorText = "No wallpapers found";
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
        id: refreshTimer

        interval: main.configuration.WallpaperDelay * 60 * 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            console.log("refreshTimer triggered");
            refreshImage();
        }
    }

    QQC2.StackView {
        id: root

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
                // The value is to keep compatible with the old feeling defined by "TransitionAnimationDuration" (default: 1000)
                // 1 is HACK for https://bugreports.qt.io/browse/QTBUG-106797 to avoid flickering
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
