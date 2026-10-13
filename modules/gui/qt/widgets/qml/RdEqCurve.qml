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

// Redesign equalizer preset preview (video 8:51-8:56, IA-40 / P4-26): about 24x12, a gray
// baseline with accent shapes above it for boosted bands and below it for cut bands.
// Canvas is not available in VLC's Qt build, so each band is a small bar.
import QtQuick

import VLC.MainInterface
import VLC.Style

Item {
    id: root

    // gains in dB (-20 to +20) of the preset's bands
    property var bands: []

    implicitWidth: VLCStyle.dp(24)
    implicitHeight: VLCStyle.dp(12)

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: VLCStyle.dp(1)
        color: VLCStyle.palette.rdFgA3
    }

    Repeater {
        model: root.bands

        delegate: Rectangle {
            required property int index
            required property var modelData

            readonly property real gain: Number(modelData)
            readonly property real barHeight: Math.min(1, Math.abs(gain) / 12) * root.height / 2

            visible: barHeight >= 0.5
            x: index * root.width / Math.max(1, root.bands.length)
            width: root.width / Math.max(1, root.bands.length)
            height: barHeight
            y: gain >= 0 ? root.height / 2 - barHeight : root.height / 2
            color: VLCStyle.palette.rdAccentMain
        }
    }
}
