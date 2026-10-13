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

// Redesign section header (Figma "Defaults", "Synchronization", "Appearance"):
// Inter 500 16 px, FG/A1, 39 px row with padding 20,24,0,24.
import QtQuick

import VLC.MainInterface
import VLC.Style

// Text's implicit size is read-only, so the 39 px row is an Item holding the text.
Item {
    property alias text: label.text

    implicitHeight: VLCStyle.dp(39)
    implicitWidth: label.implicitWidth

    Text {
        id: label

        anchors.fill: parent
        topPadding: VLCStyle.dp(20)
        leftPadding: VLCStyle.dp(24)
        rightPadding: VLCStyle.dp(24)
        font.family: VLCStyle.rd_fontFamily
        font.pixelSize: VLCStyle.rd_fontSize_header
        font.weight: Font.Medium
        color: VLCStyle.palette.rdFgA1
        elide: Text.ElideRight
    }
}
