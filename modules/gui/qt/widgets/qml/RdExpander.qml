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

// Redesign "Expand Settings >" / "Collapse Settings v" card (video 8:44-8:52, Figma
// "Audio - *" / "Video - *" components). Collapsed: full-width near-black bar with a chevron.
// Expanded: a lighter card whose header collapses it again; content goes inside the card.
// The expand is instant (no animation seen in the video). The content is created the first time
// the card expands, then kept so it expands again instantly; a collapsed card costs nothing
// (INTERACTIONS.md section 0).
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style

Item {
    id: root

    // the card's content, declared inline like children: `RdExpander { ColumnLayout { ... } }`
    default property Component content
    property bool expanded: false
    property string expandText: qsTr("Expand Settings")
    property string collapseText: qsTr("Collapse Settings")

    readonly property SystemPalette rdPalette: VLCStyle.palette

    implicitWidth: VLCStyle.dp(360)
    implicitHeight: card.height

    Rectangle {
        id: card

        width: parent.width
        height: header.height + (root.expanded ? inner.height + VLCStyle.dp(16) : 0)
        radius: VLCStyle.rd_radius_normal
        color: root.expanded ? root.rdPalette.rdBgA2 : root.rdPalette.rdBgB2

        // Figma "Video - Essential" bar: 360x48, radius 6, padding 0,10,0,16
        T.AbstractButton {
            id: header

            width: parent.width
            height: VLCStyle.dp(48)

            focusPolicy: Qt.StrongFocus
            hoverEnabled: true
            Accessible.role: Accessible.Button
            Accessible.name: root.expanded ? root.collapseText : root.expandText

            Keys.priority: Keys.AfterItem
            Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

            onClicked: root.expanded = !root.expanded

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            background: Rectangle {
                radius: VLCStyle.rd_radius_normal
                color: "transparent"
                border.width: header.visualFocus ? VLCStyle.dp(1) : 0
                border.color: root.rdPalette.rdFgA3
            }

            contentItem: Item {
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: VLCStyle.dp(16)
                    anchors.verticalCenter: parent.verticalCenter
                    text: header.Accessible.name
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_label
                    color: header.hovered ? root.rdPalette.rdFgA2 : root.rdPalette.rdFgA3
                }

                RdIcon {
                    anchors.right: parent.right
                    anchors.rightMargin: VLCStyle.dp(10)
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.expanded ? "chevron_direction-down" : "chevron_direction-right"
                    color: root.rdPalette.rdFgA3
                }
            }
        }

        Loader {
            id: inner

            visible: root.expanded
            x: VLCStyle.dp(12)
            y: header.height + VLCStyle.dp(4)
            width: parent.width - VLCStyle.dp(24)

            active: false
            sourceComponent: root.content

            // first expand: create the content, then keep it
            Binding on active {
                when: root.expanded
                value: true
                restoreMode: Binding.RestoreNone
            }
        }
    }
}
