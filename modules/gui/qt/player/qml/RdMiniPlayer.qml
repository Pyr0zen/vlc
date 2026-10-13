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

// redesign: the mini player of the full library (video 11:48-11:56; P5-27, P5-28, IB-18, F-17;
// Figma "Miniplayer" 391x339, 391x690 with the queue): a card (BG/A3, radius 14, padding 8,
// shadow) with the video (375x211, radius 6, 2 px BG/B2 border) or the cover of a song, a thin
// seek bar, the file name, the folder (and artist) chips and the queue button (accent while the
// queue shows). Hovering the picture dims it and shows close, open, previous, play and next.
// The queue opens attached to the card. The card is dragged by its picture and snaps to the
// nearest corner (300 ms, ease out).
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Playlist
import VLC.Widgets as Widgets

Item {
    id: root

    // the area the card moves in (corners)
    property real margin: VLCStyle.dp(20)
    property bool queueOpen: false
    // corner: "bottomRight" (default), "bottomLeft", "topRight", "topLeft"
    property string corner: "bottomRight"

    // the folder chip: the library opens the folder of the playing file
    signal folderClicked()

    readonly property real cardWidth: VLCStyle.dp(391)
    readonly property real playerHeight: VLCStyle.dp(339)
    readonly property real queueHeight: VLCStyle.dp(351)

    readonly property bool _top: corner === "topRight" || corner === "topLeft"
    readonly property bool _left: corner === "bottomLeft" || corner === "topLeft"

    width: cardWidth
    height: playerHeight + (queueOpen ? queueHeight : 0)

    x: _left ? margin : (parent ? parent.width - width - margin : 0)
    y: _top ? margin : (parent ? parent.height - height - margin : 0)

    Behavior on x {
        enabled: !dragHandler.active
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }
    Behavior on y {
        enabled: !dragHandler.active
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    // Parent folder of the playing file (as the top bar's folder chip)
    readonly property string folderName: {
        const url = Player.url ? Player.url.toString() : ""
        if (url === "")
            return ""
        const parts = decodeURIComponent(url).replace(/\\/g, "/").split("/").filter((p) => p !== "")
        return parts.length >= 2 ? parts[parts.length - 2] : ""
    }

    readonly property string fileName: {
        const url = Player.url ? Player.url.toString() : ""
        if (url === "")
            return Player.title
        const parts = decodeURIComponent(url).split("/")
        return parts[parts.length - 1]
    }

    readonly property bool _ended: Player.playingState === Player.PLAYING_STATE_STOPPED

    Rectangle {
        id: card

        anchors.fill: parent
        radius: VLCStyle.rd_radius_large
        color: VLCStyle.palette.rdBgA3

        Widgets.RdShadow { }

        // the queue sits above the player in the bottom corners, below it in the top ones
        Loader {
            id: queueLoader

            active: root.queueOpen
            anchors.left: parent.left
            anchors.right: parent.right
            y: root._top ? root.playerHeight : 0
            height: root.queueHeight

            sourceComponent: RdMiniQueue { }
        }

        Item {
            id: player

            anchors.left: parent.left
            anchors.right: parent.right
            y: root._top || !root.queueOpen ? 0 : root.queueHeight
            height: root.playerHeight

            Rectangle {
                id: picture

                x: VLCStyle.dp(8)
                y: VLCStyle.dp(8)
                width: parent.width - VLCStyle.dp(16)
                height: VLCStyle.dp(211)
                radius: VLCStyle.rd_radius_normal
                color: VLCStyle.palette.rdBgB2
                border.width: VLCStyle.dp(2)
                border.color: VLCStyle.palette.rdBgB2
                clip: true

                VideoSurface {
                    anchors.fill: parent
                    anchors.margins: parent.border.width
                    visible: Player.hasVideoOutput && MainCtx.hasEmbededVideo
                    videoSurfaceProvider: MainCtx.videoSurfaceProvider
                }

                // songs show their cover
                Image {
                    anchors.fill: parent
                    anchors.margins: parent.border.width
                    visible: !Player.hasVideoOutput && status === Image.Ready
                    source: Player.artwork
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(width * 2, height * 2)
                }

                HoverHandler {
                    id: pictureHover
                }

                // drag the card by its picture; it snaps to the nearest corner
                DragHandler {
                    id: dragHandler

                    target: root
                    cursorShape: Qt.DragMoveCursor

                    onActiveChanged: {
                        if (active || !root.parent)
                            return
                        const left = root.x + root.width / 2 < root.parent.width / 2
                        const top = root.y + root.height / 2 < root.parent.height / 2
                        root.corner = (top ? "top" : "bottom") + (left ? "Left" : "Right")
                        // back to the corner bindings, animated by the Behaviors
                        root.x = Qt.binding(() => root._left ? root.margin : root.parent.width - root.width - root.margin)
                        root.y = Qt.binding(() => root._top ? root.margin : root.parent.height - root.height - root.margin)
                    }
                }

                // hover overlay (IB-18): dimmed picture, white controls
                Rectangle {
                    anchors.fill: parent
                    visible: pictureHover.hovered || closeButton.hovered || openButton.hovered
                    color: VLCStyle.palette.rdBgB2Transparent
                    radius: parent.radius

                    OverlayButton {
                        id: closeButton

                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: VLCStyle.dp(14)
                        iconName: "close"
                        description: qsTr("Close")
                        onClicked: MainPlaylistController.stop()
                    }

                    OverlayButton {
                        id: openButton

                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: VLCStyle.dp(14)
                        iconName: "open"
                        description: qsTr("Open the player")
                        onClicked: MainCtx.playerView = true
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: VLCStyle.dp(40)

                        OverlayButton {
                            iconName: "previous"
                            description: qsTr("Previous")
                            onClicked: MainPlaylistController.prev()
                        }

                        OverlayButton {
                            iconName: root._ended ? "replay"
                                    : Player.playingState === Player.PLAYING_STATE_PLAYING ? "pause" : "play"
                            description: Player.playingState === Player.PLAYING_STATE_PLAYING ? qsTr("Pause") : qsTr("Play")
                            onClicked: MainPlaylistController.togglePlayPause()
                        }

                        OverlayButton {
                            iconName: "next"
                            description: qsTr("Next")
                            onClicked: MainPlaylistController.next()
                        }
                    }
                }
            }

            // seek bar (Figma 375x16, fill 12 px, accent playhead pill)
            Rectangle {
                id: seek

                anchors.left: picture.left
                anchors.right: picture.right
                anchors.top: picture.bottom
                anchors.topMargin: VLCStyle.dp(6)
                height: VLCStyle.dp(16)
                radius: VLCStyle.rd_radius_normal
                color: VLCStyle.palette.rdBgB2

                Rectangle {
                    x: VLCStyle.dp(2)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, (parent.width - VLCStyle.dp(4)) * Player.position)
                    height: VLCStyle.dp(12)
                    radius: VLCStyle.rd_radius_small
                    color: VLCStyle.palette.rdBgAccentBright
                }

                Rectangle {
                    visible: seekArea.containsMouse || pictureHover.hovered
                    x: Math.max(0, (parent.width - width) * Player.position)
                    anchors.verticalCenter: parent.verticalCenter
                    width: VLCStyle.dp(8)
                    height: VLCStyle.dp(16)
                    radius: VLCStyle.rd_radius_small
                    color: VLCStyle.palette.rdAccentMain
                }

                MouseArea {
                    id: seekArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: (mouse) => Player.position = Math.max(0, Math.min(1, mouse.x / width))
                    onPositionChanged: (mouse) => {
                        if (pressed)
                            Player.position = Math.max(0, Math.min(1, mouse.x / width))
                    }
                }
            }

            Text {
                id: titleText

                anchors.left: picture.left
                anchors.leftMargin: VLCStyle.dp(8)
                anchors.right: picture.right
                anchors.top: seek.bottom
                anchors.topMargin: VLCStyle.dp(16)
                elide: Text.ElideRight
                text: root.fileName
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_header
                color: VLCStyle.palette.rdFgA2
            }

            Row {
                anchors.left: titleText.left
                anchors.top: titleText.bottom
                anchors.topMargin: VLCStyle.dp(14)
                spacing: VLCStyle.dp(20)

                Chip {
                    visible: root.folderName !== ""
                    iconName: "folder"
                    text: root.folderName
                    onClicked: root.folderClicked()
                }

                Chip {
                    visible: !Player.hasVideoOutput && Player.artist !== ""
                    iconName: "artist"
                    text: Player.artist
                    enabled: false
                }
            }

            OverlayButton {
                anchors.right: picture.right
                anchors.rightMargin: VLCStyle.dp(4)
                anchors.verticalCenter: titleText.bottom
                anchors.verticalCenterOffset: VLCStyle.dp(26)
                iconName: "lists"
                description: qsTr("Queue")
                iconColor: root.queueOpen ? VLCStyle.palette.rdAccentMain
                                          : (hovered ? VLCStyle.palette.rdFgA1 : VLCStyle.palette.rdFgA2)
                onClicked: root.queueOpen = !root.queueOpen
            }
        }
    }

    component OverlayButton: T.AbstractButton {
        id: overlayButton

        property string iconName: ""
        property string description: ""
        property color iconColor: VLCStyle.palette.rdFg1

        implicitWidth: VLCStyle.rd_iconButtonWidth
        implicitHeight: VLCStyle.rd_iconButtonHeight
        hoverEnabled: true

        Accessible.role: Accessible.Button
        Accessible.name: description

        T.ToolTip.visible: hovered && description !== ""
        T.ToolTip.delay: VLCStyle.delayToolTipAppear
        T.ToolTip.text: description

        contentItem: Item {
            Widgets.RdIcon {
                anchors.centerIn: parent
                name: overlayButton.iconName
                color: overlayButton.iconColor
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            cursorShape: Qt.PointingHandCursor
        }
    }

    component Chip: T.AbstractButton {
        id: chip

        property string iconName: ""

        implicitHeight: VLCStyle.dp(28)
        implicitWidth: chipRow.implicitWidth
        hoverEnabled: true

        Accessible.role: Accessible.Button
        Accessible.name: text

        contentItem: Row {
            id: chipRow

            spacing: VLCStyle.dp(8)

            Widgets.RdIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: chip.iconName
                color: chip.hovered && chip.enabled ? VLCStyle.palette.rdFg2 : VLCStyle.palette.rdFgA2
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.text
                width: Math.min(implicitWidth, VLCStyle.dp(130))
                elide: Text.ElideRight
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_header
                color: chip.hovered && chip.enabled ? VLCStyle.palette.rdFg2 : VLCStyle.palette.rdFgA2
            }
        }
    }
}
