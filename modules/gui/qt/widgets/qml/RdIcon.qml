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

// redesign: one icon of the Figma "icon" component set (pixmaps/redesign/<name>.svg, 24x24).
// The SVGs carry colorizer slots instead of fixed colors, so every icon follows the theme and
// the live accent: color1 (#FF00FF) is the icon's main color (gray FG/A2 in the design, the
// button's state color here), color2 (#00FFFF) the two-tone Accent/DIm part, accent (#FF8800)
// the active / accent part.
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Util

Image {
    id: root

    // file name without extension, e.g. "settings", "subtitles_state-active"
    property string name: ""
    property color color: VLCStyle.palette.rdFgA2
    property color color2: VLCStyle.palette.rdAccentDim
    property color accentColor: VLCStyle.palette.rdAccentMain
    property real size: VLCStyle.rd_iconSize

    width: size
    height: size

    fillMode: Image.PreserveAspectFit
    // a new color (theme, accent, hover) loads a new image in the background: keep showing the
    // current one meanwhile instead of a blank frame, so a theme switch shows no gap (P8-41)
    retainWhileLoading: true
    // logical size: Image already loads at sourceSize x the window's device pixel ratio
    sourceSize: Qt.size(size, size)

    // the colorizer writes opaque colors, so the main color's alpha (disabled states,
    // light theme tool buttons) is applied to the whole icon
    opacity: color.a

    source: name === "" ? ""
                        : SVGColorImage.colorize("qrc:///rd/" + name + ".svg")
                              .color1(Qt.rgba(root.color.r, root.color.g, root.color.b, 1))
                              .color2(root.color2)
                              .accent(root.accentColor)
                              .uri()

    Accessible.ignored: true
}
