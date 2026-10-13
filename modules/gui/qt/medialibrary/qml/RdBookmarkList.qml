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

// redesign: bookmarks of the current file in the queue sidebar's Bookmarks tab (video
// 15:08-15:16). Part of the media library module: VLC keeps bookmarks in the media library, so
// the sidebar loads this list only when the media library is available.
import QtQuick
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.MediaLibrary
import VLC.Widgets as Widgets

ColumnLayout {
    id: root

    readonly property int count: bookmarks.count

    spacing: VLCStyle.dp(12)

    MLBookmarkModel {
        id: bookmarkModel

        player: Player
        ml: MediaLib
    }

    Repeater {
        id: bookmarks

        model: bookmarkModel

        delegate: Widgets.RdListRow {
            required property int index
            required property var model

            title: model.name ?? ""
            detail: model.time ?? ""
            onClicked: bookmarkModel.select(bookmarkModel.index(index, 0))
        }
    }
}
