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
// The expand is instant (no animation seen in the video).
import QtQuick

import VLC.MainInterface
import VLC.Style

Item {
    id: root

    default property alias content: inner.data
    property bool expanded: false
    property string expandText: qsTr("Expand Settings")
    property string collapseText: qsTr("Collapse Settings")

    readonly property SystemPalette rdPalette: VLCStyle.palette

    implicitWidth: VLCStyle.dp(360)
    implicitHeight: card.height

    Rectangle {
        id: card

        width: parent.width
        height: header.height + (root.expanded ? inner.childrenRect.height + VLCStyle.dp(16) : 0)
        radius: VLCStyle.rd_radius_small
        color: root.expanded ? root.rdPalette.rdBgA2 : root.rdPalette.rdBgB2

        Item {
            id: header

            width: parent.width
            height: VLCStyle.dp(32)

            Text {
                anchors.left: parent.left
                anchors.leftMargin: VLCStyle.dp(12)
                anchors.verticalCenter: parent.verticalCenter
                text: root.expanded ? root.collapseText : root.expandText
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: headerMouse.containsMouse ? root.rdPalette.rdFgA2 : root.rdPalette.rdFgA3
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.dp(12)
                anchors.verticalCenter: parent.verticalCenter
                text: root.expanded ? VLCIcons.ic_fluent_chevron_down_24 : VLCIcons.ic_fluent_chevron_right_24
                font.family: VLCIcons.fontFamily
                font.pixelSize: VLCStyle.dp(16)
                color: root.rdPalette.rdFgA3
            }

            MouseArea {
                id: headerMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = !root.expanded
            }
        }

        Item {
            id: inner

            visible: root.expanded
            x: VLCStyle.dp(12)
            y: header.height + VLCStyle.dp(4)
            width: parent.width - VLCStyle.dp(24)
            height: childrenRect.height
        }
    }
}
