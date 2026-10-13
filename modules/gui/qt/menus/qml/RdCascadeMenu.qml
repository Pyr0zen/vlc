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

// redesign: cascading menu in the Figma menu style (menu.png, right-click menu.png, Profiles.png):
// panels of 48 px option rows with 1 px Divider/Dim lines, BG/A3 95%, radius 10, padding 4. A
// submenu opens 11 px to the right of its row, its first row level with that row (Profiles.png),
// on hover after a short delay, on click, or with the Right key.
// The rows come from a RdMenuModel (VLC's own menus as data). One popup covers the window, so
// the levels never close each other; a click outside the panels closes the menu.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

T.Popup {
    id: root

    // RdMenuModel of the first level
    property QtObject model: null
    property real rootWidth: VLCStyle.rd_menuWidth
    property bool withShadow: true

    readonly property int _maxDepth: 5
    readonly property real _margin: VLCStyle.margin_xsmall
    readonly property real _padding: VLCStyle.rd_menuPadding

    // the open levels: _models[i] is the model of level i, _anchors[i] where its panel opens,
    // _openRows[i] the row of level i whose submenu is level i + 1
    property var _models: []
    property var _anchors: []
    property var _openRows: []
    property bool _keyboard: false

    // the last hovered row, applied when the hover delay ends
    property int _pendingLevel: -1
    property int _pendingRow: -1

    parent: T.Overlay.overlay
    x: 0
    y: 0
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    padding: 0
    modal: false
    dim: false
    focus: true
    closePolicy: T.Popup.NoAutoClose

    // opens the menu with its top left corner at (px, py) in `item` coordinates, kept inside the
    // window; `keyboard` puts the focus on the first row
    function popupAt(item, px, py, keyboard) {
        if (!root.model || !root.parent || !item)
            return

        const p = item.mapToItem(root.parent, px, py)

        hoverTimer.stop()
        root._pendingLevel = -1
        root.model.build()

        root._models = [root.model]
        root._anchors = [{ x: p.x, y: p.y }]
        root._openRows = []
        root._keyboard = !!keyboard
        root.open()
    }

    function _reset() {
        if (root.visible)
            return
        hoverTimer.stop()
        root._models = []
        root._anchors = []
        root._openRows = []
    }

    function _rowItem(level, row) {
        const panel = levels.itemAt(level)
        return panel ? panel.rowAt(row) : null
    }

    function _focusRow(level, row, direction) {
        const panel = levels.itemAt(level)
        if (panel)
            panel.focusRow(row, direction)
    }

    function _closeLevels(count) {
        if (root._models.length <= count)
            return
        root._models = root._models.slice(0, count)
        root._anchors = root._anchors.slice(0, count)
        root._openRows = root._openRows.slice(0, Math.max(0, count - 1))
    }

    function _openSubmenu(level, row, keyboard) {
        if (level + 1 >= root._maxDepth || level >= root._models.length)
            return

        const model = root._models[level]
        const rowItem = root._rowItem(level, row)
        const panel = levels.itemAt(level)
        if (!model || !rowItem || !panel)
            return

        const submenu = model.submenu(row)
        if (!submenu)
            return

        if (root._models.length > level + 1 && root._openRows[level] === row) {
            root._closeLevels(level + 2)
        } else {
            submenu.aboutToShow()

            const p = rowItem.mapToItem(root.contentItem, 0, 0)
            const models = root._models.slice(0, level + 1)
            const anchors = root._anchors.slice(0, level + 1)
            const openRows = root._openRows.slice(0, level)
            models.push(submenu)
            anchors.push({ right: panel.x + panel.width + VLCStyle.rd_submenuGap,
                           left: panel.x - VLCStyle.rd_submenuGap,
                           y: p.y - root._padding })
            openRows.push(row)
            root._models = models
            root._anchors = anchors
            root._openRows = openRows
        }

        if (keyboard)
            Qt.callLater(root._focusRow, level + 1, 0, 1)
    }

    // Left / Escape: back to the parent level, or close the first level
    function _back(level) {
        if (level <= 0) {
            root.close()
            return
        }
        const row = root._openRows[level - 1]
        root._closeLevels(level)
        root._focusRow(level - 1, row, 1)
    }

    function _activate(level, row, keyboard) {
        const rowItem = root._rowItem(level, row)
        if (!rowItem || rowItem.separator || !rowItem.actionEnabled)
            return

        if (rowItem.hasSubmenu) {
            root._openSubmenu(level, row, keyboard)
            return
        }

        const model = root._models[level]
        root.close()
        // after the menu is gone: the entry may open a modal dialog
        Qt.callLater(() => model.trigger(row))
    }

    function _hover(level, row) {
        root._pendingLevel = level
        root._pendingRow = row
        hoverTimer.restart()
    }

    function _applyHover() {
        const level = root._pendingLevel
        const row = root._pendingRow
        if (level < 0 || level >= root._models.length)
            return

        const rowItem = root._rowItem(level, row)
        if (rowItem && rowItem.hasSubmenu && rowItem.actionEnabled)
            root._openSubmenu(level, row, false)
        else
            root._closeLevels(level + 1)
    }

    onOpened: {
        if (root._keyboard)
            root._focusRow(0, 0, 1)
        else
            menuScope.forceActiveFocus()
    }

    // the panels go away once the click that closed the menu is handled
    onClosed: Qt.callLater(root._reset)

    Timer {
        id: hoverTimer

        interval: VLCStyle.duration_long
        onTriggered: root._applyHover()
    }

    Connections {
        target: Qt.application

        // like a native menu, the menu closes when the application loses the focus
        function onStateChanged() {
            if (Qt.application.state !== Qt.ApplicationActive)
                root.close()
        }
    }

    contentItem: FocusScope {
        id: menuScope

        focus: true

        Keys.onPressed: (event) => {
            const deepest = root._models.length - 1
            if (deepest < 0)
                return

            if (event.key === Qt.Key_Down) {
                root._focusRow(deepest, 0, 1)
                event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                root._focusRow(deepest, -1, -1)
                event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
                root._back(deepest)
                event.accepted = true
            }
        }

        // outside the panels: a click closes the menu; the wheel does not reach the player
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: root.close()
            onWheel: (wheel) => { wheel.accepted = true }
        }

        Repeater {
            id: levels

            model: root._maxDepth

            delegate: Rectangle {
                id: panel

                required property int index

                readonly property QtObject menuModel: index < root._models.length ? root._models[index] : null
                readonly property var anchor: index < root._anchors.length ? root._anchors[index] : null
                readonly property int openRow: index < root._openRows.length ? root._openRows[index] : -1

                // widest row, for submenus with long entries (track names ...)
                property real naturalWidth: 0

                function rowAt(row) {
                    return rows.itemAt(row)
                }

                // focuses the first enabled row from `row` on in `direction`, wrapping around
                function focusRow(row, direction) {
                    const count = rows.count
                    for (let k = 0; k < count; ++k) {
                        const i = (((row + k * direction) % count) + count) % count
                        const item = rows.itemAt(i)
                        if (item && !item.separator && item.actionEnabled) {
                            item.focusOption()
                            return
                        }
                    }
                }

                function updateNaturalWidth() {
                    let width = 0
                    for (let i = 0; i < rows.count; ++i) {
                        const item = rows.itemAt(i)
                        if (item)
                            width = Math.max(width, item.naturalWidth)
                    }
                    naturalWidth = width
                }

                visible: menuModel !== null && anchor !== null && rows.count > 0

                width: index === 0 ? root.rootWidth
                                   : Math.max(VLCStyle.rd_menuWidth,
                                              Math.min(VLCStyle.rd_menuMaxWidth, naturalWidth + 2 * root._padding))
                height: Math.min(column.height + 2 * root._padding, root.height - 2 * root._margin)

                x: {
                    if (!anchor)
                        return 0
                    if (index === 0)
                        return Math.max(root._margin, Math.min(anchor.x, root.width - width - root._margin))
                    if (anchor.right + width <= root.width - root._margin)
                        return anchor.right
                    return Math.max(root._margin, anchor.left - width)
                }
                y: anchor ? Math.max(root._margin, Math.min(anchor.y, root.height - height - root._margin)) : 0

                radius: VLCStyle.rd_radius_panel
                color: VLCStyle.palette.rdBgA3Transparent

                Widgets.RdShadow {
                    visible: root.withShadow
                }

                // clicks on the panel's padding stay in the menu
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onWheel: (wheel) => { wheel.accepted = true }
                }

                Flickable {
                    id: flick

                    anchors.fill: parent
                    anchors.margins: root._padding

                    contentHeight: column.height
                    interactive: contentHeight > height
                    clip: interactive
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: column

                        width: flick.width

                        Repeater {
                            id: rows

                            model: panel.menuModel

                            onItemAdded: Qt.callLater(panel.updateNaturalWidth)
                            onItemRemoved: Qt.callLater(panel.updateNaturalWidth)

                            delegate: Item {
                                id: entry

                                required property int index
                                required property string label
                                required property string iconName
                                required property bool iconAccent
                                required property string shortcut
                                required property bool checkable
                                required property bool checked
                                required property bool actionEnabled
                                required property bool separator
                                required property bool hasSubmenu

                                readonly property real naturalWidth: separator ? 0
                                    : option.leftPadding + VLCStyle.rd_iconSize + option.spacing
                                      + labelMetrics.advanceWidth + option.spacing
                                      + (hasSubmenu ? VLCStyle.rd_iconSize
                                                    : Math.max(VLCStyle.rd_iconSize, shortcutMetrics.advanceWidth))
                                      + option.rightPadding

                                function focusOption() {
                                    option.forceActiveFocus(Qt.TabFocusReason)
                                    if (entry.y < flick.contentY)
                                        flick.contentY = entry.y
                                    else if (entry.y + entry.height > flick.contentY + flick.height)
                                        flick.contentY = entry.y + entry.height - flick.height
                                }

                                onNaturalWidthChanged: Qt.callLater(panel.updateNaturalWidth)

                                width: column.width
                                height: separator ? divider.height : option.height

                                TextMetrics {
                                    id: labelMetrics

                                    font.family: VLCStyle.rd_fontFamily
                                    font.pixelSize: VLCStyle.rd_fontSize_label
                                    text: entry.label
                                }

                                TextMetrics {
                                    id: shortcutMetrics

                                    font.family: VLCStyle.rd_fontFamily
                                    font.pixelSize: VLCStyle.rd_fontSize_label
                                    text: entry.shortcut
                                }

                                Widgets.RdMenuDivider {
                                    id: divider

                                    visible: entry.separator
                                    width: parent.width
                                }

                                Widgets.RdOptionRow {
                                    id: option

                                    visible: !entry.separator
                                    width: parent.width

                                    text: entry.label
                                    // checked entries show the accent check in the icon column (Profiles.png)
                                    rdIcon: (entry.checkable && entry.checked) ? "check_state-active" : entry.iconName
                                    reserveIconSpace: true
                                    iconColor: entry.iconAccent ? VLCStyle.palette.rdAccentDim : VLCStyle.palette.rdFgA2
                                    shortcut: entry.shortcut
                                    hasSubmenu: entry.hasSubmenu
                                    enabled: entry.actionEnabled
                                    active: panel.openRow === entry.index

                                    Accessible.role: Accessible.MenuItem
                                    Accessible.checkable: entry.checkable
                                    Accessible.checked: entry.checked

                                    onHoveredChanged: {
                                        if (!hovered)
                                            return
                                        // the mouse takes over from the keyboard highlight
                                        forceActiveFocus(Qt.MouseFocusReason)
                                        root._hover(panel.index, entry.index)
                                    }

                                    onClicked: root._activate(panel.index, entry.index, visualFocus)

                                    Keys.onReturnPressed: root._activate(panel.index, entry.index, true)
                                    Keys.onEnterPressed: root._activate(panel.index, entry.index, true)

                                    Navigation.upAction: () => panel.focusRow(entry.index - 1, -1)
                                    Navigation.downAction: () => panel.focusRow(entry.index + 1, 1)
                                    Navigation.rightAction: () => {
                                        if (entry.hasSubmenu && entry.actionEnabled)
                                            root._openSubmenu(panel.index, entry.index, true)
                                    }
                                    Navigation.leftAction: () => root._back(panel.index)
                                    Navigation.cancelAction: () => root._back(panel.index)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
