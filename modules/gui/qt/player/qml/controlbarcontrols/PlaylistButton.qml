/*****************************************************************************
 * Copyright (C) 2021 VLC authors and VideoLAN
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
import QtQuick


import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Player
import VLC.Util


Widgets.IconToolButton {
    id: playlistBtn

    text: VLCIcons.playlist
    rdIcon: "lists"
    rdIconChecked: "lists_state-active"
    // redesign: in the player the list button opens the queue sidebar (video 9:29, Decision 3);
    // elsewhere it keeps VLC's play queue panel
    onClicked: {
        if (MainCtx.playerView) {
            if (RdPanels.queueOpen)
                RdPanels.close()
            else
                RdPanels.open("queue")
            return
        }
        MainCtx.playqueuePanel.visible = !MainCtx.playqueuePanel.visible
        if (MainCtx.playqueuePanel.visible && MainCtx.playqueuePanel.docked) {
            playlistWidget.gainFocus(playlistBtn)
        }
    }
    checked: MainCtx.playerView ? RdPanels.queueOpen : MainCtx.playqueuePanel.visible

    description: qsTr("Play Queue")

    AccessibleCompat.id: "playqueueButton"
}
