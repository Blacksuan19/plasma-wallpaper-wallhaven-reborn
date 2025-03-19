/*
 *  Copyright 2013 Marco Martin <mart@kde.org>
 *  Copyright 2014 Kai Uwe Broulik <kde@privat.broulik.de>
 *  Copyright 2022 Kyle Paulsen <kyle.a.paulsen@gmail.com>
 *  Copyright 2022 Link Dupont <link@sub-pop.net>
 *  Copyright 2024 Abubakar Yagoub <plasma@blacksuan19.dev>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  2.010-1301, USA.
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols 2.0 as KQuickControls

Kirigami.FormLayout {
    id: root

    property var wallpaperConfiguration: wallpaper.configuration
    property alias formLayout: root
    property alias cfg_Color: colorButton.color
    property alias cfg_Blur: blurRadioButton.checked
    property alias cfg_APIKey: apiKeyInput.text
    property alias cfg_Query: queryInput.text
    property int cfg_FillMode
    property int cfg_WallpaperDelay: 60
    property int cfg_WallpaperLimit: 100
    property int cfg_RetryRequestCount: 3
    property int cfg_RetryRequestDelay: 5
    property int cfg_ResolutionX: 1920
    property int cfg_ResolutionY: 1080
    property string cfg_Sorting
    property string cfg_TopRange
    property string cfg_SearchColor
    property bool cfg_CategoryGeneral
    property bool cfg_CategoryAnime
    property bool cfg_CategoryPeople
    property bool cfg_PuritySFW
    property bool cfg_PuritySketchy
    property bool cfg_PurityNSFW
    property bool cfg_RefreshNotification
    property bool cfg_ErrorNotification
    property bool cfg_RatioAny
    property bool cfg_Ratio169
    property bool cfg_Ratio1610
    property bool cfg_RatioCustom
    property string cfg_RatioCustomValue

    function refreshImage() {
        wallpaperConfiguration.RefetchSignal = !wallpaperConfiguration.RefetchSignal;
    }

    Image {
        id: currentWallpaper

        Kirigami.FormData.label: i18n("Current Wallpaper:")
        height: 200
        width: 200
        source: wallpaperConfiguration.currentWallpaperThumbnail
        visible: wallpaperConfiguration.currentWallpaperThumbnail != ""
        Layout.topMargin: 10
        Layout.alignment: Qt.AlignCenter
    }

    ComboBox {
        id: resizeComboBox

        function setMethod() {
            for (var i = 0; i < model.length; i++) {
                if (model[i]["fillMode"] === wallpaperConfiguration.FillMode) {
                    resizeComboBox.currentIndex = i;
                    var tl = model[i]["label"].length;
                }
            }
        }

        Kirigami.FormData.label: i18nd("plasma_wallpaper_org.kde.image", "Positioning:")
        model: [{
            "label": i18nd("plasma_wallpaper_org.kde.image", "Scaled and Cropped"),
            "fillMode": Image.PreserveAspectCrop
        }, {
            "label": i18nd("plasma_wallpaper_org.kde.image", "Scaled"),
            "fillMode": Image.Stretch
        }, {
            "label": i18nd("plasma_wallpaper_org.kde.image", "Scaled, Keep Proportions"),
            "fillMode": Image.PreserveAspectFit
        }, {
            "label": i18nd("plasma_wallpaper_org.kde.image", "Centered"),
            "fillMode": Image.Pad
        }, {
            "label": i18nd("plasma_wallpaper_org.kde.image", "Tiled"),
            "fillMode": Image.Tile
        }]
        textRole: "label"
        onCurrentIndexChanged: cfg_FillMode = model[currentIndex]["fillMode"]
        Component.onCompleted: setMethod()
    }

    ButtonGroup {
        id: backgroundGroup
    }

    RadioButton {
        id: blurRadioButton

        visible: cfg_FillMode === Image.PreserveAspectFit || cfg_FillMode === Image.Pad
        Kirigami.FormData.label: i18nd("plasma_wallpaper_org.kde.image", "Background:")
        text: i18nd("plasma_wallpaper_org.kde.image", "Blur")
        ButtonGroup.group: backgroundGroup
    }

    RowLayout {
        id: colorRow

        visible: cfg_FillMode === Image.PreserveAspectFit || cfg_FillMode === Image.Pad

        RadioButton {
            id: colorRadioButton

            text: i18nd("plasma_wallpaper_org.kde.image", "Solid color")
            checked: !cfg_Blur
            ButtonGroup.group: backgroundGroup
        }

        KQuickControls.ColorButton {
            id: colorButton

            dialogTitle: i18nd("plasma_wallpaper_org.kde.image", "Select Background Color")
        }

    }

    TextField {
        id: apiKeyInput

        text: root.cfg_APIKey
        placeholderText: i18n("Optional API Key to access NSFW content")
        Kirigami.FormData.label: i18n("API Key:")
        leftPadding: 12
        onTextChanged: cfg_APIKey = text
    }

    RowLayout {
        id: queryRow

        width: parent.width
        Layout.fillWidth: true
        Kirigami.FormData.label: i18n("Query:")

        TextField {
            id: queryInput

            Layout.fillWidth: true
            text: root.cfg_Query
            placeholderText: i18n("tag1, tag2, @username, id:123456")
            ToolTip.text: "Search terms separated by comma"
            ToolTip.visible: queryInput.activeFocus
            leftPadding: 12
        }

        Button {
            icon.name: "dialog-information-symbolic"
            ToolTip.text: i18n("<b>Supported Query Formats:</b><ul><li>tag names: <code>tag1</code></li><li>wallhaven user name: <code>@username</code></li><li>wallpapers similar to a wallpaper with id: <code>id:123456</code></li><li>combination of all: <code>@username,tag1,tag2,id:123456</code></li></ul>this will find a wallpaper matching any of the tags, the user, or the id each time a new wallpaper is fetched.")
            highlighted: true
            hoverEnabled: true
            ToolTip.visible: hovered
            Kirigami.Theme.inherit: false
            flat: true
            Layout.alignment: Qt.AlignRight
            Layout.fillWidth: false
        }

    }

    GroupBox {
        id: categoryInput

        Kirigami.FormData.label: i18n("Categories:")
        onActiveFocusChanged: {
            if (!activeFocus)
                refreshImage();

        }

        RowLayout {
            anchors.fill: parent

            CheckBox {
                text: i18n("General")
                checked: cfg_CategoryGeneral
                onToggled: {
                    cfg_CategoryGeneral = checked;
                }
            }

            CheckBox {
                text: i18n("Anime")
                checked: cfg_CategoryAnime
                onToggled: {
                    cfg_CategoryAnime = checked;
                }
            }

            CheckBox {
                text: i18n("People")
                checked: cfg_CategoryPeople
                onToggled: {
                    cfg_CategoryPeople = checked;
                }
            }

        }

    }

    GroupBox {
        id: purityInput

        Kirigami.FormData.label: i18n("Purity:")
        onActiveFocusChanged: {
            if (!activeFocus)
                refreshImage();

        }

        RowLayout {
            anchors.fill: parent

            CheckBox {
                text: i18n("SFW")
                checked: cfg_PuritySFW
                onToggled: {
                    cfg_PuritySFW = checked;
                }
            }

            CheckBox {
                text: i18n("Sketchy")
                checked: cfg_PuritySketchy
                onToggled: {
                    cfg_PuritySketchy = checked;
                }
            }

            CheckBox {
                text: i18n("NSFW")
                checked: cfg_PurityNSFW
                onToggled: {
                    cfg_PurityNSFW = checked;
                }
            }

        }

    }

    GroupBox {
        id: aspectRatioInput

        Kirigami.FormData.label: i18n("Aspect ratio:")
        Layout.fillWidth: false

        RowLayout {
            anchors.fill: parent

            CheckBox {
                text: i18n("Any")
                checked: cfg_RatioAny
                onToggled: {
                    cfg_RatioAny = checked;
                }
            }

            CheckBox {
                text: "16x9"
                checked: cfg_Ratio169
                enabled: !cfg_RatioAny
                onToggled: {
                    cfg_Ratio169 = checked;
                }
            }

            CheckBox {
                text: "16x10"
                checked: cfg_Ratio1610
                enabled: !cfg_RatioAny
                onToggled: {
                    cfg_Ratio1610 = checked;
                }
            }

            CheckBox {
                text: i18n("Custom")
                checked: cfg_RatioCustom
                enabled: !cfg_RatioAny
                onToggled: {
                    cfg_RatioCustom = checked;
                }
            }

            TextField {
                id: customRatioInput

                ToolTip.text: "Custom aspect ratios separated by comma (e.g. 16x9,16x10)"
                ToolTip.visible: customRatioInput.activeFocus
                width: 50
                text: cfg_RatioCustomValue
                visible: cfg_RatioCustom
                enabled: !cfg_RatioAny
                onTextChanged: {
                    cfg_RatioCustomValue = text;
                }
            }

        }

    }

    RowLayout {
        id: resolutionRow

        width: parent.width
        Layout.fillWidth: true
        Kirigami.FormData.label: i18n("Resolution:")

        SpinBox {
            id: resXInput

            value: cfg_ResolutionX
            onValueChanged: cfg_ResolutionX = value
            stepSize: 1
            from: 1
            to: 15360
            editable: true
            textFromValue: function(value, locale) {
                return " " + value + "px";
            }
            valueFromText: function(text, locale) {
                return text.replace(/px/, '');
            }
        }

        SpinBox {
            id: resYInput

            value: cfg_ResolutionY
            onValueChanged: cfg_ResolutionY = value
            stepSize: 1
            from: 1
            to: 15360
            editable: true
            textFromValue: function(value, locale) {
                return " " + value + "px";
            }
            valueFromText: function(text, locale) {
                return text.replace(/px/, '');
            }
        }

    }

    GroupBox {
        id: notificationToggle

        Kirigami.FormData.label: i18n("Show Notification:")
        Layout.bottomMargin: 20

        RowLayout {
            anchors.fill: parent

            CheckBox {
                text: i18n("Refresh")
                checked: cfg_RefreshNotification
                ToolTip.text: "Show a notification when the wallpaper is refreshed"
                ToolTip.visible: hovered
                onToggled: {
                    cfg_RefreshNotification = checked;
                    wallpaperConfiguration.refreshNotification = checked;
                }
            }

            CheckBox {
                text: i18n("Error")
                checked: cfg_ErrorNotification
                ToolTip.text: "Show a notification when an error occurs"
                ToolTip.visible: hovered
                onToggled: {
                    cfg_ErrorNotification = checked;
                    wallpaperConfiguration.errorNotification = checked;
                }
            }

        }

    }

    ComboBox {
        id: sortingInput

        Kirigami.FormData.label: i18n("Sorting:")
        textRole: "text"
        valueRole: "value"
        model: [{
            "text": i18n("Date Added"),
            "value": "date_added"
        }, {
            "text": i18n("Relevance"),
            "value": "relevance"
        }, {
            "text": i18n("Random"),
            "value": "random"
        }, {
            "text": i18n("Views"),
            "value": "views"
        }, {
            "text": i18n("Favorites"),
            "value": "favorites"
        }, {
            "text": i18n("Top List"),
            "value": "toplist"
        }]
        Component.onCompleted: currentIndex = indexOfValue(cfg_Sorting)
        onActivated: cfg_Sorting = currentValue
    }

    ComboBox {
        id: topRangeInput

        Kirigami.FormData.label: i18n("Top List Range:")
        visible: cfg_Sorting === "toplist"
        textRole: "text"
        valueRole: "value"
        model: [{
            "text": i18n("One day"),
            "value": "1d"
        }, {
            "text": i18n("Three days"),
            "value": "3d"
        }, {
            "text": i18n("One week"),
            "value": "1w"
        }, {
            "text": i18n("One month"),
            "value": "1M"
        }, {
            "text": i18n("Three months"),
            "value": "3M"
        }, {
            "text": i18n("Six months"),
            "value": "6M"
        }, {
            "text": i18n("One year"),
            "value": "1y"
        }]
        Component.onCompleted: currentIndex = indexOfValue(cfg_TopRange)
        onActivated: cfg_TopRange = currentValue
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Change every:")
        Layout.bottomMargin: 10

        SpinBox {
            id: delaySpinBox

            value: cfg_WallpaperDelay
            onValueChanged: cfg_WallpaperDelay = value
            stepSize: 1
            from: 1
            to: 50000
            editable: true
            textFromValue: function(value, locale) {
                return " " + value + " minutes";
            }
            valueFromText: function(text, locale) {
                return text.replace(/ minutes/, '');
            }
        }

        Button {
            icon.name: "view-refresh"
            ToolTip.text: "Refresh Wallpaper"
            ToolTip.visible: hovered
            onClicked: {
                focus = false;
                refreshImage();
            }
        }

    }

    RowLayout {
        Kirigami.FormData.label: i18n("Retry Failed request every:")
        Layout.bottomMargin: 10

        SpinBox {
            id: retryDelaySpinBox

            value: cfg_RetryRequestDelay
            onValueChanged: cfg_RetryRequestDelay = value
            stepSize: 1
            from: 1
            to: 60
            editable: true
            textFromValue: function(value, locale) {
                return " " + value + " seconds";
            }
            valueFromText: function(text, locale) {
                return text.replace(/ seconds/, '');
            }
        }

        SpinBox {
            id: retryCountSpinBox

            value: cfg_RetryRequestCount
            onValueChanged: cfg_RetryRequestCount = value
            stepSize: 1
            from: 1
            to: 10
            editable: true
            ToolTip.text: "max number of retries"
            ToolTip.visible: hovered
            textFromValue: function(value, locale) {
                return " " + value + " times";
            }
            valueFromText: function(text, locale) {
                return text.replace(/ times/, '');
            }
        }

    }

}
