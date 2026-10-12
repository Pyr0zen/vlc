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

// redesign: subtitle button of the control bar (video 4:30-4:35): opens the tracks popup on the
// Subtitles tab; orange while open. Decision 5.
import QtQuick

import VLC.Widgets as Widgets
import VLC.Style
import VLC.Player
import VLC.Util

Widgets.IconToolButton {
    id: root

    signal requestLockUnlockAutoHide(bool lock)
    signal menuOpened(var menu)

    text: VLCIcons.audiosub
    rdIcon: "subtitles"
    rdIconChecked: "subtitles_state-active"
    description: qsTr("Subtitles")

    checked: !paintOnly && RdPanels.current === "subtitles"

    AccessibleCompat.id: "subtitleTracksButton"

    onClicked: RdPanels.toggle("subtitles")

    function forceUnlock() {
        if (RdPanels.tracksOpen)
            RdPanels.close()
    }
}
