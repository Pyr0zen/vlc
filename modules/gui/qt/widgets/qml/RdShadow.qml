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

// Redesign drop shadow for menus, dialogs and popups: Figma effect "bg blur + shadow"
// (drop shadow #000000 46%, x 0, y 8, blur 15). Uses VLC's RoundedRectangleShadow, which sizes
// itself around its parent and takes the parent's radius.
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

Widgets.RoundedRectangleShadow {
    id: root

    color: VLCStyle.palette.rdShadow
    yOffset: VLCStyle.dp(8)
    blurRadius: VLCStyle.dp(15)
}
