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

// Redesign toggle (Figma component "Toggle", 68x32): square knob plus ON / OFF label.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style

T.AbstractButton {
    id: control

    checkable: true

    implicitWidth: VLCStyle.dp(68)
    implicitHeight: VLCStyle.dp(32)

    focusPolicy: Qt.StrongFocus

    Accessible.role: Accessible.CheckBox
    Accessible.checked: control.checked

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    readonly property SystemPalette rdPalette: VLCStyle.palette

    background: Rectangle {
        radius: VLCStyle.rd_radius_normal
        color: control.rdPalette.rdBgB2
        border.width: control.visualFocus ? VLCStyle.dp(1) : 0
        border.color: control.rdPalette.rdFgA3
    }

    contentItem: Item {
        // knob side highlight (Figma "Rectangle 11", 33x26)
        Rectangle {
            id: track

            width: VLCStyle.dp(33)
            height: VLCStyle.dp(26)
            radius: VLCStyle.dp(3)
            anchors.verticalCenter: parent.verticalCenter
            x: control.checked ? parent.width - width - VLCStyle.dp(3) : VLCStyle.dp(3)
            color: control.checked ? control.rdPalette.rdBgAccentBright : control.rdPalette.rdBgA4
        }

        // knob (Figma "Rectangle 12", 26x26)
        Rectangle {
            width: VLCStyle.dp(26)
            height: VLCStyle.dp(26)
            radius: VLCStyle.dp(3)
            anchors.verticalCenter: parent.verticalCenter
            x: control.checked ? parent.width - width - VLCStyle.dp(3) : VLCStyle.dp(3)
            color: control.checked ? control.rdPalette.rdAccentDim : control.rdPalette.rdFgA4
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            x: control.checked ? VLCStyle.dp(10) : parent.width - width - VLCStyle.dp(8)
            text: control.checked ? qsTr("ON") : qsTr("OFF")
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_toggle
            color: control.checked ? control.rdPalette.rdAccentMain : control.rdPalette.rdFgA3
        }
    }
}
