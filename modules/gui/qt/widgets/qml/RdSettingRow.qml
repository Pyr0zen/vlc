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

// Redesign settings row (Figma "Frame 60": 360 wide, padding 6,0,6,4): label on the left in
// Inter 14 FG/A3, the control (value box, toggle, dropdown, segmented control) on the right.
// Children go to the right of the label; `below` items (a slider, a full-width dropdown) go
// under the row at full width. Both stay in the item tree from the start.
import QtQuick
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style

ColumnLayout {
    id: root

    property alias text: label.text
    default property alias control: controlSlot.data
    property alias below: belowSlot.data
    property real rowHeight: VLCStyle.dp(48)

    readonly property SystemPalette rdPalette: VLCStyle.palette

    Layout.fillWidth: true
    spacing: VLCStyle.dp(5)

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: root.rowHeight

        Text {
            id: label

            anchors.left: parent.left
            anchors.leftMargin: VLCStyle.dp(4)
            anchors.right: controlSlot.left
            anchors.rightMargin: VLCStyle.dp(10)
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: root.rdPalette.rdFgA3
        }

        // sized by its child; the control is right-aligned
        Item {
            id: controlSlot

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }
    }

    // full-width items under the row; each child should bind its width to the row
    Column {
        id: belowSlot

        visible: children.length > 0
        Layout.fillWidth: true
    }
}
