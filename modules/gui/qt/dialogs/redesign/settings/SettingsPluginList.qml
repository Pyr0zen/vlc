/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
// redesign: VLC's plugins under the Extensions page's Advanced Options (video 18:28-18:47,
// P8-19 / P8-20: "plugins are VLC's internal functions, you're not really supposed to edit them
// here", so they move out of the add-ons list). The old dialog's table: Name, Capability, Score,
// with a search field. Rows are created as they scroll into the list's own 360 px view.
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Dialogs

SettingsSection {
    id: root

    property bool _wanted: false
    readonly property bool _requested: !!_page && (_page.advancedExpanded || _page.filtering)
    on_RequestedChanged: _build()
    Component.onCompleted: Qt.callLater(_build)

    function _build() {
        if (!_requested || _wanted)
            return
        _wanted = true
        SettingsCatalog.load()
    }

    title: qsTr("Plugins")
    keywords: qsTr("plugins modules capability score")

    SettingsRow {
        text: qsTr("Search plugins")
        description: qsTr("Plugins are the parts VLC is built from: each one reads, decodes, filters or shows one kind of media. VLC picks the plugin with the highest score that can handle the media.")
        keywords: qsTr("plugins modules capability score")

        Widgets.RdTextField {
            id: filterField

            implicitWidth: VLCStyle.dp(320)
            implicitHeight: VLCStyle.dp(36)
            placeholderText: qsTr("Name or capability")
            Accessible.name: qsTr("Search plugins")
        }
    }

    // Figma add-ons list box (BG/B2, 2 px BG/A4 stroke, radius 6)
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: VLCStyle.dp(360)
        Layout.topMargin: VLCStyle.dp(5)
        radius: VLCStyle.rd_radius_normal
        color: VLCStyle.palette.rdBgB2
        border.width: VLCStyle.dp(2)
        border.color: VLCStyle.palette.rdBgA4

        readonly property real _scoreWidth: VLCStyle.dp(70)
        readonly property real _capabilityWidth: Math.round((width - _scoreWidth) * 0.4)

        Row {
            id: columnHeader

            x: VLCStyle.dp(14)
            y: VLCStyle.dp(8)
            width: parent.width - 2 * VLCStyle.dp(14)
            height: VLCStyle.dp(24)

            HeaderText {
                width: parent.width - parent.parent._capabilityWidth - parent.parent._scoreWidth
                text: qsTr("Name")
            }
            HeaderText {
                width: parent.parent._capabilityWidth
                text: qsTr("Capability")
            }
            HeaderText {
                width: parent.parent._scoreWidth
                horizontalAlignment: Text.AlignRight
                text: qsTr("Score")
            }
        }

        ListView {
            id: list

            anchors.top: columnHeader.bottom
            anchors.left: columnHeader.left
            anchors.right: columnHeader.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: VLCStyle.dp(8)
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            model: root._wanted && SettingsCatalog.ready ? SettingsCatalog.plugins(filterField.text) : []

            T.ScrollBar.vertical: Widgets.ScrollBarExt {
                colorContext.palette: VLCStyle.palette
            }

            delegate: Row {
                required property var modelData

                width: list.width
                height: VLCStyle.dp(28)

                CellText {
                    width: parent.width - list.parent._capabilityWidth - list.parent._scoreWidth
                    text: modelData.title
                    color: VLCStyle.palette.rdFgA2
                }
                CellText {
                    width: list.parent._capabilityWidth
                    text: modelData.capability
                }
                CellText {
                    width: list.parent._scoreWidth
                    horizontalAlignment: Text.AlignRight
                    text: modelData.score
                }
            }
        }

        Text {
            anchors.centerIn: list
            visible: list.count === 0
            text: SettingsCatalog.ready ? qsTr("No plugin matches \"%1\"").arg(filterField.text)
                                        : qsTr("Loading the plugins...")
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: VLCStyle.palette.rdFgA3
        }
    }

    component HeaderText: Text {
        height: parent.height
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        font.family: VLCStyle.rd_fontFamily
        font.pixelSize: VLCStyle.rd_fontSize_toggle
        color: VLCStyle.palette.rdFgA4
    }

    component CellText: Text {
        height: parent.height
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        font.family: VLCStyle.rd_fontFamily
        font.pixelSize: VLCStyle.rd_fontSize_label
        color: VLCStyle.palette.rdFgA3
    }
}
