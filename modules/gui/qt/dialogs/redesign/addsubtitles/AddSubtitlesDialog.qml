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

// redesign (W6.5, video 6:02-6:24, Figma "Add Subtitles to Playlist/Folder" 1911:7545 /
// 3336:11929 / 1919:8707 / 1919:9278): the Add Subtitles dialog, 1048x800, radius 14, BG/B1,
// "bg blur + shadow" (opaque here: it opens over the native video, Figma's 95 % assumes a blur).
// - header (Figma "Frame 120", 96 px, BG/B2, padding 9, gap 12): "Add Subtitles" (Inter 14
//   FG/A2) and the close button, then the target and source dropdowns (200x34, 10 px apart) and
//   the source's field (the folder, the search with its language, or the link);
// - body (632 px): "To This File" lists the subtitle files to check (Figma "Folder-2" /
//   "Folder-3"); "To This Folder" / "To This Playlist" lists the videos with the subtitle matched
//   to each (Figma "Folder" / "Folder-1"); an empty list says why;
// - footer (72 px, padding 20): Cancel, Save.
// Logic: the AddSubtitles singleton (dialogs/redesign/addsubtitles/add_subtitles.cpp).
// Opens and closes instantly like every redesign dialog (Decision 32); Decision 12: it opens on
// "To This File / From Computer". Files, folders and links dropped on it are added.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Dialogs
import VLC.Player

