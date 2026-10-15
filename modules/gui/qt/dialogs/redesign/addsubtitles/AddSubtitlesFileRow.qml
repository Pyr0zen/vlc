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

// redesign (Add Subtitles "To This File", W6.5, F-10): a subtitle file to add (Figma component
// "subtitle one" 1919:9121): 36 px, radius 6, padding 0,8; subtitle icon FG/A3, 14 px gap, name
// Inter 14 FG/A1. A click checks it (Figma "selected": BG/B2 and the accent check at the right);
// several can be checked. Hovering shows the BG/B2 row without the check (the look of the
// "subtitle multiple" rows' hover).
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

T.ItemDelegate {
    id: root

    property bool selected: false

    readonly property SystemPalette rdPalette: VLCStyle.palette

    implicitHeight: VLCStyle.dp(36)

    leftPadding: VLCStyle.dp(8)
    rightPadding: VLCStyle.dp(8)
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus

    Accessible.role: Accessible.CheckBox
    Accessible.name: text
    Accessible.checkable: true
    Accessible.checked: selected

    background: Rectangle {
        radius: VLCStyle.rd_radius_normal
        color: (root.selected || root.hovered || root.visualFocus || root.highlighted)
               ? root.rdPalette.rdBgB2 : "transparent"
        // keyboard focus (the list's current row while the list has it)
        border.width: (root.visualFocus || root.highlighted) ? VLCStyle.dp(1) : 0
        border.color: root.rdPalette.rdFgA3
    }

    contentItem: Item {
        Widgets.RdIcon {
            id: fileIcon

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            name: "subtitle"
            color: root.rdPalette.rdFgA3
        }

        Text {
            anchors.left: fileIcon.right
            anchors.leftMargin: VLCStyle.dp(14)
            anchors.right: check.left
            anchors.rightMargin: VLCStyle.dp(16)
            anchors.verticalCenter: parent.verticalCenter

            text: root.text
            elide: Text.ElideMiddle
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: root.rdPalette.rdFgA1
        }

        Widgets.RdIcon {
            id: check

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.selected
            name: "check_state-active"
        }
    }
}
