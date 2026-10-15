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

// redesign (W4.7, P4-04 to P4-07, IA-34 / IA-35; video 7:52-8:03, Figma "Setting Preset"
// 2372:8834): the per-show preset selector in the settings sidebar's footer, above "Open
// Advanced Settings". One preset holds the settings of every tab (Decision 18); the logic is
// RdPresets (player/rd_presets.cpp).
// - closed: 360x42, BG/B2, radius 6, padding 2; the 38 px row inside shows the preset's name
//   (Inter 14 FG/A2, padding 2,14) and a chevron up (the list opens upward);
// - open: the list grows upward from the selector's bottom edge, as wide as it: BG/A4, radius 6,
//   padding 2, gap 2, drop shadow 35 % blur 14; rows 38 px, radius 4. "+ New Custom Preset" first
//   (FG/A3, Decision 11: the video's wording), then the user's presets with the "..." button that
//   opens their menu (Rename, Duplicate, Use for This Folder, Delete: Decision 25), then
//   "Default Preset" (no menu, Figma). The selected row is BG/A2 with the accent check.
// Selecting a preset applies all its values at once; "New Custom Preset" copies the current
// settings and starts renaming it. Opens and closes instantly, like the Figma prototype.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets

T.Control {
    id: root

    property int maxVisibleRows: 9

    readonly property SystemPalette rdPalette: VLCStyle.palette
    readonly property real _rowHeight: VLCStyle.dp(38)
    readonly property real _rowGap: VLCStyle.dp(2)

    // the preset being renamed in the list, empty when none
    property string _renamingId: ""

    // [{ kind: "new" }, { kind: "preset", id, name, builtin, linked }]
    readonly property var _rows: [{ kind: "new" }].concat(RdPresets.presets.map((p) => Object.assign({ kind: "preset" }, p)))

    function openList() {
        if (!list.opened)
            list.open()
    }

    function _createPreset() {
        const id = RdPresets.create()
        if (id !== "")
            _startRename(id)
    }

    function _startRename(id) {
        _renamingId = id
        const row = _rows.findIndex((r) => r.id === id)
        if (row >= 0) {
            listView.currentIndex = row
            listView.positionViewAtIndex(row, ListView.Contain)
        }
    }

    function _activate(index) {
        const row = _rows[index]
        if (!row)
            return
        if (row.kind === "new") {
            _createPreset()
            return
        }
        RdPresets.select(row.id)
        list.close()
    }

    implicitWidth: VLCStyle.dp(360)
    implicitHeight: VLCStyle.dp(42)

    padding: VLCStyle.dp(2)
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true

    Accessible.role: Accessible.ComboBox
    Accessible.name: qsTr("Preset")
    Accessible.description: RdPresets.currentName
    Accessible.onPressAction: root.openList()

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space
                || event.key === Qt.Key_Up) {
            event.accepted = true
            root.openList()
        }
    }

    background: Rectangle {
        radius: VLCStyle.rd_radius_normal
        color: root.rdPalette.rdBgB2
        border.width: root.visualFocus ? VLCStyle.dp(1) : 0
        border.color: root.rdPalette.rdFgA3
    }

    // Figma "option" 360x38 inside the 2 px frame
    contentItem: Rectangle {
        radius: VLCStyle.rd_radius_small
        color: (root.hovered && !list.opened) ? root.rdPalette.rdBgA2 : "transparent"

        Text {
            anchors.left: parent.left
            anchors.leftMargin: VLCStyle.dp(14)
            anchors.right: chevron.left
            anchors.rightMargin: VLCStyle.dp(10)
            anchors.verticalCenter: parent.verticalCenter

            text: RdPresets.currentName
            elide: Text.ElideRight
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: root.rdPalette.rdFgA2
        }

        Widgets.RdIcon {
            id: chevron

            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.dp(14)
            anchors.verticalCenter: parent.verticalCenter
            name: "chevron_direction-up"
            color: root.rdPalette.rdFgA2
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.forceActiveFocus(Qt.MouseFocusReason)
                list.opened ? list.close() : list.open()
            }
        }
    }

    // ------------------------------------------------------------------------------- list
    T.Popup {
        id: list

        readonly property int visibleRows: Math.max(1, Math.min(root._rows.length, root.maxVisibleRows))

        // Figma "state=open": the list's bottom edge is the selector's
        x: 0
        y: root.height - height
        width: root.width
        height: visibleRows * root._rowHeight + (visibleRows - 1) * root._rowGap + 2 * padding
        padding: VLCStyle.dp(2)

        // a click outside only closes the list (not the sidebar under it); while a name is
        // being edited, Escape puts the old name back instead
        modal: true
        dim: false
        closePolicy: root._renamingId !== "" ? T.Popup.CloseOnPressOutside
                                             : (T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside)

        onAboutToShow: {
            root._renamingId = ""
            const current = root._rows.findIndex((r) => r.id === RdPresets.currentId)
            listView.currentIndex = Math.max(0, current)
            listView.positionViewAtIndex(listView.currentIndex, ListView.Contain)
            listView.forceActiveFocus(Qt.PopupFocusReason)
        }

        onClosed: {
            presetMenu.close()
            root._renamingId = ""
            if (root.visible)
                root.forceActiveFocus(Qt.PopupFocusReason)
        }

        T.Overlay.modal: Item { }

        background: Rectangle {
            radius: VLCStyle.rd_radius_normal
            color: root.rdPalette.rdBgA4

            // Figma "Options": drop shadow #000000 35 %, no offset, blur 14
            Widgets.RdShadow {
                color: root.rdPalette.rdListShadow
                yOffset: 0
                blurRadius: VLCStyle.dp(14)
            }
        }

        contentItem: ListView {
            id: listView

            clip: true
            spacing: root._rowGap
            boundsBehavior: Flickable.StopAtBounds
            model: root._rows
            keyNavigationEnabled: true
            highlightFollowsCurrentItem: false

            T.ScrollBar.vertical: Widgets.ScrollBarExt { }

            Keys.onPressed: (event) => {
                if (root._renamingId !== "")
                    return
                const row = root._rows[currentIndex]
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    event.accepted = true
                    root._activate(currentIndex)
                } else if (event.key === Qt.Key_F2 && row && row.kind === "preset" && !row.builtin) {
                    event.accepted = true
                    root._startRename(row.id)
                } else if (event.key === Qt.Key_Menu && row && row.kind === "preset" && !row.builtin
                           && currentItem) {
                    event.accepted = true
                    currentItem.openMenu(true)
                }
            }

            delegate: T.ItemDelegate {
                id: option

                required property int index
                required property var modelData

                readonly property bool isNew: modelData.kind === "new"
                readonly property bool selected: !isNew && modelData.id === RdPresets.currentId
                readonly property bool renaming: !isNew && modelData.id === root._renamingId
                readonly property bool hasMenu: !isNew && !modelData.builtin

                function openMenu(keyboard) {
                    presetMenu.openFor(option.modelData, moreButton, keyboard)
                }

                width: ListView.view.width
                height: root._rowHeight
                hoverEnabled: true
                focusPolicy: Qt.NoFocus

                leftPadding: VLCStyle.dp(14)
                rightPadding: VLCStyle.dp(14)
                topPadding: VLCStyle.dp(2)
                bottomPadding: VLCStyle.dp(2)

                Accessible.role: Accessible.ListItem
                Accessible.name: isNew ? qsTr("New Custom Preset") : modelData.name
                Accessible.selected: selected

                onClicked: {
                    if (!renaming)
                        root._activate(index)
                }

                // the row's menu also opens on a right click
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    enabled: option.hasMenu
                    onTapped: option.openMenu(false)
                }

                background: Rectangle {
                    radius: VLCStyle.rd_radius_small
                    color: (option.selected || option.hovered || option.renaming
                            || (option.index === listView.currentIndex && listView.activeFocus))
                           ? root.rdPalette.rdBgA2 : "transparent"
                }

                contentItem: Item {
                    // Figma: "+" on the new preset row, "..." on the user's presets; "Default
                    // Preset" has none and starts at the row's padding
                    T.Button {
                        id: moreButton

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: VLCStyle.rd_iconSize
                        height: VLCStyle.rd_iconSize
                        visible: option.isNew || option.hasMenu
                        enabled: option.hasMenu
                        focusPolicy: Qt.NoFocus

                        Accessible.name: option.isNew ? "" : qsTr("Preset options for %1").arg(option.modelData.name)

                        onClicked: option.openMenu(false)

                        background: Rectangle {
                            radius: VLCStyle.rd_radius_small
                            color: (moreButton.hovered && option.hasMenu) ? root.rdPalette.rdHoverOverlay : "transparent"
                        }

                        contentItem: Widgets.RdIcon {
                            name: option.isNew ? "add" : "more"
                            color: (moreButton.hovered && option.hasMenu) ? root.rdPalette.rdFg2
                                                                          : (option.isNew ? root.rdPalette.rdFgA3 : root.rdPalette.rdFgA2)
                        }
                    }

                    Text {
                        anchors.left: moreButton.visible ? moreButton.right : parent.left
                        anchors.leftMargin: moreButton.visible ? VLCStyle.dp(10) : 0
                        anchors.right: check.left
                        anchors.rightMargin: VLCStyle.dp(10)
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !option.renaming

                        text: option.isNew ? qsTr("New Custom Preset") : option.modelData.name
                        elide: Text.ElideRight
                        font.family: VLCStyle.rd_fontFamily
                        font.pixelSize: VLCStyle.rd_fontSize_label
                        color: option.isNew ? root.rdPalette.rdFgA3 : root.rdPalette.rdFgA2
                    }

                    // Rename: the name becomes editable in place; Enter or leaving the row keeps
                    // it, Escape puts the old one back
                    Loader {
                        anchors.left: moreButton.right
                        anchors.leftMargin: VLCStyle.dp(10)
                        anchors.right: check.left
                        anchors.rightMargin: VLCStyle.dp(10)
                        anchors.verticalCenter: parent.verticalCenter
                        active: option.renaming

                        sourceComponent: TextInput {
                            id: nameInput

                            property bool done: false

                            function finish(keep) {
                                if (done)
                                    return
                                done = true
                                if (keep)
                                    RdPresets.rename(option.modelData.id, text)
                                root._renamingId = ""
                                listView.forceActiveFocus(Qt.OtherFocusReason)
                            }

                            text: option.modelData.name
                            clip: true
                            selectByMouse: true
                            maximumLength: 80
                            font.family: VLCStyle.rd_fontFamily
                            font.pixelSize: VLCStyle.rd_fontSize_label
                            color: root.rdPalette.rdFg2
                            selectionColor: root.rdPalette.rdAccentDim
                            selectedTextColor: root.rdPalette.rdSelectionText

                            Accessible.role: Accessible.EditableText
                            Accessible.name: qsTr("Preset name")

                            Component.onCompleted: {
                                selectAll()
                                forceActiveFocus(Qt.OtherFocusReason)
                            }

                            Keys.onReturnPressed: finish(true)
                            Keys.onEnterPressed: finish(true)
                            Keys.onEscapePressed: finish(false)
                            onActiveFocusChanged: {
                                if (!activeFocus)
                                    finish(true)
                            }
                        }
                    }

                    Widgets.RdIcon {
                        id: check

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: option.selected
                        name: "check_state-active"
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------------- preset menu
    // Decision 25: Rename, Duplicate, Delete; a preset can also be tied to the folder playing
    // (Decision (Claude): the video does not show the menu)
    Widgets.RdMenuPanel {
        id: presetMenu

        property var preset: null
        // Delete asks for a second click
        property bool confirmDelete: false

        function openFor(preset, anchor, keyboard) {
            presetMenu.preset = preset
            presetMenu.confirmDelete = false
            presetMenu.keyboard = keyboard
            const origin = anchor.mapToItem(root, 0, anchor.height)
            presetMenu.x = origin.x
            presetMenu.y = origin.y
            presetMenu.open()
        }

        closeOnClick: false

        onClosed: {
            confirmDelete = false
            if (list.opened)
                listView.forceActiveFocus(Qt.PopupFocusReason)
        }

        Widgets.RdOptionRow {
            width: parent.width
            rdIcon: "edit"
            text: qsTr("Rename")
            onClicked: {
                const id = presetMenu.preset.id
                presetMenu.close()
                root._startRename(id)
            }
        }

        Widgets.RdOptionRow {
            width: parent.width
            rdIcon: "file_two-tone-yes"
            text: qsTr("Duplicate")
            onClicked: {
                const id = RdPresets.duplicate(presetMenu.preset.id)
                presetMenu.close()
                if (id !== "")
                    root._startRename(id)
            }
        }

        Widgets.RdOptionRow {
            width: parent.width
            visible: RdPresets.folderAvailable
            rdIcon: "folder_two-tone-yes"
            text: qsTr("Use for This Folder")
            selected: !!presetMenu.preset && !!presetMenu.preset.linked
            Accessible.description: RdPresets.folderName
            onClicked: {
                RdPresets.setLinked(presetMenu.preset.id, !presetMenu.preset.linked)
                presetMenu.close()
            }
        }

        Widgets.RdMenuDivider {
            width: parent.width
        }

        Widgets.RdOptionRow {
            width: parent.width
            rdIcon: "close"
            text: presetMenu.confirmDelete ? qsTr("Click Again to Delete") : qsTr("Delete")
            onClicked: {
                if (!presetMenu.confirmDelete) {
                    presetMenu.confirmDelete = true
                    return
                }
                RdPresets.remove(presetMenu.preset.id)
                presetMenu.close()
            }
        }
    }
}
