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

// Redesign small value tooltip (Figma "audio value": 121x37, padding 10, radius 6,
// BG/B1 95% + "bg blur + shadow", Inter 400 14 FG/A1). Also used for the info-icon popovers.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style

T.Popup {
    id: control

    property string text: ""
    property int maximumTextWidth: VLCStyle.dp(320)
    property int minimumWidth: VLCStyle.dp(60)
    property int textAlignment: Text.AlignHCenter

    // a long text wraps at maximumTextWidth instead of widening the popup
    implicitWidth: Math.max(minimumWidth, Math.min(label.implicitWidth, maximumTextWidth) + leftPadding + rightPadding)
    implicitHeight: label.implicitHeight + topPadding + bottomPadding

    padding: VLCStyle.dp(10)
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside

    contentItem: Text {
        id: label

        text: control.text
        width: Math.min(Math.max(implicitWidth, control.availableWidth), control.maximumTextWidth)
        wrapMode: Text.WordWrap
        horizontalAlignment: control.textAlignment
        font.family: VLCStyle.rd_fontFamily
        font.pixelSize: VLCStyle.rd_fontSize_label
        color: VLCStyle.palette.rdFgA1
    }

    background: Rectangle {
        radius: VLCStyle.rd_radius_normal
        color: VLCStyle.palette.rdBgB1Transparent

        RdShadow { }
    }
}
