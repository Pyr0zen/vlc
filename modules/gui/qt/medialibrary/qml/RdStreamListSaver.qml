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

// redesign: Open Network Stream with a Playlist Name (video 13:09-13:20, P6-14): the links are
// saved as stream lists under Network and the library shows the first one ("Network > Index",
// 13:19), next to the video when the player is shown. Loaded by OpenNetworkStreamDialog only
// when the media library is available (VLC.MediaLibrary needs it).
import QtQuick

import VLC.MainInterface
import VLC.Player
import VLC.MediaLibrary

Item {
    // name: the Playlist Name; urls: the links, one stream list each
    function save(name, urls) {
        if (name === "" || urls.length === 0)
            return
        for (let i = 0; i < urls.length; ++i)
            RdLibraryStore.addStreamList(urls.length > 1 ? name + " " + (i + 1) : name, urls[i])
        RdLibraryNav.openPath([
            { page: "network", title: qsTr("Network") },
            { page: "streams", url: urls[0], title: urls.length > 1 ? name + " 1" : name }
        ])
        if (MainCtx.playerView)
            RdPanels.libraryOpen = true
    }
}