T.Popup {
    id: root

    readonly property SystemPalette rdPalette: VLCStyle.palette

    readonly property bool _fileTarget: AddSubtitles.target === 0
    readonly property int _source: AddSubtitles.source
    readonly property bool _online: _source === 1
    readonly property bool _link: _source === 2
    readonly property Item _list: _fileTarget ? fileList : matchList
    readonly property bool _listEmpty: _fileTarget ? AddSubtitles.files.count === 0
                                                   : AddSubtitles.matches.count === 0

    readonly property real _availableWidth: T.Overlay.overlay ? T.Overlay.overlay.width : VLCStyle.rd_dialogWidth
    readonly property real _availableHeight: T.Overlay.overlay ? T.Overlay.overlay.height : VLCStyle.rd_dialogHeight

    // item to give the keyboard focus back to when the dialog closes
    property Item _restoreFocusItem: null
    property bool _saved: false
    // while open, keys go to the dialog instead of VLC's hotkeys (RdPanels.modalCount)
    property bool _holdsModal: false

    function openDialog() {
        const window = MainCtx.intfMainWindow
        if (window) {
            window.raise()
            window.requestActivate()
        }
        if (visible)
            return

        let focusItem = (window && window.activeFocusItem) ? window.activeFocusItem : null
        // an item inside another popup (the menu that opened the dialog) closes with it
        for (let item = focusItem; item; item = item.parent) {
            if (item === root.parent) {
                focusItem = null
                break
            }
        }
        _restoreFocusItem = focusItem
        _saved = false
        open()
    }

    parent: T.Overlay.overlay
    anchors.centerIn: parent

    width: Math.min(VLCStyle.rd_dialogWidth, _availableWidth - 2 * (VLCStyle.margin_large + MainCtx.windowExtendedMargin))
    height: Math.min(VLCStyle.rd_dialogHeight, _availableHeight - 2 * (VLCStyle.margin_large + MainCtx.windowExtendedMargin))

    padding: 0
    modal: true
    focus: true
    // downloads finish before the dialog may close by a stray click
    closePolicy: AddSubtitles.saving ? T.Popup.CloseOnEscape
                                     : (T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside)

    Connections {
        target: AddSubtitles

        function onSaved() {
            root._saved = true
            root.close()
        }
    }

    onAboutToShow: {
        if (!_holdsModal) {
            RdPanels.acquireModal()
            _holdsModal = true
        }
        targetDropdown.forceActiveFocus(Qt.PopupFocusReason)
    }

    onAboutToHide: {
        if (_holdsModal) {
            RdPanels.releaseModal()
            _holdsModal = false
        }
        choicePopup.close()
        // closed without saving: what is still running stops
        if (!_saved)
            AddSubtitles.cancel()
    }

    onClosed: {
        const window = MainCtx.intfMainWindow
        if (_restoreFocusItem && _restoreFocusItem.visible
                && (!window || window.activeFocusItem !== _restoreFocusItem))
            _restoreFocusItem.forceActiveFocus(Qt.PopupFocusReason)
        _restoreFocusItem = null
    }

    Component.onDestruction: {
        if (_holdsModal)
            RdPanels.releaseModal()
    }

    // no dim behind the dialog (Decision 41); the transparent overlay takes the clicks outside
    T.Overlay.modal: Item {
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            cursorShape: Qt.ArrowCursor
        }
    }

    background: Rectangle {
        radius: VLCStyle.rd_radius_large
        color: Qt.alpha(root.rdPalette.rdBgB1Transparent, 1.0)

        Widgets.RdShadow { }
    }

    contentItem: Item {
        id: content

        Accessible.role: Accessible.Dialog
        Accessible.name: qsTr("Add Subtitles")

        // keys nobody in the dialog handled never reach the player behind it
        Keys.onPressed: (event) => {
            event.accepted = (event.key !== Qt.Key_Escape && event.key !== Qt.Key_Back)
        }

        // files, folders and links dropped anywhere on the dialog
        DropArea {
            anchors.fill: parent
            keys: ["text/uri-list"]
            onDropped: (drop) => {
                if (drop.hasUrls) {
                    AddSubtitles.addDropped(drop.urls)
                    drop.accept(Qt.CopyAction)
                }
            }
        }

        // ---------------------------------------------------------------------- header
        Rectangle {
            id: header

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: VLCStyle.rd_dialogHeaderHeight

            radius: VLCStyle.rd_radius_large
            color: root.rdPalette.rdBgB2

            // square bottom corners
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.radius
                color: parent.color
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: VLCStyle.dp(19)
                anchors.right: closeButton.left
                anchors.rightMargin: VLCStyle.dp(10)
                anchors.verticalCenter: closeButton.verticalCenter

                text: qsTr("Add Subtitles")
                elide: Text.ElideRight
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: root.rdPalette.rdFgA2

                Accessible.role: Accessible.TitleBar
                Accessible.name: text
            }

            // Figma "Icon Wrapper" 32x32, radius 4, hover #FFFFFF 6%
            T.Button {
                id: closeButton

                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.dp(9)
                anchors.top: parent.top
                anchors.topMargin: VLCStyle.dp(9)
                implicitWidth: VLCStyle.dp(32)
                implicitHeight: VLCStyle.dp(32)

                focusPolicy: Qt.StrongFocus
                Accessible.name: qsTr("Close")

                KeyNavigation.tab: targetDropdown
                KeyNavigation.backtab: saveButton.enabled ? saveButton : cancelButton

                onClicked: root.close()

                background: Rectangle {
                    radius: VLCStyle.rd_radius_small
                    color: closeButton.hovered ? root.rdPalette.rdHoverOverlay : "transparent"
                    border.width: closeButton.visualFocus ? VLCStyle.dp(1) : 0
                    border.color: root.rdPalette.rdFgA3
                }

                contentItem: Item {
                    Widgets.RdIcon {
                        anchors.centerIn: parent
                        name: "close"
                        color: closeButton.hovered ? root.rdPalette.rdFg2 : root.rdPalette.rdFgA2
                    }
                }
            }

            // Figma "Frame 206": the controls row, gap 10
            Item {
                id: controls

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: VLCStyle.dp(9)
                anchors.rightMargin: VLCStyle.dp(9)
                anchors.bottomMargin: VLCStyle.dp(9)
                height: VLCStyle.dp(34)

                // narrow windows: the dropdowns give room to the field
                readonly property real dropdownWidth: Math.min(VLCStyle.dp(200), (width - 3 * VLCStyle.dp(10)) / 4)

                AddSubtitlesDropdown {
                    id: targetDropdown

                    width: controls.dropdownWidth
                    height: parent.height

                    text: qsTr("Add subtitles to")
                    model: [
                        { text: qsTr("To This File"), enabled: AddSubtitles.fileAvailable },
                        { text: qsTr("To This Folder"), enabled: AddSubtitles.folderAvailable },
                        { text: qsTr("To This Playlist"), enabled: AddSubtitles.playlistAvailable }
                    ]
                    currentIndex: AddSubtitles.target

                    KeyNavigation.tab: sourceDropdown
                    KeyNavigation.backtab: closeButton

                    onActivated: (index) => AddSubtitles.target = index
                }

                AddSubtitlesDropdown {
                    id: sourceDropdown

                    x: targetDropdown.width + VLCStyle.dp(10)
                    width: controls.dropdownWidth
                    height: parent.height

                    text: qsTr("Subtitles from")
                    // Decision 17: "From Link ..." without the space before the ellipsis
                    model: [
                        { text: qsTr("From Computer"), enabled: true },
                        { text: qsTr("From OpenSubtitles"), enabled: true },
                        { text: qsTr("From Link..."), enabled: true }
                    ]
                    currentIndex: AddSubtitles.source

                    KeyNavigation.tab: field
                    KeyNavigation.backtab: targetDropdown

                    onActivated: (index) => AddSubtitles.source = index
                }

                AddSubtitlesField {
                    id: field

                    property string linkText: ""

                    anchors.left: sourceDropdown.right
                    anchors.leftMargin: VLCStyle.dp(10)
                    anchors.right: root._online ? languageDropdown.left : parent.right
                    anchors.rightMargin: root._online ? VLCStyle.dp(10) : 0
                    height: parent.height

                    editable: root._source !== 0
                    enabled: !root._online || AddSubtitles.openSubtitlesEnabled
                    opacity: enabled ? 1 : VLCStyle.rd_disabledRowOpacity

                    iconName: root._online ? "search" : root._link ? "link" : "folder"
                    text: root._online ? AddSubtitles.searchText : root._link ? linkText : AddSubtitles.folderPath
                    placeholderText: root._online ? qsTr("Search OpenSubtitles")
                                   : root._link ? qsTr("Paste a link to a subtitle file")
                                   : qsTr("Choose a folder")
                    accessibleName: root._online ? qsTr("Search OpenSubtitles")
                                  : root._link ? qsTr("Link to a subtitle file")
                                  : qsTr("Folder of the subtitles: %1").arg(AddSubtitles.folderPath)

                    KeyNavigation.tab: root._online ? languageDropdown : root._list
                    KeyNavigation.backtab: sourceDropdown
                    input.KeyNavigation.tab: root._online ? languageDropdown : root._list
                    input.KeyNavigation.backtab: sourceDropdown

                    onClicked: AddSubtitles.chooseFolder()
                    onTextEdited: (text) => {
                        if (root._online)
                            AddSubtitles.searchText = text
                        else if (root._link)
                            linkText = text
                    }
                    onAccepted: (text) => {
                        if (root._online) {
                            AddSubtitles.search()
                        } else if (root._link && text.trim() !== "") {
                            AddSubtitles.addLink(text)
                            linkText = ""
                            input.clear()
                        }
                    }
                }

                // Figma "Frame 124" (Folder-3): the OpenSubtitles language, 200x34
                AddSubtitlesDropdown {
                    id: languageDropdown

                    readonly property var codes: AddSubtitles.languages.map((l) => l.code)

                    anchors.right: parent.right
                    width: controls.dropdownWidth
                    height: parent.height
                    visible: root._online
                    enabled: AddSubtitles.openSubtitlesEnabled
                    opacity: enabled ? 1 : VLCStyle.rd_disabledRowOpacity

                    text: qsTr("Language")
                    model: AddSubtitles.languages.map((l) => ({ text: l.name, enabled: true }))
                    currentIndex: codes.indexOf(AddSubtitles.language)

                    KeyNavigation.tab: root._list
                    KeyNavigation.backtab: field.input

                    onActivated: (index) => AddSubtitles.language = codes[index]
                }
            }
        }

        // ------------------------------------------------------------------------ body
        Item {
            id: body

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.bottom: footer.top

            // "To This File" (Figma "Frame 124": padding 22,20,22,20, rows 36 px, gap 4)
            ListView {
                id: fileList

                anchors.fill: parent
                anchors.leftMargin: VLCStyle.dp(20)
                anchors.rightMargin: VLCStyle.dp(20)
                topMargin: VLCStyle.dp(22)
                bottomMargin: VLCStyle.dp(22)

                visible: root._fileTarget
                clip: true
                spacing: VLCStyle.dp(4)
                boundsBehavior: Flickable.StopAtBounds
                model: root._fileTarget ? AddSubtitles.files : null
                activeFocusOnTab: true
                keyNavigationEnabled: true

                T.ScrollBar.vertical: Widgets.ScrollBarExt { }

                KeyNavigation.tab: cancelButton
                KeyNavigation.backtab: field

                Keys.onSpacePressed: AddSubtitles.toggle(currentIndex)
                Keys.onReturnPressed: AddSubtitles.toggle(currentIndex)
                Keys.onEnterPressed: AddSubtitles.toggle(currentIndex)

                delegate: AddSubtitlesFileRow {
                    required property int index
                    required property string name
                    required selected

                    width: ListView.view.width
                    text: name
                    focusPolicy: Qt.NoFocus
                    highlighted: ListView.isCurrentItem && ListView.view.activeFocus

                    onClicked: {
                        ListView.view.currentIndex = index
                        AddSubtitles.toggle(index)
                    }
                }
            }

            // "To This Folder" / "To This Playlist" (Figma "Folder": rows every 40 px from 22 px)
            ListView {
                id: matchList

                anchors.fill: parent
                topMargin: VLCStyle.dp(22)
                bottomMargin: VLCStyle.dp(18)

                visible: !root._fileTarget
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root._fileTarget ? null : AddSubtitles.matches
                activeFocusOnTab: true
                keyNavigationEnabled: true

                T.ScrollBar.vertical: Widgets.ScrollBarExt { }

                KeyNavigation.tab: cancelButton
                KeyNavigation.backtab: field

                Keys.onSpacePressed: currentItem && currentItem.openChoices()
                Keys.onReturnPressed: currentItem && currentItem.openChoices()
                Keys.onEnterPressed: currentItem && currentItem.openChoices()

                delegate: AddSubtitlesMatchRow {
                    id: matchRow

                    required property int index
                    required videoName
                    required property string name
                    required matched

                    function openChoices() {
                        chooseRequested(matchRow.matchItem)
                    }

                    width: ListView.view.width
                    subtitleName: name
                    focusPolicy: Qt.NoFocus
                    highlighted: ListView.isCurrentItem && ListView.view.activeFocus

                    onChooseRequested: (anchor) => {
                        ListView.view.currentIndex = index
                        choicePopup.openFor(anchor, index, AddSubtitles.choices(index))
                    }
                }
            }

            // why the list is empty (no files, no key, nothing found, searching ...)
            Column {
                anchors.centerIn: parent
                width: Math.min(parent.width - 2 * VLCStyle.dp(40), VLCStyle.dp(560))
                spacing: VLCStyle.dp(16)
                visible: root._listEmpty && AddSubtitles.message !== ""

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: AddSubtitles.message
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_label
                    lineHeight: VLCStyle.dp(24.5)
                    lineHeightMode: Text.FixedHeight
                    color: root.rdPalette.rdFgA3

                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }

                // the OpenSubtitles source needs the user's API key
                Widgets.RdButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root._online && !AddSubtitles.openSubtitlesEnabled
                    style: Widgets.RdButton.Style.Plain
                    text: qsTr("Open Settings")

                    onClicked: {
                        root.close()
                        DialogsProvider.settingsDialog("subtitles")
                    }
                }
            }
        }

        // ---------------------------------------------------------------------- footer
        Item {
            id: footer

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: VLCStyle.dp(20)
            anchors.rightMargin: VLCStyle.dp(20)
            height: VLCStyle.rd_dialogFooterHeight

            Widgets.RdButton {
                id: cancelButton

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Cancel")

                KeyNavigation.tab: saveButton.enabled ? saveButton : closeButton
                KeyNavigation.backtab: root._list

                onClicked: root.close()
            }

            // a problem while the list shows (a download failed)
            Text {
                anchors.left: cancelButton.right
                anchors.leftMargin: VLCStyle.dp(20)
                anchors.right: saveButton.left
                anchors.rightMargin: VLCStyle.dp(20)
                anchors.verticalCenter: parent.verticalCenter
                visible: !root._listEmpty && AddSubtitles.message !== ""
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                text: AddSubtitles.message
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: root.rdPalette.rdFgA3

                Accessible.role: Accessible.StaticText
                Accessible.name: text
            }

            Widgets.RdButton {
                id: saveButton

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                style: Widgets.RdButton.Style.Save
                text: qsTr("Save")
                enabled: AddSubtitles.canSave

                KeyNavigation.tab: closeButton
                KeyNavigation.backtab: cancelButton

                onClicked: AddSubtitles.save()
            }
        }

        AddSubtitlesChoicePopup {
            id: choicePopup

            onPicked: (row, candidate) => AddSubtitles.choose(row, candidate)
        }
    }
}
