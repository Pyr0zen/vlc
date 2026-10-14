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

// redesign (W8.1a, video 19:12-19:27, Figma "Player - customize"): the box of controls that are
// not in the edited bar. Figma grid: items 86 wide, 24 apart, 38 between rows; each item is its
// icon in a dashed outline (Icon Wrapper 30x32, the Spacer 24x32) with its name 16 below
// (Inter 14, FG/A2, centered, up to two lines). Dragging an item into the bar adds it and it
// leaves the box (the others shift in 50 ms, Figma smart animate); a control dragged from the bar
// into the box is removed from the bar and comes back here. The spacers can be used many times.
// Icons: the Figma icon the control uses, or the closest Figma icon; VLC's glyph for controls
// the design has no icon for.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.PlayerControls

GridView {
    id: root

    // the dialog content: drag state and drag layer
    property Item editor: null

    // PlayerControlbarModel of the selected profile and player
    property var playerModel: null

    readonly property bool removeHintVisible: removeDrop.containsDrag

    cellWidth: VLCStyle.rd_customizeItemWidth + VLCStyle.rd_customizeColumnGap
    cellHeight: _itemHeight + VLCStyle.rd_customizeRowGap

    // two label lines (Figma "Playback Speed" item: 32 + 16 + 34)
    readonly property real _itemHeight: VLCStyle.rd_iconButtonHeight + VLCStyle.dp(16) + 2 * _labelLineHeight
    readonly property real _labelLineHeight: Math.ceil(fontMetrics.height)

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    currentIndex: -1
    highlightFollowsCurrentItem: false
    keyNavigationEnabled: false

    T.ScrollBar.vertical: Widgets.ScrollBarExt { }

    FontMetrics {
        id: fontMetrics
        font.family: VLCStyle.rd_fontFamily
        font.pixelSize: VLCStyle.rd_fontSize_label
    }

    displaced: Transition {
        NumberAnimation {
            properties: "x,y"
            duration: VLCStyle.rd_customizeDragDuration
        }
    }

    // ------------------------------------------------------------------------------ items

    // Figma icon per control (PlayerControlbarControls ids); "" = VLC's glyph
    function rdIconFor(id) {
        switch (id) {
        case ControlListModel.PLAY_BUTTON: return "play"
        case ControlListModel.STOP_BUTTON: return "stop"
        case ControlListModel.OPEN_BUTTON: return "open"
        case ControlListModel.PREVIOUS_BUTTON: return "previous"
        case ControlListModel.NEXT_BUTTON: return "next"
        case ControlListModel.FULLSCREEN_BUTTON: return "fullscreen"
        case ControlListModel.EXTENDED_BUTTON: return "playback-settings"
        case ControlListModel.PLAYLIST_BUTTON: return "lists"
        case ControlListModel.SNAPSHOT_BUTTON: return "snapshot"
        case ControlListModel.RECORD_BUTTON: return "record"
        // VLC's short jump, 10 s by default
        case ControlListModel.SKIP_BACK_BUTTON: return "backward-10-sec"
        case ControlListModel.SKIP_FW_BUTTON: return "forward-10-sec"
        case ControlListModel.QUIT_BUTTON: return "quit"
        case ControlListModel.RANDOM_BUTTON: return "shuffle_direction-right"
        case ControlListModel.LOOP_BUTTON: return "repeat_direction-right"
        case ControlListModel.INFO_BUTTON: return "info"
        case ControlListModel.AUDIO_TRACKS_BUTTON: return "audio"
        case ControlListModel.SUBTITLE_TRACKS_BUTTON: return "subtitles"
        case ControlListModel.BOOKMARK_BUTTON: return "bookmarks"
        case ControlListModel.VOLUME: return "volume_value-high"
        case ControlListModel.ARTWORK_INFO: return "thumbnail"
        case ControlListModel.PLAYBACK_SPEED_BUTTON: return "speed"
        default: return ""
        }
    }

    // Figma's name where the design has the same control, VLC's name otherwise
    function nameFor(entry) {
        switch (entry.id) {
        // VLC's short jump, 10 s by default; two lines as in Figma
        case ControlListModel.SKIP_FW_BUTTON: return qsTr("Forward\n10s")
        case ControlListModel.SKIP_BACK_BUTTON: return qsTr("Backward\n10s")
        case ControlListModel.LOOP_BUTTON: return qsTr("Repeat")
        case ControlListModel.RANDOM_BUTTON: return qsTr("Shuffle")
        case ControlListModel.INFO_BUTTON: return qsTr("Properties")
        case ControlListModel.BOOKMARK_BUTTON: return qsTr("Bookmarks")
        default: return entry.text
        }
    }

    // Figma's order first (Spacer, Playback Speed, Forward / Backward, Stop, Repeat, Shuffle,
    // Record, Snapshot ... Properties, Bookmarks), then VLC's other controls in VLC's order
    readonly property var _figmaOrder: [
        ControlListModel.WIDGET_SPACER, ControlListModel.WIDGET_SPACER_EXTEND,
        ControlListModel.PLAYBACK_SPEED_BUTTON, ControlListModel.SKIP_FW_BUTTON,
        ControlListModel.SKIP_BACK_BUTTON, ControlListModel.STOP_BUTTON,
        ControlListModel.LOOP_BUTTON, ControlListModel.RANDOM_BUTTON,
        ControlListModel.RECORD_BUTTON, ControlListModel.SNAPSHOT_BUTTON,
        ControlListModel.FULLSCREEN_BUTTON, ControlListModel.EXTENDED_BUTTON,
        ControlListModel.QUIT_BUTTON, ControlListModel.ARTWORK_INFO,
        ControlListModel.INFO_BUTTON, ControlListModel.CHAPTER_PREVIOUS_BUTTON,
        ControlListModel.CHAPTER_NEXT_BUTTON, ControlListModel.BOOKMARK_BUTTON,
        ControlListModel.PLAYLIST_BUTTON
    ]

    readonly property var _orderedControls: {
        const list = PlayerControlbarControls.controlList
        const first = []
        for (const id of _figmaOrder) {
            const entry = list.find((e) => e.id === id)
            if (entry)
                first.push(entry)
        }
        return first.concat(list.filter((e) => _figmaOrder.indexOf(e.id) < 0))
    }

    // the dashed outline of an item, as Figma draws it per icon: the spacers 24x32, the icons
    // outlined on the Icon instance itself 28x28 (quit, info, bookmarks, thumbnail, ...), the
    // others on their Icon Wrapper 30x32
    function frameSizeFor(id) {
        if (isRepeatable(id))
            return Qt.size(VLCStyle.rd_iconSize, VLCStyle.rd_iconButtonHeight)
        switch (rdIconFor(id)) {
        case "quit":
        case "info":
        case "bookmarks":
        case "thumbnail":
            return Qt.size(VLCStyle.dp(28), VLCStyle.dp(28))
        default:
            return Qt.size(VLCStyle.rd_iconButtonWidth, VLCStyle.rd_iconButtonHeight)
        }
    }

    function labelLines(text) {
        return (text.indexOf("\n") >= 0 || fontMetrics.advanceWidth(text) > VLCStyle.rd_customizeItemWidth) ? 2 : 1
    }

    // height of the tallest item from index `first` on (the last row)
    function itemsHeightFrom(first) {
        let height = 0
        for (let i = first; i < paletteModel.count; ++i) {
            const item = paletteModel.get(i)
            height = Math.max(height, frameSizeFor(item.controlId).height + VLCStyle.dp(16)
                                      + labelLines(item.text) * _labelLineHeight)
        }
        return height > 0 ? height : _itemHeight
    }

    function isRepeatable(id) {
        return id === ControlListModel.WIDGET_SPACER || id === ControlListModel.WIDGET_SPACER_EXTEND
    }

    // ids used by the edited bar
    function _usedIds() {
        const used = []
        if (!playerModel)
            return used
        for (const m of [playerModel.left, playerModel.center, playerModel.right]) {
            const n = m.rowCount()
            for (let i = 0; i < n; ++i)
                used.push(m.data(m.index(i, 0), Qt.UserRole))
        }
        return used
    }

    // brings the box in line with the bar: removes the used controls and puts back the others,
    // always in the same order, so the remaining items shift into place
    function refresh() {
        // never while an item of the box is dragged: its delegate must live until the drop ends
        if (editor && editor.paletteDragActive) {
            _refreshPending = true
            return
        }
        _refreshPending = false

        const used = _usedIds()
        const wanted = _orderedControls.filter((e) => isRepeatable(e.id) || used.indexOf(e.id) < 0)

        for (let i = paletteModel.count - 1; i >= 0; --i) {
            const id = paletteModel.get(i).controlId
            if (!wanted.some((e) => e.id === id))
                paletteModel.remove(i)
        }
        for (let i = 0; i < wanted.length; ++i) {
            if (i >= paletteModel.count || paletteModel.get(i).controlId !== wanted[i].id)
                paletteModel.insert(i, { controlId: wanted[i].id, label: wanted[i].label, text: nameFor(wanted[i]) })
        }
    }

    property bool _refreshPending: false

    function scheduleRefresh() {
        Qt.callLater(refresh)
    }

    onPlayerModelChanged: refresh()

    Connections {
        target: root.editor
        function onPaletteDragActiveChanged() {
            if (!root.editor.paletteDragActive && root._refreshPending)
                root.scheduleRefresh()
        }
    }

    Connections {
        target: root.playerModel ? root.playerModel.left : null
        function onCountChanged() { root.scheduleRefresh() }
    }
    Connections {
        target: root.playerModel ? root.playerModel.center : null
        function onCountChanged() { root.scheduleRefresh() }
    }
    Connections {
        target: root.playerModel ? root.playerModel.right : null
        function onCountChanged() { root.scheduleRefresh() }
    }

    model: ListModel {
        id: paletteModel
    }

    delegate: Item {
        id: tile

        required property int index
        required property int controlId
        required property string label
        required property string text

        // drop source identification (CustomizeZone.dropAt)
        readonly property int paletteControlId: controlId

        width: root.cellWidth
        height: root.cellHeight

        CustomizePaletteTile {
            id: tileContent

            box: root

            controlId: tile.controlId
            label: tile.label
            text: tile.text
            hovered: tileMouse.containsMouse
        }

        MouseArea {
            id: tileMouse

            x: tileContent.x
            width: tileContent.width
            height: tileContent.height

            hoverEnabled: true
            cursorShape: (pressed || root.editor.paletteDragActive) ? Qt.DragMoveCursor : Qt.OpenHandCursor

            drag.target: root.editor.dragGhost
            drag.smoothed: false

            onPressed: (mouse) => {
                const ghost = root.editor.dragGhost
                ghost.controlId = tile.controlId
                ghost.label = tile.label
                ghost.text = tile.text
                const pos = tileContent.mapToItem(ghost.parent, 0, 0)
                ghost.x = pos.x
                ghost.y = pos.y
                // drops happen where the cursor is
                ghost.Drag.hotSpot.x = mouse.x
                ghost.Drag.hotSpot.y = mouse.y
            }

            drag.onActiveChanged: {
                const ghost = root.editor.dragGhost
                if (drag.active) {
                    ghost.Drag.source = tile
                    root.editor.paletteDragStarted(tile.controlId)
                    ghost.Drag.start()
                } else {
                    ghost.Drag.drop()
                    root.editor.paletteDragStopped(tile.controlId)
                }
            }
        }
    }

    // a control dragged from the bar into the box is removed from the bar
    DropArea {
        id: removeDrop

        // the visible part of the box, whatever the scroll position
        parent: root
        x: 0
        y: 0
        width: root.width
        height: root.height
        z: 2

        onEntered: (drag) => {
            if (!drag.source || drag.source.paletteControlId !== undefined)
                drag.accepted = false
        }

        onDropped: (drop) => {
            drop.source.zone.model.remove(drop.source.index)
            drop.accept(Qt.MoveAction)
        }
    }
}
