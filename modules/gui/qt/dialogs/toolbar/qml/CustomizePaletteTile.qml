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

// redesign (W8.1a, Figma "Player - customize" palette item, e.g. "Frame 232"): the control's icon
// in a dashed outline (sized per icon as in Figma: CustomizePalette.frameSizeFor),
// its name 16 below, Inter 14 FG/A2, centered, at most two lines in the 86 wide item. Also drawn
// under the cursor while the item is dragged (video 19:22, P8-47).
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.PlayerControls

Item {
    id: root

    // CustomizePalette (icon names)
    property Item box: null

    property int controlId: -1
    property string label: ""      // VLC's glyph, for controls without a Figma icon
    property string text: ""
    property bool hovered: false

    readonly property bool _spacer: controlId === ControlListModel.WIDGET_SPACER
                                    || controlId === ControlListModel.WIDGET_SPACER_EXTEND
    readonly property string _rdIcon: box ? box.rdIconFor(controlId) : ""

    width: VLCStyle.rd_customizeItemWidth
    height: frame.height + VLCStyle.dp(16) + nameText.height

    Item {
        id: frame

        readonly property size _size: root.box ? root.box.frameSizeFor(root.controlId)
                                               : Qt.size(VLCStyle.rd_iconButtonWidth, VLCStyle.rd_iconButtonHeight)

        anchors.horizontalCenter: parent.horizontalCenter
        width: _size.width
        height: _size.height

        Widgets.RdDashedFrame {
            anchors.fill: parent
            color: root.hovered ? VLCStyle.palette.rdFgA2 : VLCStyle.palette.rdFgA3
        }

        Widgets.RdIcon {
            anchors.centerIn: parent
            visible: root._rdIcon !== ""
            name: root._rdIcon
            color: VLCStyle.palette.rdFgA2
        }

        Text {
            anchors.centerIn: parent
            visible: root._rdIcon === "" && !root._spacer
            text: root.label
            font.family: VLCIcons.fontFamily
            font.pixelSize: VLCStyle.rd_iconSize
            color: VLCStyle.palette.rdFgA2

            Accessible.ignored: true
        }
    }

    Text {
        id: nameText

        anchors.top: frame.bottom
        anchors.topMargin: VLCStyle.dp(16)
        width: parent.width

        text: root.text
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
        font.family: VLCStyle.rd_fontFamily
        font.pixelSize: VLCStyle.rd_fontSize_label
        color: VLCStyle.palette.rdFgA2
    }
}
