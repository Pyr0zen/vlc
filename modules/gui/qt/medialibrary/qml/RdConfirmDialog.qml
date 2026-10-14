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

// redesign: asks before a library action that cannot be undone (Delete Playlist, Remove from
// Library). The video shows neither action, so the question uses the library dialog frame
// (RdLibraryDialog: Figma "new playlist" header, body and footer) with the action's name on the
// right button. Opened through RdLibraryNav.confirmRequested().
import QtQuick

import VLC.MainInterface
import VLC.Style

RdLibraryDialog {
    id: dialog

    property string message: ""
    property var _action: null

    // params: { title, message, button, action }
    function ask(params) {
        title = params.title ?? ""
        message = params.message ?? ""
        saveText = params.button ?? qsTr("OK")
        _action = params.action ?? null
        open()
        focusSaveButton()
    }

    preferredWidth: VLCStyle.dp(520)

    onSaved: {
        if (_action)
            _action()
        _action = null
    }

    onClosed: _action = null

    Text {
        width: dialog.bodyWidth
        wrapMode: Text.WordWrap
        text: dialog.message
        font.family: VLCStyle.rd_fontFamily
        font.pixelSize: VLCStyle.rd_fontSize_label
        color: VLCStyle.palette.rdFgA2
    }
}
