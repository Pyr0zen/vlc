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

// Redesign text input (Figma "Frame 86"): BG/B2 fill, 2 px BG/A4 border, radius 6,
// padding 8,18,8,12, placeholder FG/A4, text FG/2. Border turns accent while editing.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style

T.TextField {
    id: control

    readonly property SystemPalette rdPalette: VLCStyle.palette

    implicitWidth: VLCStyle.dp(240)
    implicitHeight: VLCStyle.dp(37)

    topPadding: VLCStyle.dp(8)
    bottomPadding: VLCStyle.dp(8)
    leftPadding: VLCStyle.dp(12)
    rightPadding: VLCStyle.dp(18)

    font.family: VLCStyle.rd_fontFamily
    font.pixelSize: VLCStyle.rd_fontSize_label
    color: rdPalette.rdFg2
    placeholderTextColor: rdPalette.rdFgA4
    selectionColor: rdPalette.rdAccentDim
    selectedTextColor: rdPalette.rdFg1
    verticalAlignment: TextInput.AlignVCenter

    background: Rectangle {
        radius: VLCStyle.rd_radius_normal
        color: control.rdPalette.rdBgB2
        border.width: VLCStyle.dp(2)
        border.color: control.activeFocus ? control.rdPalette.rdAccentMain
                                          : (control.hovered ? control.rdPalette.rdDividerBright
                                                             : control.rdPalette.rdBgA4)
    }
}
