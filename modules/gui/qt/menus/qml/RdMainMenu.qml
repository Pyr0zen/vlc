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

// redesign: the main "..." menu of the top bar (Decision 2: her last version, Figma "menu" 375 wide;
// video 5:05-5:16, 12:56-13:09, 15:28-15:33, 16:01-16:03, 19:29-19:36). The entries are built in
// C++ (RdMenuModel "main") with VLC's own actions; the two below are handled here.
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Dialogs
import VLC.Menus

RdCascadeMenu {
    id: root

    rootWidth: VLCStyle.rd_mainMenuWidth

    // opens under `button` (the top bar "..."): the Figma overlay sits 17 px left of the 24 px icon
    // and 38 px below its top, so the menu icons line up under the "..." icon
    function popupBelow(button, keyboard) {
        const iconX = (button.width - VLCStyle.rd_iconSize) / 2
        const iconY = (button.height - VLCStyle.rd_iconSize) / 2
        root.popupAt(button,
                     iconX - VLCStyle.dp(17, VLCStyle.scale),
                     iconY + VLCStyle.dp(38, VLCStyle.scale),
                     keyboard)
    }

    model: RdMenuModel {
        kind: "main"
        ctx: MainCtx

        onRequested: (id) => {
            if (id === "keyboardShortcuts") {
                DialogsProvider.keyboardShortcutsDialog()
            } else if (id === "customizePlayer") {
                // VLC's toolbar editor (Customize Player screen: W8.1)
                DialogsProvider.showToolbarEditorDialog()
            }
        }
    }
}
