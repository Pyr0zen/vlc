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

// redesign: Open Network Stream of the library (video 13:09-13:20, P6-14; Figma "Open network
// stream"): "Network URL" (several links, one per line) and an optional "Playlist Name". With a
// name the links are saved as a stream list under Network and the library opens it ("Network >
// Index", 13:19); without one they play. A pasted playlist link fills the name with its file
// name ("index.m3u" gives "Index", 13:16).
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Playlist
import VLC.MediaLibrary

RdLibraryDialog {
    id: dialog

    preferredWidth: VLCStyle.dp(1048)
    title: qsTr("Open Network Stream")
    canSave: _urls().length > 0

    property bool _nameEdited: false

    function _urls() {
        return urlField.text.split(/\s+/).map((u) => u.trim()).filter((u) => u !== "")
    }

    // "https://iptv-org.github.io/iptv/index.m3u" -> "Index"
    function _nameFromUrl(url) {
        const path = url.split(/[?#]/)[0]
        let file = path.substring(path.lastIndexOf("/") + 1)
        try {
            file = decodeURIComponent(file)
        } catch (e) {
            // a stray "%" while typing: keep the text as it is
        }
        const dot = file.lastIndexOf(".")
        const base = dot > 0 ? file.substring(0, dot) : file
        return base.length > 0 ? base.charAt(0).toUpperCase() + base.substring(1) : ""
    }

    function _isPlaylistUrl(url) {
        return /\.(m3u8?|pls|xspf|asx)(\?|#|$)/i.test(url)
    }

    onOpened: {
        urlField.text = ""
        nameField.text = ""
        _nameEdited = false
        urlField.forceActiveFocus()
    }

    onSaved: {
        const urls = _urls()
        const name = nameField.text.trim()
        if (name === "") {
            MainPlaylistController.append(urls, true)
            return
        }
        for (let i = 0; i < urls.length; ++i)
            RdLibraryStore.addStreamList(urls.length > 1 ? name + " " + (i + 1) : name, urls[i])
        RdLibraryNav.openPath([
            { page: "network", title: qsTr("Network") },
            { page: "streams", url: urls[0], title: urls.length > 1 ? name + " 1" : name }
        ])
    }

    RdLibraryDialog.Section {
        width: dialog.bodyWidth
        title: qsTr("Network URL")
        hint: qsTr("You can enter multiple links to load.")
    }

    // Figma "Frame 86": 1008x194, BG/B2, 2 px BG/A4 border, radius 6, padding 8,18
    Rectangle {
        width: dialog.bodyWidth
        height: VLCStyle.dp(194)
        radius: VLCStyle.rd_radius_normal
        color: VLCStyle.palette.rdBgB2
        border.width: VLCStyle.dp(2)
        border.color: urlField.activeFocus ? VLCStyle.palette.rdAccentMain : VLCStyle.palette.rdBgA4

        Flickable {
            id: urlFlick

            anchors.fill: parent
            anchors.topMargin: VLCStyle.dp(8)
            anchors.bottomMargin: VLCStyle.dp(8)
            anchors.leftMargin: VLCStyle.dp(14)
            anchors.rightMargin: VLCStyle.dp(18)
            contentHeight: urlField.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            TextEdit {
                id: urlField

                width: urlFlick.width
                wrapMode: TextEdit.WrapAnywhere
                selectByMouse: true
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: VLCStyle.palette.rdFg2
                selectionColor: VLCStyle.palette.rdAccentDim

                Accessible.role: Accessible.EditableText
                Accessible.name: qsTr("Network URL")

                onTextChanged: {
                    if (dialog._nameEdited)
                        return
                    const urls = dialog._urls()
                    nameField.text = urls.length === 1 && dialog._isPlaylistUrl(urls[0]) ? dialog._nameFromUrl(urls[0]) : ""
                }

                Text {
                    visible: urlField.text === ""
                    text: qsTr("e.g., https://www.example.com/stream.avi")
                    font: urlField.font
                    color: VLCStyle.palette.rdFgA4
                }
            }
        }
    }

    RdLibraryDialog.Section {
        width: dialog.bodyWidth
        title: qsTr("Playlist Name")
        note: qsTr("(optional)")
        hint: qsTr("The playlist will be saved and displayed with this title.")
    }

    Widgets.RdTextField {
        id: nameField

        width: dialog.bodyWidth
        placeholderText: qsTr("e.g., Favorite TV Channels")
        onTextEdited: dialog._nameEdited = text !== ""
        onAccepted: {
            if (dialog.canSave) {
                dialog.saved()
                dialog.close()
            }
        }
    }
}
