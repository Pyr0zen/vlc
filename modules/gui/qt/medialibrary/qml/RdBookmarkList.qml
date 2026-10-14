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
// the sidebar loads this list only when the media library is available. The rows are created on
// demand (RdListView).
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.MediaLibrary
import VLC.Widgets as Widgets

Widgets.RdListView {
    id: root

    model: MLBookmarkModel {
        id: bookmarkModel

        player: Player
        ml: MediaLib
    }

    // Enter on the current row jumps to it
    onActionAtIndex: (index) => bookmarkModel.select(bookmarkModel.index(index, 0))

    delegate: Widgets.RdListRow {
        required property int index
        required property var model

        width: root.contentWidth

        title: model.name ?? ""
        detail: model.time ?? ""

        Navigation.upAction: function() { root.focusRow(index - 1) }
        Navigation.downAction: function() { root.focusRow(index + 1) }
        // Enter acts on the focused row, also when it got focus by Tab
        onActiveFocusChanged: if (activeFocus) ListView.view.currentIndex = index

        onClicked: bookmarkModel.select(bookmarkModel.index(index, 0))
    }
}
