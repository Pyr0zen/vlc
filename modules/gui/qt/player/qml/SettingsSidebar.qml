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
import VLC.Widgets as Widgets

RdSidePanel {
    id: root

    tabs: [
        { key: "playback", label: qsTr("Playback"), icon: "playback", width: 108 },
        { key: "videoSettings", label: qsTr("Video"), icon: "video", width: 85 },
        { key: "audioSettings", label: qsTr("Audio"), icon: "audio", width: 85 },
        { key: "subtitleSettings", label: qsTr("Subtitles"), icon: "subtitles", width: 108 }
    ]
    currentKey: RdPanels.settingsOpen ? RdPanels.current : "playback"
    onTabClicked: (key) => RdPanels.open(key)

    PlaybackSettingsPage { }
    VideoSettingsPage { }
    AudioSettingsPage { }
    SubtitleSettingsPage { }

    // Figma "Button": 360x32, BG/B2, 20 px gear, FG/A3 text
    footer: Widgets.RdButton {
        width: root.width - 2 * VLCStyle.dp(20)
        style: Widgets.RdButton.Style.Bar
        rdIcon: "settings"
        text: qsTr("Open Advanced Settings")
        onClicked: {
            RdPanels.close()
            DialogsProvider.prefsDialog()
        }
    }
}
