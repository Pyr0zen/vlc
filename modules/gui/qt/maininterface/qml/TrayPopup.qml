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
// redesign: VLC's own track-change popup near the system tray (S2-03, Settings > Interface
// "Popup duration", Decision 34). Windows takes the tray balloon's time only as a hint and keeps
// its own ("Show notifications for"), so the popup is drawn here and closed by its own timer,
// which runs only while the popup shows (paused while the mouse is on it). No Figma frame:
// Figma's toast ("continue" 1919:9580) styles it: BG/A3, radius 16, 52 high, padding 20 / 10,
// Inter 16 FG/2, the 44x32 close button. Bottom-right of the primary screen's free area.
import QtQuick
import QtQuick.Window
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

Window {
    id: root

    property string trackName: ""
    property url artwork: ""
    property int duration: 4000

    // the screen's free area (the taskbar excluded), in the screen's coordinates
    property rect area: Qt.rect(0, 0, 0, 0)

    readonly property real margin: VLCStyle.dp(16, VLCStyle.scale)
    readonly property bool _hasArt: artwork.toString() !== "" && art.status === Image.Ready

    function popup(name, artworkUrl, freeArea, durationMs) {
        trackName = name
        artwork = artworkUrl
        area = freeArea
        duration = durationMs
        // a new track while the popup shows starts its time again
        closeTimer.restart()
        show()
    }

    // independent of the main window: the popup shows while VLC is minimized or in the tray. A
    // tool window (no taskbar button; a tooltip window would get Windows' square drop shadow)
    // that never takes the focus
    transientParent: null
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
    color: "transparent"

    width: Math.min(VLCStyle.dp(420, VLCStyle.scale), content.implicitWidth)
    height: VLCStyle.dp(52, VLCStyle.scale)
    x: area.x + area.width - width - margin
    y: area.y + area.height - height - margin

    Timer {
        id: closeTimer

        interval: root.duration
        running: root.visible && !hover.hovered
        onTriggered: root.close()
    }

    Rectangle {
        anchors.fill: parent
        radius: VLCStyle.rd_radius_toast
        // opaque, like the other popups (Figma's 95 % is meant with a background blur)
        color: Qt.alpha(VLCStyle.palette.rdBgA3Transparent, 1.0)

        Accessible.role: Accessible.AlertMessage
        Accessible.name: root.trackName

        HoverHandler {
            id: hover
        }

        // a click on the popup dismisses it
        TapHandler {
            onTapped: root.close()
        }
    }

    Row {
        id: content

        anchors.verticalCenter: parent.verticalCenter
        leftPadding: root._hasArt ? VLCStyle.dp(10, VLCStyle.scale) : VLCStyle.dp(20, VLCStyle.scale)
        rightPadding: VLCStyle.dp(10, VLCStyle.scale)
        spacing: VLCStyle.dp(10, VLCStyle.scale)

        // the track's cover (square, as the system popup's icon)
        Image {
            id: art

            anchors.verticalCenter: parent.verticalCenter
            visible: root._hasArt
            width: VLCStyle.dp(32, VLCStyle.scale)
            height: width
            source: root.artwork
            sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }

        T.Label {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth,
                            VLCStyle.dp(420, VLCStyle.scale) - content.leftPadding - content.rightPadding
                            - (art.visible ? art.width + content.spacing : 0)
                            - closeButton.width - content.spacing)
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: root.trackName
            color: VLCStyle.palette.rdFg2
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_header
        }

        T.Button {
            id: closeButton

            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: VLCStyle.dp(44, VLCStyle.scale)
            implicitHeight: VLCStyle.dp(32, VLCStyle.scale)
            focusPolicy: Qt.NoFocus

            Accessible.name: qsTr("Dismiss")

            onClicked: root.close()

            background: Rectangle {
                radius: VLCStyle.rd_radius_normal
                color: closeButton.hovered ? VLCStyle.palette.rdBgA2 : VLCStyle.palette.rdBgA1
            }

            contentItem: Item {
                Widgets.RdIcon {
                    anchors.centerIn: parent
                    name: "close"
                    color: VLCStyle.palette.rdFgA2
                }
            }
        }
    }
}
