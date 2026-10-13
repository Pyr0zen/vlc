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
// redesign: one category of the Settings dialog's left column (Figma component "setting
// category", 188x40, padding 4, gap 8, radius 2, 24 px icon in a 32 px cell, Inter 14).
// Idle: outline icon and text FG/A2. Selected: BG/A1 row, the icon's filled accent variant
// ("<icon>_state-active", follows the live accent) and FG/1 text (video 17:36-17:39, P8-39).
// The design has no hover state; the row takes the icon buttons' hover tint.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

T.AbstractButton {
    id: control

    // Figma icon name (pixmaps/redesign/<icon>.svg)
    property string iconName: ""
    property bool selected: false

    readonly property SystemPalette rdPalette: VLCStyle.palette

    implicitHeight: VLCStyle.rd_settingsCategoryHeight

    padding: VLCStyle.dp(4)

    focusPolicy: Qt.StrongFocus
    hoverEnabled: true

    Accessible.role: Accessible.PageTab
    Accessible.name: text
    Accessible.selected: selected

    Keys.onReturnPressed: control.clicked()
    Keys.onEnterPressed: control.clicked()

    background: Rectangle {
        radius: VLCStyle.rd_radius_xsmall
        color: control.selected ? control.rdPalette.rdBgA1
                                : (control.hovered ? control.rdPalette.rdHoverOverlay : "transparent")
        border.width: control.visualFocus ? VLCStyle.dp(1) : 0
        border.color: control.rdPalette.rdFgA3
    }

    contentItem: Item {
        Item {
            id: iconCell

            width: VLCStyle.dp(32)
            height: VLCStyle.dp(32)
            anchors.verticalCenter: parent.verticalCenter

            Widgets.RdIcon {
                anchors.centerIn: parent
                name: control.iconName === "" ? "" : (control.selected ? control.iconName + "_state-active" : control.iconName)
                color: control.rdPalette.rdFgA2
            }
        }

        Text {
            anchors.left: iconCell.right
            anchors.leftMargin: VLCStyle.dp(8)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: control.text
            elide: Text.ElideRight
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: control.selected ? control.rdPalette.rdFg1 : control.rdPalette.rdFgA2
        }
    }
}
