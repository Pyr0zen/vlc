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

// redesign (W8.1a): asks for a layout profile name (new, duplicate, rename) inside the Customize
// Player dialog. No Figma frame (Decision 21): the redesign dialog style (BG/B1 box, radius 14,
// BG/B2 header with the title FG/A2, RdTextField, Cancel / Save footer like Figma's dialogs).
// Enter saves, Escape cancels.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

T.Popup {
    id: root

    property string title: ""

    signal accepted(string name)

    function ask(title, name) {
        root.title = title
        nameField.text = name
        open()
    }

    anchors.centerIn: parent

    width: Math.min(VLCStyle.dp(400), parent ? parent.width - 2 * VLCStyle.margin_large : VLCStyle.dp(400))
    height: content.implicitHeight

    padding: 0
    modal: true
    dim: false
    focus: true
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside

    onOpened: {
        nameField.selectAll()
        nameField.forceActiveFocus(Qt.PopupFocusReason)
    }

    function _accept() {
        const name = nameField.text.trim()
        if (name === "")
            return
        close()
        accepted(name)
    }

    background: Rectangle {
        radius: VLCStyle.rd_radius_large
        color: Qt.alpha(VLCStyle.palette.rdBgB1Transparent, 1.0)

        Widgets.RdShadow { }
    }

    contentItem: Column {
        id: content

        // keys the prompt does not handle stay in it; Escape goes on to the popup, which closes
        Keys.onPressed: (event) => {
            event.accepted = (event.key !== Qt.Key_Escape && event.key !== Qt.Key_Back)
        }

        Rectangle {
            width: parent.width
            height: VLCStyle.dp(50)

            radius: VLCStyle.rd_radius_large
            color: VLCStyle.palette.rdBgB2

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
                anchors.right: parent.right
                anchors.leftMargin: VLCStyle.dp(19)
                anchors.rightMargin: VLCStyle.dp(19)
                anchors.verticalCenter: parent.verticalCenter

                text: root.title
                elide: Text.ElideRight
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: VLCStyle.palette.rdFgA2

                Accessible.role: Accessible.TitleBar
                Accessible.name: text
            }
        }

        Item {
            width: parent.width
            height: nameField.height + 2 * VLCStyle.dp(20)

            Widgets.RdTextField {
                id: nameField

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: VLCStyle.dp(20)
                anchors.verticalCenter: parent.verticalCenter

                placeholderText: qsTr("Profile name")
                Accessible.name: root.title

                KeyNavigation.tab: cancelButton
                KeyNavigation.backtab: saveButton.enabled ? saveButton : cancelButton

                Keys.onReturnPressed: root._accept()
                Keys.onEnterPressed: root._accept()
            }
        }

        Item {
            width: parent.width
            height: VLCStyle.rd_dialogFooterHeight

            Widgets.RdButton {
                id: cancelButton

                anchors.left: parent.left
                anchors.leftMargin: VLCStyle.dp(20)
                anchors.verticalCenter: parent.verticalCenter

                text: qsTr("Cancel")

                KeyNavigation.tab: saveButton.enabled ? saveButton : nameField
                KeyNavigation.backtab: nameField

                onClicked: root.close()
            }

            Widgets.RdButton {
                id: saveButton

                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.dp(20)
                anchors.verticalCenter: parent.verticalCenter

                style: Widgets.RdButton.Style.Save
                text: qsTr("Save")
                enabled: nameField.text.trim() !== ""

                KeyNavigation.tab: nameField
                KeyNavigation.backtab: cancelButton

                onClicked: root._accept()
            }
        }
    }
}
