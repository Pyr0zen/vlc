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

// redesign: settings sidebar, Playback tab (video 9:06-9:19 final version; Figma "playback").
// Step 1 has the rows VLC already supports: Audio Visualizer and Speed. Show Subtitle Timeline,
// Show Waveform, Show Metadata, Show Statistics, Reverse and Sleep Timer are new features
// (BUILD_PLAN.md W4.3b) and are added above them in the video's order.
import QtQuick
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets

RdSidePanelPage {
    id: root

    key: "playback"

    function rateText(rate) {
        return qsTr("%1x").arg(Math.round(rate * 100) / 100)
    }

    Widgets.RdSettingsSection {
        showDivider: false

        Widgets.RdSettingRow {
            text: qsTr("Audio Visualizer")
            rowHeight: VLCStyle.dp(58)

            Widgets.RdChoiceDropdown {
                implicitWidth: VLCStyle.dp(220)
                choices: Player.audioVisualization
                Accessible.name: qsTr("Audio Visualizer")
            }
        }

        // the video's speed slider: 0.25 to 2 in 0.25 steps with a label under each step;
        // the value box also takes VLC's other speeds (up to 4x)
        Widgets.RdParamSlider {
            text: qsTr("Speed")
            valueBox: true
            valueText: root.rateText(Player.rate)
            from: 0.25
            to: 2
            stepSize: 0.25
            labels: ["0.25", "0.5", "0.75", "1", "1.25", "1.5", "1.75", "2"]
            value: Player.rate
            enabled: Player.ratechangable
            onMoved: (v) => Player.rate = v
            onEdited: (text) => {
                const r = parseFloat(String(text).replace(",", ".").replace(/[^0-9.]/g, ""))
                if (!isNaN(r))
                    Player.rate = Math.max(0.25, Math.min(4, r))
            }
        }
    }
}
