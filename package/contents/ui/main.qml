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
import org.kde.plasma.wallpapers.image as Wallpaper
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

WallpaperItem {
    id: root 
    anchors.fill: parent 

    property url currentUrl
    property int currentPage
    property int currentIndex

    readonly property int fillMode: wallpaper.configuration.FillMode
    readonly property string configColor: wallpaper.configuration.Color
    readonly property bool blur: wallpaper.configuration.Blur
    readonly property bool refreshSignal: wallpaper.configuration.RefetchSignal
    readonly property string sorting: wallpaper.configuration.Sorting

    readonly property size sourceSize: Qt.size(root.width * Screen.devicePixelRatio, root.height * Screen.devicePixelRatio)

    function greatestCommonDenominator(a, b) {
        return (b == 0) ? a : greatestCommonDenominator(b, a%b);
    }
    readonly property string aspectRatio: {
        var d = greatestCommonDenominator(root.width, root.height)
        return root.width / d + "x" + root.height / d;
    }

    property Item pendingImage

    onCurrentUrlChanged: Qt.callLater(loadImage);
    onFillModeChanged: Qt.callLater(loadImage);
    onConfigColorChanged: Qt.callLater(loadImage);
    onBlurChanged: Qt.callLater(loadImage);
    onRefreshSignalChanged: refreshTimer.restart();
    onSortingChanged: {
        if (sorting != "random") {
            currentPage = 1;
            currentIndex = 0;
        }
    }

    Component.onCompleted: refreshImage();

    Timer {
        id: refreshTimer
        interval: wallpaper.configuration.WallpaperDelay * 60 * 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            console.log("refreshTimer triggered");
            refreshImage();
        }
    }

    property Component mainImage: Component {
        Image {
            id: mainImage

            Rectangle {
                id: backgroundColor
                color: "black"
                anchors.fill: parent
                visible: mainImage.status === Image.Ready
                z: -2
            }
        }
    }

    function refreshImage() {
        getImageData().then(pickImage).catch(e => {
            console.error(e);
            wallpaper.configuration.ErrorText = e;
            root.currentUrl = "blackscreen.jpg";
            loadImage();
        });
    }

    function getImageData() {
        return new Promise((res, rej) => {
            var url = `https://wallhaven.cc/api/v1/search?`

            var categories = ""
            if (wallpaper.configuration.CategoryGeneral) {
                categories += "1";
            } else {
                categories += "0";
            }
            if (wallpaper.configuration.CategoryAnime) {
                categories += "1";
            } else {
                categories += "0";
            }
            if (wallpaper.configuration.CategoryPeople) {
                categories += "1";
            } else {
                categories += "0";
            }
            url += `categories=${categories}&`

            var purity = "";
            if (wallpaper.configuration.PuritySFW) {
                purity += "1";
            } else {
                purity += "0";
            }
            if (wallpaper.configuration.PuritySketchy) {
                purity += "1";
            } else {
                purity += "0";
            }
            if (wallpaper.configuration.PurityNSFW) {
                purity += "1";
            } else {
                purity += "0";
            }
            url += `purity=${purity}&`

            url += `sorting=${wallpaper.configuration.Sorting}&`

            if (wallpaper.configuration.Sorting != "random") {
                url += `page=${root.currentPage}&`
            }

            url += `atleast=${root.sourceSize.width}x${root.sourceSize.height}&`

            if (wallpaper.configuration.Sorting == "toplist") {
                url += `topRange=${wallpaper.configuration.TopRange}&`
            }

            // if (wallpaper.configuration.SearchColor) {
            //     url += `color=${wallpaper.configuration.SearchColor}&`
            // }

            url += `ratios=${encodeURIComponent(root.aspectRatio)}&`

            url += `q=${encodeURIComponent(wallpaper.configuration.Query)}`
            console.error('using url: ' + url);

            const xhr = new XMLHttpRequest();
            xhr.onload = () => {
                if (xhr.status != 200) {
                    return rej("request error: " + xhr.responseText);
                }

                let data = {};
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
            xhr.setRequestHeader('X-API-Key', wallpaper.configuration.APIKey);
            xhr.setRequestHeader('User-Agent','wallhaven-wallpaper-kde-plugin');
            xhr.timeout = 15000;
            xhr.send();
        });
    }

    function pickImage(d) {
        if (d.data.length > 0) {
            var index = 0;
            if (wallpaper.configuration.Sorting != "random") {
                index = root.currentIndex;
                if (index > 24) {
                    root.currentPage += 1;
                    root.currentIndex = 0;
                    refreshTimer.restart();
                    return;
                }
                root.currentIndex += 1;
            } else {
                index = Math.floor(Math.random() * d.data.length);
            }
            const imageObj = d.data[index] || {};
            root.currentUrl = imageObj.path;
            root.currentPage = d.meta.current_page;
            wallpaper.configuration.currentWallpaperThumbnail = imageObj.thumbs.small
            wallpaper.configuration.currentWallpaperUrl = imageObj.url
            wallpaper.configuration.ErrorText = "";
        } else {
            wallpaper.configuration.ErrorText = "No wallpapers found";
            wallpaper.configuration.currentWallpaperThumbnail = "";
            wallpaper.configuration.currentWallpaperUrl = "";
            root.currentUrl = "blackscreen.jpg";
        }
        loadImage();
    }

    function loadImage() {
        if (pendingImage) {
            pendingImage.statusChanged.disconnect(replaceWhenLoaded);
            pendingImage.destroy();
            pendingImage = null;
        }

        pendingImage = root.mainImage.createObject(root, {
            "source": root.currentUrl,
            "fillMode": root.fillMode,
            "sourceSize": root.sourceSize,
            "color": root.configColor,
            "blur": root.blur,
            "opacity": 0,
            "width": root.width,
            "height": root.height,
        });

        pendingImage.statusChanged.connect(replaceWhenLoaded);
        replaceWhenLoaded();
    }

    function replaceWhenLoaded() {
        if (pendingImage.status === Image.Loading) {
            return;
        }

        pendingImage.statusChanged.disconnect(replaceWhenLoaded);
        pendingImage.QQC2.StackView.onActivated.connect(wallpaper.repaintNeeded);
        pendingImage.QQC2.StackView.onRemoved.connect(pendingImage.destroy);
        root.replace(pendingImage, {}, QQC2.StackView.Transition);

        wallpaper.loading = false;

        pendingImage = null;
    }

    // replaceEnter: Transition {
    //     OpacityAnimator {
    //         id: replaceEnterOpacityAnimator
    //         from: 0
    //         to: 1
    //         // The value is to keep compatible with the old feeling defined by "TransitionAnimationDuration" (default: 1000)
    //         // 1 is HACK for https://bugreports.qt.io/browse/QTBUG-106797 to avoid flickering
    //         duration: root.doesSkipAnimation ? 1 : Math.round(PlasmaCore.Units.veryLongDuration * 2.5)
    //     }
    // }
    // Keep the old image around till the new one is fully faded in
    // If we fade both at the same time you can see the background behind glimpse through
    // replaceExit: Transition{
    //     PauseAnimation {
    //         duration: replaceEnterOpacityAnimator.duration
    //     }
    // }

}
