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

// redesign: settings sidebar opened by the gear (video 7:12-9:19, Decision 5; Figma
// "playback" / "video settings" / "audio settings" / "subtitle settings"). Tabs Playback, Video,
// Audio, Subtitles (108 / 85 / 85 / 108 px). The footer holds "Open Advanced Settings"; the
// per-show preset selector above it is a new feature (BUILD_PLAN.md W4.7).
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Dialogs
import VLC.Player
import VLC.Widgets as Widgets

RdSidePanel {
    id: root

    // Figma 5187:24312 / 2127:7749: the Playback tab shows the "state=selected" two-tone icon in
    // both states (main strokes FG/A2 when active); Video and Audio underlines are 70 wide
    // (498:2969, 536:1094)
    tabs: [
        { key: "playback", label: qsTr("Playback"), icon: "playback", width: 107.5, underline: 91.5,
          activeIcon: "playback_state-selected_two-tone-yes", inactiveIcon: "playback_state-selected_two-tone-yes",
          activeColor: VLCStyle.palette.rdFgA2 },
        { key: "videoSettings", label: qsTr("Video"), icon: "video", width: 85, underline: 70 },
        { key: "audioSettings", label: qsTr("Audio"), icon: "audio", width: 85, underline: 70 },
        { key: "subtitleSettings", label: qsTr("Subtitles"), icon: "subtitles", width: 107.5, underline: 91.5 }
    ]
    currentKey: RdPanels.settingsOpen ? RdPanels.current : "playback"
    onTabClicked: (key) => RdPanels.open(key)

    // each page is created when first needed (RdSidePanelPageLoader)
    RdSidePanelPageLoader {
        key: "playback"
        sourceComponent: PlaybackSettingsPage { }
    }

    RdSidePanelPageLoader {
        key: "videoSettings"
        sourceComponent: VideoSettingsPage { }
    }

    RdSidePanelPageLoader {
        key: "audioSettings"
        sourceComponent: AudioSettingsPage { }
    }

    RdSidePanelPageLoader {
        key: "subtitleSettings"
        sourceComponent: SubtitleSettingsPage { }
    }

    // Figma "playback" (5187:24308) has no footer; the other tabs keep "Frame 68" (812:1580)
    footerVisible: currentKey !== "playback"

    footer: [
        // Figma "Setting Preset" 2372:8834 (360x42) above the button, gap 10 (W4.7, Decision 18)
        PresetSelector {
            width: root.width - 2 * VLCStyle.dp(20)
        },
        // Figma "Button" 812:1585: 360x32 with its fill cleared (video 7:58: no button), 20 px gear,
        // FG/A3 text, FG/A2 on hover (Decision (Sticky) 43)
        Widgets.RdButton {
            width: root.width - 2 * VLCStyle.dp(20)
            style: Widgets.RdButton.Style.Link
            rdIcon: "settings"
            text: qsTr("Open Advanced Settings")
            // opens the Settings dialog on the matching category (Figma prototype, F-08)
            onClicked: {
                const category = ({ playback: "playback", videoSettings: "video",
                                    audioSettings: "audio", subtitleSettings: "subtitles" })[root.currentKey]
                RdPanels.close()
                DialogsProvider.settingsDialog(category || "")
            }
        }
    ]
}
