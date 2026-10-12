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

// Redesign slider (video 7:20-9:10, settings pages): near-black pill track, dark accent fill,
// accent vertical-pill thumb slightly taller than the track.
// - plain: fill from the left
// - bipolar: fill from the zero point to the thumb (subtitle / audio delay)
// - stepped: tick marks at each step (speed, font size, outline thickness)
// Optional labels are drawn under the track, spread evenly from left to right.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style

T.Slider {
    id: control

    property bool bipolar: false
    property real zeroValue: 0
    property bool showTicks: stepSize > 0 && (to - from) / stepSize <= 40
    property var labels: []

    readonly property SystemPalette rdPalette: VLCStyle.palette

    implicitWidth: VLCStyle.dp(360)
    implicitHeight: labelRow.visible ? VLCStyle.dp(40) : VLCStyle.dp(24)

    focusPolicy: Qt.StrongFocus

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    readonly property real _trackY: VLCStyle.dp(12) - track.height / 2

    function _pos(v) {
        return (to === from) ? 0 : (v - from) / (to - from)
    }

    background: Item {
        Rectangle {
            id: track

            x: 0
            y: control._trackY
            width: control.availableWidth
            height: VLCStyle.dp(10)
            radius: height / 2
            color: control.rdPalette.rdBgB2

            Rectangle {
                id: fill

                readonly property real zeroX: control.bipolar ? control._pos(control.zeroValue) * track.width : 0
                readonly property real thumbX: control.visualPosition * track.width

                x: Math.min(zeroX, thumbX)
                width: Math.abs(thumbX - zeroX)
                height: parent.height
                radius: parent.radius
                color: control.rdPalette.rdBgAccentBright
            }

            Repeater {
                model: control.showTicks ? Math.round((control.to - control.from) / control.stepSize) + 1 : 0

                delegate: Rectangle {
                    required property int index
                    readonly property int count: Math.round((control.to - control.from) / control.stepSize)

                    x: count > 0 ? index * (track.width - width) / count : 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: VLCStyle.dp(1)
                    height: VLCStyle.dp(4)
                    color: x < fill.x + fill.width && x >= fill.x ? control.rdPalette.rdAccentDim
                                                                   : control.rdPalette.rdFgA4
                }
            }
        }

        Row {
            id: labelRow

            visible: control.labels.length > 0
            y: VLCStyle.dp(24)
            width: control.availableWidth

            Repeater {
                model: control.labels

                delegate: Text {
                    required property int index
                    required property var modelData

                    width: labelRow.width / Math.max(1, control.labels.length)
                    horizontalAlignment: index === 0 ? Text.AlignLeft
                                        : (index === control.labels.length - 1 ? Text.AlignRight : Text.AlignHCenter)
                    text: modelData
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_toggle
                    color: control.rdPalette.rdFgA3
                }
            }
        }
    }

    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: VLCStyle.dp(12) - height / 2
        width: VLCStyle.dp(8)
        height: VLCStyle.dp(18)
        radius: VLCStyle.rd_radius_small
        color: control.pressed ? control.rdPalette.rdAccentBright : control.rdPalette.rdAccentMain
    }
}
