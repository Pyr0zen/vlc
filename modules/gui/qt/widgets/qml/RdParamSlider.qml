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

// Redesign setting with a slider (Figma "Frame 96", video 8:46-8:52): the name on the left and
// the value on the right of a 37 px row, the slider under it at full width. The value is plain
// text (filter parameters, sizes) or an editable value box (equalizer bands, valueBox: true).
import QtQuick
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style

ColumnLayout {
    id: root

    property alias text: label.text
    property string valueText: ""
    property bool valueBox: false

    property alias from: slider.from
    property alias to: slider.to
    property alias stepSize: slider.stepSize
    property alias value: slider.value
    property alias bipolar: slider.bipolar
    property alias zeroValue: slider.zeroValue
    property alias showTicks: slider.showTicks
    property alias labels: slider.labels
    readonly property alias pressed: slider.pressed

    // the user moved the slider / typed a value in the box
    signal moved(real value)
    signal edited(string text)

    readonly property SystemPalette rdPalette: VLCStyle.palette

    Layout.fillWidth: true
    spacing: VLCStyle.dp(5)

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: root.valueBox ? VLCStyle.dp(48) : VLCStyle.dp(37)

        Text {
            id: label

            anchors.left: parent.left
            anchors.leftMargin: VLCStyle.dp(4)
            anchors.right: valueArea.left
            anchors.rightMargin: VLCStyle.dp(10)
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: root.rdPalette.rdFgA3
        }

        Item {
            id: valueArea

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: root.valueBox ? box.implicitWidth : plainValue.implicitWidth + VLCStyle.dp(4)
            height: root.valueBox ? box.implicitHeight : plainValue.implicitHeight

            Text {
                id: plainValue

                visible: !root.valueBox
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.valueText
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: root.rdPalette.rdFgA3
            }

            RdValueBox {
                id: box

                visible: root.valueBox
                text: root.valueText
                Accessible.name: label.text
                onEdited: (value) => root.edited(value)
            }
        }
    }

    RdSlider {
        id: slider

        Layout.fillWidth: true
        Accessible.name: label.text
        onMoved: root.moved(value)
    }
}
