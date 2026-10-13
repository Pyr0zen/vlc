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

// redesign: "Add to Playlist" of the file menu (video 13:30-13:33, P6-17): a new playlist with
// the file, or one of the playlists.
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.MediaLibrary

Widgets.RdMenuPanel {
    id: menu

    // MLItemIds or URLs of the media to add
    property var items: []

    // to the right of a row of another menu; parented to the window, so it stays when that
    // menu closes
    function openBeside(row) {
        parent = row.Window.contentItem
        const p = row.mapToItem(parent, row.width, 0)
        x = p.x + VLCStyle.dp(4)
        y = p.y - VLCStyle.dp(4)
        open()
    }

    // VLC's paged playlist list, alive only while the menu is open
    Loader {
        id: playlists

        active: menu.opened
        sourceComponent: MLPlaylistListModel {
            ml: MediaLib
        }
    }

    Widgets.RdOptionRow {
        text: qsTr("New Playlist...")
        rdIcon: "add"
        dimmed: true
        onClicked: RdLibraryNav.playlistDialogRequested({ items: menu.items })
    }

    // at most 6 rows high, rows are created as they scroll in
    ListView {
        id: list

        width: parent ? parent.width : 0
        height: Math.min(count, 6) * VLCStyle.rd_menuRowHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: playlists.item

        delegate: Widgets.RdOptionRow {
            required property var model

            width: list.width
            text: model.name ?? ""
            rdIcon: "playlist_two-tone-yes"
            onClicked: {
                RdLibraryStore.appendToPlaylist(model.id, menu.items)
                menu.close()
            }
        }
    }
}
