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

// Redesign value box (Figma "text_input": 140x36, padding 10,18,10,12, radius 6, BG/B2 with a
// 2 px BG/A4 inside stroke (accent while typing), Inter 14
// FG/A2). Shows a value; when editable, clicking it lets the user type a new one (Enter applies,
// Escape cancels). An optional color swatch (22x22, radius 2) sits at the right (Text Color).
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style

T.Control {
    id: control

    property string text: ""
    property bool editable: true
    property color swatch: "transparent"
    property bool showSwatch: false
    // input validation while typing
    property var validator: null

    signal edited(string text)

    readonly property SystemPalette rdPalette: VLCStyle.palette
    readonly property bool editing: input.activeFocus

    implicitWidth: VLCStyle.dp(140)
    implicitHeight: VLCStyle.dp(36)

    leftPadding: VLCStyle.dp(12)
    rightPadding: showSwatch ? VLCStyle.dp(5) : VLCStyle.dp(18)

    hoverEnabled: true

    background: Rectangle {
        radius: VLCStyle.rd_radius_normal
        color: control.rdPalette.rdBgB2
        border.width: VLCStyle.dp(2)
        border.color: control.editing ? control.rdPalette.rdAccentMain : control.rdPalette.rdBgA4
    }

    contentItem: Item {
        TextInput {
            id: input

            anchors.left: parent.left
            anchors.right: swatchRect.visible ? swatchRect.left : parent.right
            anchors.rightMargin: swatchRect.visible ? VLCStyle.dp(8) : 0
            anchors.verticalCenter: parent.verticalCenter

            readOnly: !control.editable
            activeFocusOnPress: control.editable
            activeFocusOnTab: control.editable
            clip: true
            selectByMouse: true
            validator: control.validator
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: control.rdPalette.rdFgA2
            selectionColor: control.rdPalette.rdAccentMain
            selectedTextColor: control.rdPalette.rdFgB1
            cursorDelegate: Rectangle {
                width: VLCStyle.dp(1)
                color: control.rdPalette.rdAccentMain
                visible: input.activeFocus
            }

            Accessible.role: Accessible.EditableText
            Accessible.name: control.Accessible.name

            Binding on text {
                when: !input.activeFocus
                value: control.text
                // keep the shown value when editing starts
                restoreMode: Binding.RestoreNone
            }

            onActiveFocusChanged: {
                if (activeFocus)
                    selectAll()
            }

            onAccepted: {
                control.edited(text)
                focus = false
            }

            // Escape cancels the edit before the player's Escape shortcut closes the panel
            Keys.onShortcutOverride: (event) => {
                if (event.key === Qt.Key_Escape)
                    event.accepted = true
            }

            Keys.onEscapePressed: (event) => {
                focus = false
                event.accepted = true
            }
        }

        Rectangle {
            id: swatchRect

            visible: control.showSwatch
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: VLCStyle.dp(22)
            height: VLCStyle.dp(22)
            radius: VLCStyle.rd_radius_xsmall
            color: control.swatch
            border.width: VLCStyle.dp(1)
            border.color: control.rdPalette.rdDividerBright
        }
    }
}
