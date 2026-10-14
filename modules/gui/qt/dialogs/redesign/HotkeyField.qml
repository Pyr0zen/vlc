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

// redesign: one hotkey field of the Keyboard Shortcuts dialog (Figma "Keyboard Shortcuts",
// "Frame 162" / "Frame 252": 270x33, radius 6, BG/B2, keys centered in DM Mono 400 14 FG/2,
// pencil icon FG/A4 5 px from the right edge).
// Click, Enter or Space starts capturing: the next key or combination (Escape included) and
// mouse wheel steps are captured instead of reaching any shortcut; Tab or a click elsewhere
// cancels. Delete or Backspace clears the field when it is not capturing.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Util
import VLC.Widgets as Widgets

T.AbstractButton {
    id: control

    // keys as shown ("Ctrl + F, Space")
    property string keys: ""
    property bool capturing: false
    // HotkeysModel, converts key events to VLC key strings
    property var hotkeys: null

    readonly property SystemPalette rdPalette: VLCStyle.palette

    // a VLC key string ("Ctrl+f", "Mouse Wheel Up")
    signal keyCaptured(string key)
    signal captureCancelled()
    signal clearRequested()
    signal contextMenuRequested(point position)
    // Up, Down, Left, Right, Tab and Backtab move between the fields
    signal navigationRequested(int key)
    signal focusEntered()

    implicitWidth: VLCStyle.dp(270)
    implicitHeight: VLCStyle.dp(33)

    focusPolicy: Qt.StrongFocus
    hoverEnabled: true

    Accessible.role: Accessible.Button
    Accessible.name: capturing ? qsTr("Press the new key or combination")
                               : (keys !== "" ? keys : qsTr("No shortcut"))
    Accessible.onPressAction: control.clicked()

    onActiveFocusChanged: {
        if (activeFocus)
            focusEntered()
        else if (capturing)
            captureCancelled()
    }

    // while capturing, shortcuts (Escape closing the dialog, the application shortcuts) must
    // not see the key: accepting the override delivers it to this field as a key press
    Keys.onShortcutOverride: (event) => {
        if (control.capturing)
            event.accepted = true
    }

    Keys.onPressed: (event) => {
        if (control.capturing) {
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                control.captureCancelled()
                control.navigationRequested(event.key)
                event.accepted = true
                return
            }
            event.accepted = true
            const key = control.hotkeys ? control.hotkeys.keyFromEvent(event.key, event.modifiers) : ""
            if (key !== "")
                control.keyCaptured(key)
            return
        }

        switch (event.key) {
        case Qt.Key_Delete:
        case Qt.Key_Backspace:
            event.accepted = true
            control.clearRequested()
            break
        case Qt.Key_Return:
        case Qt.Key_Enter:
            event.accepted = true
            control.clicked()
            break
        case Qt.Key_Up:
        case Qt.Key_Down:
        case Qt.Key_Left:
        case Qt.Key_Right:
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            event.accepted = true
            control.navigationRequested(event.key)
            break
        case Qt.Key_Menu:
            event.accepted = true
            control.contextMenuRequested(Qt.point(control.width / 2, control.height))
            break
        default:
            break
        }
    }

    Keys.onReleased: (event) => {
        if (control.capturing)
            event.accepted = true
    }

    background: Rectangle {
        radius: VLCStyle.rd_radius_normal
        color: control.rdPalette.rdBgB2
        border.width: (control.capturing || control.visualFocus) ? VLCStyle.dp(1) : 0
        border.color: control.capturing ? control.rdPalette.rdAccentMain : control.rdPalette.rdFgA3

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: control.rdPalette.rdHoverOverlay
            visible: control.hovered && !control.capturing
        }
    }

    contentItem: Item {
        Text {
            anchors.verticalCenter: parent.verticalCenter
            // centered in the field; long key lists stay clear of the pencil
            x: Math.max(VLCStyle.dp(20), (control.width - width) / 2)
            width: Math.min(implicitWidth, control.width - VLCStyle.dp(20) - pencil.width - VLCStyle.dp(10))

            text: control.capturing ? qsTr("Press a key") : control.keys
            elide: Text.ElideRight
            font.family: control.capturing ? VLCStyle.rd_fontFamily : VLCStyle.rd_fontFamilyMono
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: control.capturing ? control.rdPalette.rdFgA3 : control.rdPalette.rdFg2
        }

        Widgets.RdIcon {
            id: pencil

            anchors.verticalCenter: parent.verticalCenter
            x: control.width - width - VLCStyle.dp(5)
            name: "edit"
            color: control.capturing ? control.rdPalette.rdAccentMain
                                     : (control.hovered ? control.rdPalette.rdFgA2 : control.rdPalette.rdFgA4)
        }
    }

    // right click: change / clear / reset menu; wheel while capturing: a mouse wheel binding
    MouseArea {
        anchors.fill: parent

        acceptedButtons: Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => control.contextMenuRequested(Qt.point(mouse.x, mouse.y))

        onWheel: (wheel) => {
            if (!control.capturing) {
                wheel.accepted = false
                return
            }
            wheel.accepted = true
            wheelConverter.qmlWheelEvent(wheel)
        }
    }

    WheelToVLCConverter {
        id: wheelConverter

        onVlcWheelKey: (key) => {
            if (!control.capturing || !control.hotkeys)
                return
            const name = control.hotkeys.keyFromCode(key)
            if (name !== "")
                control.keyCaptured(name)
        }
    }
}
