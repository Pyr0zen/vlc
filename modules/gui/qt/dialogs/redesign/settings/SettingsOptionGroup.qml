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
// redesign: one plugin (or one part of VLC itself) in a page's "All Other Options": a row with
// its name and the number of its settings; clicking it shows them below, one SettingsOption
// each, created only then. The dialog's search finds the plugin by any of its settings.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

SettingsRow {
    id: root

    // { id, title, options: [name], keywords } (SettingsCatalog.groups())
    required property var group
    property bool expanded: false

    text: group.title
    keywords: group.keywords

    T.AbstractButton {
        id: toggleButton

        implicitWidth: countText.implicitWidth + chevron.width + VLCStyle.dp(10) + leftPadding + rightPadding
        implicitHeight: VLCStyle.dp(32)
        leftPadding: VLCStyle.dp(8)
        rightPadding: VLCStyle.dp(4)

        focusPolicy: Qt.StrongFocus
        hoverEnabled: true

        Accessible.role: Accessible.Button
        Accessible.name: root.expanded ? qsTr("Hide the settings of %1").arg(root.text)
                                       : qsTr("Show the settings of %1").arg(root.text)

        Keys.onReturnPressed: clicked()
        Keys.onEnterPressed: clicked()

        onClicked: root.expanded = !root.expanded

        background: Rectangle {
            radius: VLCStyle.rd_radius_small
            color: toggleButton.hovered ? VLCStyle.palette.rdHoverOverlay : "transparent"
            border.width: toggleButton.visualFocus ? VLCStyle.dp(1) : 0
            border.color: VLCStyle.palette.rdFgA3
        }

        contentItem: Row {
            spacing: VLCStyle.dp(10)

            Text {
                id: countText

                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("%n setting(s)", "", root.group.options.length)
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: VLCStyle.palette.rdFgA3
            }

            Widgets.RdIcon {
                id: chevron

                anchors.verticalCenter: parent.verticalCenter
                name: root.expanded ? "chevron_direction-down" : "chevron_direction-right"
                color: VLCStyle.palette.rdFgA2
            }
        }
    }

    below: [
        Loader {
            width: root.width
            active: root.expanded
            visible: active

            sourceComponent: Column {
                leftPadding: VLCStyle.dp(16)

                Repeater {
                    model: root.group.options

                    delegate: SettingsOption {
                        required property string modelData

                        width: root.width - VLCStyle.dp(16)
                        option: modelData
                    }
                }
            }
        }
    ]
}
