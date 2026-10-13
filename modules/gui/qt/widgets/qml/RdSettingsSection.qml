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

// Redesign settings section (video 8:29 IA-36, Figma "Frame 99" + "Frame 80"): a 1 px
// Divider/Dim line between sections, the header (Inter 500 16 FG/A1, padding 20,24,0,24) and
// the rows in a group with padding 10,20,20,20 and 5 px between rows.
import QtQuick
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style

ColumnLayout {
    id: root

    property alias title: header.text
    property bool showDivider: true
    // small note under the header (e.g. "Applies from the next file")
    property string note: ""
    default property alias content: group.data

    Layout.fillWidth: true
    spacing: 0

    Rectangle {
        visible: root.showDivider
        Layout.fillWidth: true
        Layout.preferredHeight: VLCStyle.dp(1)
        color: VLCStyle.palette.rdDividerDim
    }

    RdSectionHeader {
        id: header

        visible: text !== ""
        Layout.fillWidth: true
    }

    Text {
        visible: root.note !== ""
        Layout.fillWidth: true
        leftPadding: VLCStyle.dp(24)
        rightPadding: VLCStyle.dp(24)
        topPadding: VLCStyle.dp(4)
        text: root.note
        wrapMode: Text.WordWrap
        font.family: VLCStyle.rd_fontFamily
        font.pixelSize: VLCStyle.rd_fontSize_toggle
        color: VLCStyle.palette.rdFgA3
    }

    ColumnLayout {
        id: group

        Layout.fillWidth: true
        Layout.leftMargin: VLCStyle.dp(20)
        Layout.rightMargin: VLCStyle.dp(20)
        Layout.topMargin: VLCStyle.dp(10)
        Layout.bottomMargin: VLCStyle.dp(20)
        spacing: VLCStyle.dp(5)
    }
}
