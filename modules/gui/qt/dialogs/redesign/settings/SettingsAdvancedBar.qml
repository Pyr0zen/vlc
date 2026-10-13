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
// redesign: "Advanced Options >" bar at the end of a settings page (video 18:48-18:55, Figma
// "Frame 265": full width x 38, radius 2, BG/A3 95%, centered Inter 14 FG/A2 text with a 24 px
// chevron 10 px after it). Expanded, the chevron points down and the advanced settings follow
// below the bar (Figma "Settings - global-1").
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

T.AbstractButton {
    id: control

    property bool expanded: false

    readonly property SystemPalette rdPalette: VLCStyle.palette

    implicitHeight: VLCStyle.dp(38)

    text: qsTr("Advanced Options")

    focusPolicy: Qt.StrongFocus
    hoverEnabled: true

    Accessible.role: Accessible.Button
    Accessible.name: text

    Keys.onReturnPressed: control.clicked()
    Keys.onEnterPressed: control.clicked()

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    background: Rectangle {
        radius: VLCStyle.rd_radius_xsmall
        color: control.rdPalette.rdBgA3Transparent

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: control.hovered
            color: control.rdPalette.rdHoverOverlay
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: control.visualFocus ? VLCStyle.dp(1) : 0
            border.color: control.rdPalette.rdFgA3
        }
    }

    contentItem: Item {
        Row {
            anchors.centerIn: parent
            spacing: VLCStyle.dp(10)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: control.text
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: control.rdPalette.rdFgA2
            }

            Widgets.RdIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: control.expanded ? "chevron_direction-down" : "chevron_direction-right"
                color: control.rdPalette.rdFgA2
            }
        }
    }
}
