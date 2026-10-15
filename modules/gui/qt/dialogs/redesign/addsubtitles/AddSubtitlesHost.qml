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

// redesign (W6.5): hosts the Add Subtitles dialog over every view (MainInterface.qml), so a view
// switch (the video ends) does not close it. Created on its first open; AddSubtitles.open(...)
// opens it from anywhere (tracks popup "+" and pencil, library menus).
import QtQuick

import VLC.Dialogs

Loader {
    id: root

    active: false
    sourceComponent: Component {
        Item {
            readonly property alias dialog: dialog

            AddSubtitlesDialog {
                id: dialog
            }
        }
    }

    Connections {
        target: AddSubtitles

        function onOpenRequested() {
            root.active = true
            if (root.item)
                root.item.dialog.openDialog()
        }
    }
}
