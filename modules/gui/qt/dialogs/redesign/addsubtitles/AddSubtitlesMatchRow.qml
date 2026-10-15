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

// redesign (Add Subtitles "To This Folder" / "To This Playlist", W6.5, P3-08 / P3-09): a video
// and the subtitle matched to it (Figma "Add Subtitles to Playlist/Folder" 1911:7545, 40 px a
// row):
// - left column (519 of 1048, padding left 30): video icon FG/A3, 14 px, name Inter 14 FG/A1,
//   14 px, then a 1 px dashed line (Divider/Bright, dashes 8 / 8) to the column's end; the row is
//   24 px, 8 px below the top of the 40;
// - right column (padding 20): the match (Figma "subtitle multiple" 1915:8397: 36 px, radius 6,
//   padding 0,8, subtitle icon FG/A3, name FG/A1). Hovering shows BG/B2 and the swap icon
//   (FG/A2) at the right; a click opens the list to match another subtitle by hand (video
//   6:16-6:22). A video without a match says so in the placeholder color.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

T.ItemDelegate {
    id: root

    property string videoName: ""
    property string subtitleName: ""
    property bool matched: false

    // the match was clicked: the list of subtitles opens over `anchor`
    signal chooseRequested(Item anchor)

    // the match, where the list of subtitles opens
    readonly property Item matchItem: match

    readonly property SystemPalette rdPalette: VLCStyle.palette
    readonly property real _scale: width / VLCStyle.dp(1048)
    readonly property real _leftWidth: Math.round(VLCStyle.dp(519) * _scale)

    implicitHeight: VLCStyle.dp(40)
    padding: 0
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus

    Accessible.role: Accessible.ListItem
    Accessible.name: matched ? qsTr("%1, subtitles: %2").arg(videoName).arg(subtitleName)
                             : qsTr("%1, no subtitles").arg(videoName)
    Accessible.onPressAction: root.chooseRequested(match)

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            event.accepted = true
            root.chooseRequested(match)
        }
    }

    background: null

    contentItem: Item {
        // ---------------------------------------------------------------- video
        Item {
            id: video

            x: VLCStyle.dp(30)
            y: VLCStyle.dp(8)
            width: root._leftWidth - x
            height: VLCStyle.dp(24)

            Widgets.RdIcon {
                id: videoIcon

                anchors.verticalCenter: parent.verticalCenter
                name: "video"
                color: root.rdPalette.rdFgA3
            }

            Text {
                id: videoText

                anchors.left: videoIcon.right
                anchors.leftMargin: VLCStyle.dp(14)
                anchors.verticalCenter: parent.verticalCenter
                // the dashes keep at least a few dashes of room
                width: Math.min(implicitWidth, video.width - x - VLCStyle.dp(14 + 48))

                text: root.videoName
                elide: Text.ElideMiddle
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: root.rdPalette.rdFgA1
            }

            // Figma "Vector 77": 1 px Divider/Bright, dashes [8, 8] (VLC's Qt has no Shapes)
            Item {
                id: leader

                anchors.left: videoText.right
                anchors.leftMargin: VLCStyle.dp(14)
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: VLCStyle.dp(1)
                clip: true

                Repeater {
                    model: Math.max(0, Math.ceil(leader.width / VLCStyle.dp(16)))

                    Rectangle {
                        required property int index

                        x: index * VLCStyle.dp(16)
                        width: VLCStyle.dp(8)
                        height: leader.height
                        color: root.rdPalette.rdDividerBright
                    }
                }
            }
        }

        // ---------------------------------------------------------------- match
        Rectangle {
            id: match

            // keyboard focus: the list's current row while the list has it
            readonly property bool focused: root.visualFocus || root.highlighted
            readonly property bool active: matchMouse.containsMouse || focused

            x: root._leftWidth + VLCStyle.dp(20)
            width: root.width - x - VLCStyle.dp(20)
            height: VLCStyle.dp(36)

            radius: VLCStyle.rd_radius_normal
            color: active ? root.rdPalette.rdBgB2 : "transparent"
            border.width: focused ? VLCStyle.dp(1) : 0
            border.color: root.rdPalette.rdFgA3

            Widgets.RdIcon {
                id: subtitleIcon

                anchors.left: parent.left
                anchors.leftMargin: VLCStyle.dp(8)
                anchors.verticalCenter: parent.verticalCenter
                name: "subtitle"
                color: root.matched ? root.rdPalette.rdFgA3 : root.rdPalette.rdFgA4
            }

            Text {
                anchors.left: subtitleIcon.right
                anchors.leftMargin: VLCStyle.dp(14)
                anchors.right: swapIcon.left
                anchors.rightMargin: VLCStyle.dp(16)
                anchors.verticalCenter: parent.verticalCenter

                text: root.matched ? root.subtitleName : qsTr("No subtitles found")
                elide: Text.ElideMiddle
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: root.matched ? root.rdPalette.rdFgA1 : root.rdPalette.rdFgA4
            }

            Widgets.RdIcon {
                id: swapIcon

                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.dp(8)
                anchors.verticalCenter: parent.verticalCenter
                visible: match.active
                name: "swap"
                color: root.rdPalette.rdFgA2
            }

            MouseArea {
                id: matchMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.forceActiveFocus(Qt.MouseFocusReason)
                    root.chooseRequested(match)
                }
            }
        }
    }
}
