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

// redesign: a library menu (Figma "Sorting Options", "View Options", "folder context menu",
// "file context menu", "playlist context menu": 265 wide, 48 px rows, two-tone icons, orange
// check on the chosen option; F-11, F-12, IB-03, IB-04, IB-31).
// entries: [{ text, icon, selected, enabled, submenu, action: function(row) }]
import QtQuick

import VLC.MainInterface
import VLC.Player
import VLC.Style
import VLC.Widgets as Widgets

Widgets.RdMenuPanel {
    id: menu

    // while open, keys go to the menu instead of VLC's hotkeys over the player
    // (RdPanels.modalCount, see menus/qml/RdCascadeMenu.qml)
    property bool _holdsModal: false

    onAboutToShow: {
        if (!menu._holdsModal) {
            RdPanels.acquireModal()
            menu._holdsModal = true
        }
    }

    onAboutToHide: {
        if (menu._holdsModal) {
            RdPanels.releaseModal()
            menu._holdsModal = false
        }
    }

    Component.onDestruction: {
        if (menu._holdsModal)
            RdPanels.releaseModal()
    }

    property var entries: []

    // below `item`, its left edge 11 px left of the item (sort and view menus), or its right
    // edge on the item's right edge (the "..." menus)
    function openBelow(item, alignRight) {
        openOffset(item, alignRight ? item.width - width : -VLCStyle.dp(11), item.height + VLCStyle.dp(6))
    }

    // at the Figma overlay offset (dx, dy) from the button; above it when the window has no
    // room below
    function openOffset(item, dx, dy) {
        parent = item
        keyboard = !!item.visualFocus
        x = dx
        const window = item.Window.window
        const below = item.mapToItem(null, 0, dy).y
        y = (window && below + implicitHeight > window.height - margins)
            ? -implicitHeight - (dy - item.height)
            : dy
        open()
    }

    // at a point of `item` (right click)
    function openAt(item, px, py) {
        parent = item
        x = px
        y = py
        open()
    }

    Repeater {
        model: menu.entries

        delegate: Widgets.RdOptionRow {
            required property var modelData

            text: modelData.text
            rdIcon: modelData.icon ?? ""
            selected: !!modelData.selected
            hasSubmenu: !!modelData.submenu
            showChevron: modelData.chevron ?? true
            enabled: modelData.enabled ?? true

            onClicked: {
                if (modelData.action)
                    modelData.action(this)
            }
        }
    }
}
