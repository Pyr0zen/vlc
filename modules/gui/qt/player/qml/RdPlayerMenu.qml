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

// redesign: the player's right-click menu (Figma "right-click menu": 292 wide, no shadow; video
// 5:14-5:30) and Hide UI (Ctrl + \, Decision 22). While the player is shown, VLC's right click on
// the video and the Menu key come here through DialogsProvider instead of the native menu.
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Dialogs
import VLC.Menus as Menus

Item {
    id: root

    readonly property bool shown: menu.visible

    // opens the menu at the mouse cursor
    function popupAtCursor() {
        const p = MainCtx.cursorPosition(root)
        menu.popupAt(root, p.x, p.y, false)
    }

    function close() {
        menu.close()
    }

    // only for the embedded video: a video in its own window keeps VLC's native menu
    Binding {
        target: DialogsProvider
        property: "rdPopupMenu"
        value: root.visible && MainCtx.hasEmbededVideo
    }

    Component.onDestruction: DialogsProvider.rdPopupMenu = false

    Connections {
        target: DialogsProvider

        function onRdPopupMenuRequested(show) {
            if (show)
                root.popupAtCursor()
            else
                menu.close()
        }
    }

    // Hide UI: no bars, no panels, only the video (video 5:25-5:30)
    Menus.ShortcutExt {
        sequence: "Ctrl+\\"
        context: Qt.WindowShortcut
        onActivated: RdPanels.toggleUi()
    }

    Menus.RdCascadeMenu {
        id: menu

        rootWidth: VLCStyle.rd_contextMenuWidth
        withShadow: false

        // like a native context menu: a right click elsewhere reopens the menu there
        onRightPressedOutside: Qt.callLater(root.popupAtCursor)

        model: Menus.RdMenuModel {
            kind: "player"
            ctx: MainCtx
            uiHidden: RdPanels.uiHidden

            onRequested: (id) => {
                if (id === "hideUi") {
                    RdPanels.toggleUi()
                } else if (id === "showQueue") {
                    RdPanels.uiHidden = false
                    RdPanels.open("queue")
                }
            }
        }
    }
}
