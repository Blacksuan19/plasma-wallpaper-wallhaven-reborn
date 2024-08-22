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

import Qt5Compat.GraphicalEffects
import QtMultimedia
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols 2.0 as KQuickControls
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid

Kirigami.FormLayout {
    id: root

    property alias cfg_Color: colorButton.color
    property int cfg_FillMode
    property alias cfg_Blur: blurRadioButton.checked
    property int cfg_WallpaperDelay: 60
    property int cfg_WallpaperLimit: 100
    property var wallpaperConfiguration: wallpaper.configuration
    property string cfg_APIKey
    property string cfg_Query
    property bool cfg_CategoryGeneral
    property bool cfg_CategoryAnime
    property bool cfg_CategoryPeople
    property bool cfg_PuritySFW
    property bool cfg_PuritySketchy
    property bool cfg_PurityNSFW
    property string cfg_Sorting
    property string cfg_TopRange
    property string cfg_SearchColor
    property alias formLayout: root

    twinFormLayouts: parentLayout

    Image {
        id: currentWallpaper

        source: wallpaperConfiguration.currentWallpaperThumbnail
        visible: wallpaperConfiguration.currentWallpaperThumbnail != ""
        Layout.topMargin: 10
        Layout.alignment: Qt.AlignCenter
    }

    Label {
        id: currentWallpaperLabel

        text: `<html><a href="${wallpaperConfiguration.currentWallpaperUrl}">${wallpaperConfiguration.currentWallpaperUrl || ""}</a></html>`
        onLinkActivated: function(url) {
            Qt.openUrlExternally(url);
        }
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

        text: cfg_APIKey
        Kirigami.FormData.label: i18n("API Key:")
        onTextChanged: {
            cfg_APIKey = text;
        }
    }

    TextField {
        id: queryInput

        text: cfg_Query
        Kirigami.FormData.label: i18n("Query:")
        onTextChanged: {
            cfg_Query = text;
        }
    }

    GroupBox {
        id: categoryInput

        Kirigami.FormData.label: i18n("Categories:")

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

    KQuickControls.ColorButton {
        id: searchColorButton

        visible: false
        Kirigami.FormData.label: i18n("Search Color:")
        dialogTitle: i18nd("plasma_wallpaper_org.kde.image", "Select Search Color")
        onColorChanged: cfg_SearchColor = color
        Component.onCompleted: color = cfg_SearchColor
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Change every:")

        SpinBox {
            id: delaySpinBox

            value: cfg_WallpaperDelay
            onValueChanged: cfg_WallpaperDelay = value
            stepSize: 1
            from: 1
            to: 50000
            editable: true
            textFromValue: function(value, locale) {
                return value + " minutes";
            }
            valueFromText: function(text, locale) {
                return text.replace(/ minutes/, '');
            }
        }

        Button {
            icon.name: "view-refresh"
            ToolTip.text: "Refresh Wallpaper"
            ToolTip.visible: top
            onClicked: {
                wallpaperConfiguration.RefetchSignal = !wallpaperConfiguration.RefetchSignal;
            }
        }

    }

    Label {
        id: errorLabel

        Layout.alignment: Qt.AlignLeft
        text: wallpaperConfiguration.ErrorText
        color: Kirigami.Theme.negativeTextColor
        visible: wallpaperConfiguration.ErrorText != ""
    }

}
