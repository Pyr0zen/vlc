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
    // tick marks every tickStep (the step by default; a percentage slider moving by 1 marks
    // every 10, Figma "Text opacity")
    property real tickStep: stepSize
    property bool showTicks: tickStep > 0 && (to - from) / tickStep <= 40
    // labels under the track, spread from the left end to the right end (Figma "Frame 205")
    property var labels: []
    // Figma "wrapper" auto layout: the track 4 px down (8 in the Settings rows whose slider is
    // wrapped twice), then the gap to the labels (10; 8 in some Settings rows)
    property real trackTop: VLCStyle.dp(4)
    property real labelSpacing: VLCStyle.dp(10)

    readonly property SystemPalette rdPalette: VLCStyle.palette

    // Figma "wrapper": the 16 px track (the 24 px thumb overflows it by 4), the gap, the 15 px
    // label row, 4 px below (360x49 in the sidebar)
    implicitWidth: VLCStyle.dp(360)
    implicitHeight: labelRow.visible ? labelRow.y + labelRow.height + VLCStyle.dp(4)
                                     : trackTop + VLCStyle.dp(16) + VLCStyle.dp(4)

    focusPolicy: Qt.StrongFocus

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    readonly property real _inset: VLCStyle.dp(2)

    // Figma draws the marks in BG/Accent Dark with the "screen" blend mode: the color it gives
    // over each background (QML has no blend modes)
    function _screen(c, bg) {
        return Qt.rgba(c.r + bg.r - c.r * bg.r, c.g + bg.g - c.g * bg.g, c.b + bg.b - c.b * bg.b, 1)
    }
    readonly property color _tickOnTrack: _screen(rdPalette.rdBgAccentDark, rdPalette.rdBgB2)
    readonly property color _tickOnFill: _screen(rdPalette.rdBgAccentDark, rdPalette.rdBgAccentBright)

    function _pos(v) {
        return (to === from) ? 0 : (v - from) / (to - from)
    }

    background: Item {
        // Figma "range": 16 px, radius 6, BG/B2, 2 px padding around a 12 px fill (radius 4)
        Rectangle {
            id: track

            y: control.trackTop
            width: control.availableWidth
            height: VLCStyle.dp(16)
            radius: VLCStyle.rd_radius_normal
            color: control.rdPalette.rdBgB2

            Rectangle {
                id: fill

                readonly property real span: track.width - 2 * control._inset
                readonly property real zeroX: control.bipolar ? control._pos(control.zeroValue) * span : 0
                readonly property real thumbX: control.visualPosition * span

                x: control._inset + Math.min(zeroX, thumbX)
                y: control._inset
                width: Math.max(control.bipolar ? 0 : VLCStyle.dp(8), Math.abs(thumbX - zeroX))
                height: track.height - 2 * control._inset
                radius: VLCStyle.rd_radius_small
                color: control.rdPalette.rdBgAccentBright
            }

            // Figma "degrees": the marks between the ends (its first and last are hidden)
            Repeater {
                id: ticks

                readonly property int segments: control.showTicks ? Math.round((control.to - control.from) / control.tickStep) : 0

                model: Math.max(0, segments - 1)

                delegate: Rectangle {
                    required property int index

                    x: control._inset + (index + 1) * (fill.span - width) / ticks.segments
                    anchors.verticalCenter: parent.verticalCenter
                    // Figma "degrees": 6 px lines stroked 2 px with round caps (2 x 8 drawn),
                    // BG/Accent Dark screened over the track or the fill (dark: #221E19 / #4B3217)
                    width: VLCStyle.dp(2)
                    height: VLCStyle.dp(8)
                    radius: width / 2
                    color: (x >= fill.x && x < fill.x + fill.width) ? control._tickOnFill : control._tickOnTrack
                }
            }
        }

        Item {
            id: labelRow

            visible: control.labels.length > 0
            y: control.trackTop + VLCStyle.dp(16) + control.labelSpacing
            width: control.availableWidth
            height: VLCStyle.dp(15)

            Repeater {
                model: control.labels

                delegate: Text {
                    required property int index
                    required property var modelData

                    readonly property real center: control.labels.length > 1
                                                   ? index * labelRow.width / (control.labels.length - 1)
                                                   : labelRow.width / 2

                    x: Math.max(0, Math.min(labelRow.width - width, center - width / 2))
                    text: modelData
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_toggle
                    color: control.rdPalette.rdFgA3
                }
            }
        }
    }

    // Figma "thumb": 8x24, radius 4, Accent/DIm (accent while hovered or pressed)
    handle: Rectangle {
        x: control.leftPadding + control._inset + control.visualPosition * (control.availableWidth - 2 * control._inset - width)
        y: control.trackTop - VLCStyle.dp(4)
        width: VLCStyle.dp(8)
        height: VLCStyle.dp(24)
        radius: VLCStyle.rd_radius_small
        color: (control.pressed || control.hovered || control.visualFocus) ? control.rdPalette.rdAccentMain
                                                                           : control.rdPalette.rdAccentDim
    }
}
