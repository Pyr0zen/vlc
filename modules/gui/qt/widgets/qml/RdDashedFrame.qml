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

// Redesign dashed outline (Figma Customize Player: 1 px inside stroke FG/A3 #6B6B6B, dashes 4 / 4,
// half dashes at the corners). Qt Quick has no dashed border (and VLC's Qt has no Shapes), so a
// small shader draws it (shaders/RdDashedFrame.frag). Size it like the outlined area.
import QtQuick
import QtQuick.Window

import VLC.MainInterface
import VLC.Style

ShaderEffect {
    id: root

    property color color: VLCStyle.palette.rdFgA3
    property real lineWidth: VLCStyle.dp(1)
    property real dash: VLCStyle.dp(4)
    property real gap: VLCStyle.dp(4)

    readonly property size size: Qt.size(width, height)
    readonly property real dpr: Screen.devicePixelRatio

    blending: true

    fragmentShader: "qrc:///shaders/RdDashedFrame.frag.qsb"

    Accessible.ignored: true
}
