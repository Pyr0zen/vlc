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

// Redesign panel background (side panels, tracks popup, library panel, dialogs):
// BG/B1 95% by default, radius 10. Background blur ("bg blur", radius 50) is applied by
// the hosting view where the video surface allows it (see BUILD_PLAN.md risk 2).
import QtQuick

import VLC.MainInterface
import VLC.Style

Rectangle {
    property bool withShadow: false

    radius: VLCStyle.rd_radius_panel
    color: VLCStyle.palette.rdBgB1Transparent

    RdShadow {
        visible: parent.withShadow
    }

    // the panel is solid to the mouse: a click or the wheel on its empty parts does not reach
    // what is behind it (the video would pause or change the volume, the player would take the
    // click as a click outside the panel and close it)
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        // the player may have hidden the cursor over the video
        cursorShape: Qt.ArrowCursor
        onWheel: (wheel) => { wheel.accepted = true }
    }
}
