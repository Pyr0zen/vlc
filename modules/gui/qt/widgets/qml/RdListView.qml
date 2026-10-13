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

// Redesign list of the sidebars (queue, bookmarks, chapters): RdListRow rows (Figma "Frame 39",
// 32 high) 12 apart, 20 from the panel sides. Rows are created on demand and recycled
// (ListViewExt), so a 500+ item queue or an audiobook's chapters open and scroll at full frame
// rate (INTERACTIONS.md section 0). Up / Down move between the rows; a row calls focusRow() from
// its Navigation actions.
import QtQuick

import VLC.Style

ListViewExt {
    id: root

    leftMargin: VLCStyle.dp(20)
    rightMargin: VLCStyle.dp(20)
    spacing: VLCStyle.dp(12)

    // about ten rows ready above and below the visible ones
    cacheBuffer: 10 * (VLCStyle.rd_rowHeight + spacing)

    // rows scrolled out of the list do not draw over the header above it
    clip: true

    // the sidebar body has no fading edges (Figma)
    fadingEdge.enableBeginningFade: false
    fadingEdge.enableEndFade: false

    // reordering: a 2 px accent line in the middle of the gap the dragged rows go to (a row
    // providing the drop areas exposes topContainsDrag / bottomContainsDrag, see ListViewExt)
    dropIndicator: Rectangle {
        parent: {
            const item = root.itemContainsDrag
            if (!item || item.topContainsDrag === undefined || item.bottomContainsDrag === undefined)
                return null
            return item
        }

        z: 99

        x: 0
        y: {
            if (!parent)
                return 0
            // the footer (drop at the end) starts right after the last row
            if (parent === root.footerItem)
                return (root.spacing - height) / 2
            if (parent.topContainsDrag)
                // above the first row there is no gap: the line stays inside the list
                return (parent.index === 0) ? 0 : -(root.spacing + height) / 2
            return parent.height + (root.spacing - height) / 2
        }
        width: parent ? parent.width : 0
        height: VLCStyle.dp(2)

        visible: !!parent
        color: VLCStyle.palette.rdAccentMain
    }

    function focusRow(index) {
        if (index < 0 || index >= count)
            return
        currentIndex = index
        positionViewAtIndex(index, ItemView.Contain)
        const item = itemAtIndex(index)
        if (item)
            item.forceActiveFocus(Qt.TabFocusReason)
    }
}
