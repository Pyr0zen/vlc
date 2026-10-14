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
// redesign: the accent colors of Settings > General (video 17:44-17:49, P8-05, P8-42, IB-43;
// Figma "Settings - global" "Accent color": a 320x36 BG/B2 strip, radius 6, padding 2, nine
// 32x32 cells 4 px apart, each a 20x20 square swatch (radius 1); the chosen cell has the
// BG/Accent Bright fill). Decision 15 colors, in her order. A click recolors the whole
// interface at once (MainCtx.accentColor, kept in "qt-accent-color").
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style

Rectangle {
    id: root

    // Decision 15 (figma/styles.txt); the first one is VLC's own accent
    readonly property var colors: ["#D37918", "#E15032", "#C49E23", "#19A234", "#18AAD3",
                                   "#185DD3", "#8E42FF", "#F052B3", "#AFAFAF"]
    readonly property var names: [qsTr("Orange"), qsTr("Red"), qsTr("Mustard"), qsTr("Green"),
                                  qsTr("Teal"), qsTr("Blue"), qsTr("Purple"), qsTr("Pink"),
                                  qsTr("Gray")]

    // no choice yet ("default") is VLC's orange
    readonly property int currentIndex: {
        const current = MainCtx.accentColor
        if (!current.valid)
            return 0
        return colors.indexOf(String(current).toUpperCase())
    }

    function select(index) {
        MainCtx.accentColor = Qt.color(colors[index])
    }

    implicitWidth: VLCStyle.dp(320)
    implicitHeight: VLCStyle.dp(36)
    radius: VLCStyle.rd_radius_normal
    color: VLCStyle.palette.rdBgB2

    Accessible.role: Accessible.List
    Accessible.name: qsTr("Accent color")

    Row {
        anchors.fill: parent
        anchors.margins: VLCStyle.dp(2)
        spacing: VLCStyle.dp(4)

        Repeater {
            model: root.colors.length

            delegate: T.AbstractButton {
                id: cell

                required property int index

                readonly property bool selected: root.currentIndex === index

                width: VLCStyle.dp(32)
                height: VLCStyle.dp(32)

                focusPolicy: Qt.StrongFocus
                hoverEnabled: true

                Accessible.role: Accessible.RadioButton
                Accessible.checked: selected
                Accessible.name: root.names[index]

                Keys.onReturnPressed: clicked()
                Keys.onEnterPressed: clicked()
                Keys.onLeftPressed: root.select(Math.max(0, index - 1))
                Keys.onRightPressed: root.select(Math.min(root.colors.length - 1, index + 1))

                onClicked: root.select(index)

                background: Rectangle {
                    radius: VLCStyle.rd_radius_small
                    color: cell.selected ? VLCStyle.palette.rdBgAccentBright
                                         : (cell.hovered ? VLCStyle.palette.rdHoverOverlay : "transparent")
                    border.width: cell.visualFocus ? VLCStyle.dp(1) : 0
                    border.color: VLCStyle.palette.rdFgA3
                }

                contentItem: Item {
                    Rectangle {
                        anchors.centerIn: parent
                        width: VLCStyle.dp(20)
                        height: VLCStyle.dp(20)
                        radius: VLCStyle.dp(1)
                        color: root.colors[cell.index]
                    }
                }
            }
        }
    }
}
