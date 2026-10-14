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

// redesign: Open Network Stream with a Playlist Name (video 13:09-13:20, P6-14): links to
// playlists (m3u, pls, xspf ...) are saved as stream lists under Network and the library shows
// the first one ("Network > Index", 13:19), next to the video when the player is shown. Loaded
// by OpenNetworkStreamDialog only when the media library is available (VLC.MediaLibrary needs
// it); the dialog sends other links to DialogsProvider.openNetworkStreams (a media library
// playlist, W6.4).
import QtQuick

import VLC.MainInterface
import VLC.Player
import VLC.Dialogs
import VLC.MediaLibrary

Item {
    // a link to a playlist of streams (the TV channel lists of 13:16)
    function isPlaylistUrl(url) {
        return /\.(m3u8?|pls|xspf|asx)(\?|#|$)/i.test(url)
    }

    // name: the Playlist Name; urls: playlist links, one stream list each
    function save(name, urls) {
        if (name === "" || urls.length === 0)
            return
        let first = null
        let invalid = 0
        for (let i = 0; i < urls.length; ++i) {
            const entry = RdLibraryStore.addStreamList(urls.length > 1 ? name + " " + (i + 1) : name, urls[i])
            if (!entry.url)
                invalid += 1
            else if (!first)
                first = entry
        }
        if (invalid > 0)
            DialogsProvider.messageDialog(qsTr("%1 link could not be opened.", "%1 links could not be opened.", invalid).arg(invalid),
                                          qsTr("Open Network Stream"))
        if (!first)
            return
        // a link saved before opens its existing list
        RdLibraryNav.openPath([
            { page: "network", title: qsTr("Network") },
            { page: "streams", url: first.url, title: first.name }
        ])
        if (MainCtx.playerView)
            RdPanels.libraryOpen = true
    }
}
