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

// redesign: drop target of the queue (video 11:44-11:49, P5-24, IB-15; 20:20-20:23, P8-34):
// library rows dragged over the video, and files from the file manager, join the queue where
// they are dropped, or at its end. The new row appears at once (the queue model updates).
// Library rows carry their URLs in `rdDragUrls` (RdLibraryRow / RdLibraryCard drag ghost).
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Playlist

DropArea {
    id: root

    // the queue's list, to insert at the dropped row; null appends
    property Item view: null

    function _urls(drag) {
        if (drag.source && drag.source.rdDragUrls)
            return drag.source.rdDragUrls
        const urls = []
        if (drag.hasUrls) {
            for (let i = 0; i < drag.urls.length; ++i)
                urls.push(drag.urls[i].toString())
        }
        return urls
    }

    onEntered: (drag) => {
        drag.accepted = _urls(drag).length > 0
    }

    onDropped: (drop) => {
        const urls = _urls(drop)
        if (urls.length === 0)
            return
        let index = -1
        if (view && view.contentItem) {
            const p = root.mapToItem(view.contentItem, drop.x, drop.y)
            index = view.indexAt(p.x, p.y)
        }
        if (index >= 0)
            MainPlaylistController.insert(index, urls, false)
        else
            MainPlaylistController.append(urls, false)
        drop.accept()
    }

    // where it will land (Figma accent: the drop target lights up)
    Rectangle {
        anchors.fill: parent
        visible: root.containsDrag
        color: "transparent"
        radius: VLCStyle.rd_radius_panel
        border.width: VLCStyle.dp(2)
        border.color: VLCStyle.palette.rdAccentMain
    }
}
