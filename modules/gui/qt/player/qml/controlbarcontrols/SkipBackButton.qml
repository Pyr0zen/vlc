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


import VLC.Widgets as Widgets
import VLC.Style
import VLC.Player
import VLC.Util

Widgets.IconToolButton {
    id: stepBackBtn

    enabled: Player.seekable

    // redesign: 15 s back (Figma "Player - Music" and the Customize Player item "Backward 15s"),
    // relative to where the player is, so quick clicks add up
    readonly property int jumpSeconds: 15

    text: VLCIcons.skip_back
    rdIcon: "backward-15-sec"
    onClicked: Player.jumpSeconds(-jumpSeconds)
    description: qsTr("Back %1 second", "Back %1 seconds", jumpSeconds).arg(jumpSeconds)

    AccessibleCompat.id: "skipBackButton"
}
