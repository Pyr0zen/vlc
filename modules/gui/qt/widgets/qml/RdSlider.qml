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
    // the setting's filter is off: Figma draws the slider in luminosity blend (614:1472), a gray
    // thumb and fill; moving it still works (and turns the filter on)
    property bool dimmed: false
    // intervals between the ticks (default: one per step)
    property int tickIntervals: stepSize > 0 ? Math.round((to - from) / stepSize) : 0
    // labels under the track, spread from the left end to the right end (Figma "Frame 205")
    property var labels: []
    // top of the label row: 10 px under the 16 px track (Figma "wrapper" 1905:7365: labels at
    // 30); the Speed slider's wrapper puts them 10 px under its 24 px zone (5187:24558: 34)
    property real labelsY: VLCStyle.dp(30)

    readonly property SystemPalette rdPalette: VLCStyle.palette

    // Figma "wrapper": 24 px slider zone, or the label row and a 4 px bottom padding
    implicitWidth: VLCStyle.dp(360)
    implicitHeight: labelRow.visible ? labelsY + labelRow.height + VLCStyle.dp(4) : VLCStyle.dp(24)

    focusPolicy: Qt.StrongFocus
    // disabled: Figma's 30 % rows ("Settings - library")
    opacity: enabled ? 1 : VLCStyle.rd_disabledRowOpacity

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    readonly property real _inset: VLCStyle.dp(2)

    function _pos(v) {
        return (to === from) ? 0 : (v - from) / (to - from)
    }

    background: Item {
        // Figma "range": 16 px, radius 6, BG/B2, 2 px padding around a 12 px fill (radius 4)
        Rectangle {
            id: track

            y: VLCStyle.dp(4)
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
                color: control.dimmed ? control.rdPalette.rdBgA1 : control.rdPalette.rdBgAccentBright
            }

            // Figma "degrees" (5187:24548, 848:1693): 2x6 ticks in BG/Accent Dark on the fill and
            // the track alike, spread over the fill span; the first and last are hidden
            Repeater {
                model: control.showTicks ? Math.max(0, control.tickIntervals - 1) : 0

                delegate: Rectangle {
                    required property int index
                    x: control._inset + (index + 1) * fill.span / control.tickIntervals - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: VLCStyle.dp(2)
                    height: VLCStyle.dp(6)
                    color: control.rdPalette.rdBgAccentDark
                }
            }
        }

        Item {
            id: labelRow

            visible: control.labels.length > 0
            y: control.labelsY
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
        y: 0
        width: VLCStyle.dp(8)
        height: VLCStyle.dp(24)
        radius: VLCStyle.rd_radius_small
        color: (control.pressed || control.hovered || control.visualFocus)
               ? (control.dimmed ? control.rdPalette.rdFgA2 : control.rdPalette.rdAccentMain)
               : (control.dimmed ? control.rdPalette.rdFgA3 : control.rdPalette.rdAccentDim)
    }
}
