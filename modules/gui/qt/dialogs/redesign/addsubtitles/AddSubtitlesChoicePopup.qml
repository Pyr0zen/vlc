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

// redesign (Add Subtitles, W6.5, P3-09): the subtitles a video can be matched to by hand,
// opened by the swap icon of a match (video 6:16-6:22 shows the icon, not the list: Decision 21,
// the list is the dialog's dropdown list, Figma "target" / "origin"). It opens IN PLACE over the
// match, the current subtitle under the pointer with the accent check: this episode's
// subtitles first, then the others, then "No subtitles".
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

T.Popup {
    id: root

    property int maxVisibleRows: 7

    // a subtitle was picked: `candidate` -1 is "No subtitles"
    signal picked(int row, int candidate)

    readonly property SystemPalette rdPalette: VLCStyle.palette
    readonly property real _rowHeight: VLCStyle.dp(48)
    readonly property real _listPadding: VLCStyle.dp(2)

    property int _row: -1
    property var _choices: []
    property Item _anchor: null

    function openFor(anchor, row, choices) {
        _anchor = anchor
        _row = row
        _choices = choices

        const current = Math.max(0, choices.findIndex((c) => c.current))
        const visibleRows = Math.max(1, Math.min(choices.length, maxVisibleRows))
        const currentRow = Math.min(current, visibleRows - 1)

        const origin = anchor.mapToItem(parent, 0, 0)
        width = anchor.width + VLCStyle.dp(9)
        height = visibleRows * _rowHeight + 2 * _listPadding
        x = origin.x - VLCStyle.dp(4)
        y = origin.y - _listPadding - currentRow * _rowHeight - (_rowHeight - anchor.height) / 2

        open()
        listView.currentIndex = current
        listView.contentY = Math.max(0, current - currentRow) * _rowHeight
        listView.forceActiveFocus(Qt.PopupFocusReason)
    }

    function _pick(index) {
        const choice = _choices[index]
        if (!choice)
            return
        close()
        root.picked(_row, choice.candidate)
    }

    padding: _listPadding
    // inside the dialog's window area
    margins: 0

    modal: true
    dim: false
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside

    onClosed: {
        if (_anchor && _anchor.visible)
            _anchor.forceActiveFocus(Qt.PopupFocusReason)
        _anchor = null
        _choices = []
    }

    T.Overlay.modal: Item { }

    background: Rectangle {
        radius: VLCStyle.rd_radius_normal
        color: root.rdPalette.rdBgA4

        Widgets.RdShadow {
            color: root.rdPalette.rdListShadow
            yOffset: VLCStyle.dp(4)
            blurRadius: VLCStyle.dp(13.8)
        }
    }

    contentItem: ListView {
        id: listView

        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root._choices
        keyNavigationEnabled: true
        highlightFollowsCurrentItem: false

        T.ScrollBar.vertical: Widgets.ScrollBarExt { }

        Keys.onReturnPressed: root._pick(currentIndex)
        Keys.onEnterPressed: root._pick(currentIndex)
        Keys.onSpacePressed: root._pick(currentIndex)

        delegate: T.ItemDelegate {
            id: option

            required property int index
            required property var modelData

            width: ListView.view.width
            height: root._rowHeight
            hoverEnabled: true
            focusPolicy: Qt.NoFocus

            leftPadding: VLCStyle.dp(14)
            rightPadding: VLCStyle.dp(14)
            topPadding: VLCStyle.dp(2)
            bottomPadding: VLCStyle.dp(2)

            Accessible.role: Accessible.ListItem
            Accessible.name: modelData.name
            Accessible.selected: !!modelData.current

            onClicked: root._pick(index)

            background: Rectangle {
                radius: VLCStyle.rd_radius_normal
                color: (option.modelData.current || option.hovered
                        || (option.index === listView.currentIndex && listView.activeFocus))
                       ? root.rdPalette.rdBgA3 : "transparent"
            }

            contentItem: Item {
                Text {
                    anchors.left: parent.left
                    anchors.right: check.left
                    anchors.rightMargin: VLCStyle.dp(10)
                    anchors.verticalCenter: parent.verticalCenter

                    text: option.modelData.name
                    elide: Text.ElideMiddle
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_label
                    // subtitles of other episodes are dimmer
                    color: option.modelData.matched ? root.rdPalette.rdFgA2 : root.rdPalette.rdFgA3
                }

                Widgets.RdIcon {
                    id: check

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !!option.modelData.current
                    name: "check_state-active"
                }
            }
        }
    }
}
