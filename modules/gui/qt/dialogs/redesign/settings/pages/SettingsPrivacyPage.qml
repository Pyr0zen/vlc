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
// redesign: Settings > Privacy ("Privacy Settings", video 17:52-17:55, Figma "Settings - privacy");
// rows: P8-07. "What VLC needs to remember about history or network." No Advanced Options
// (the video and Figma show none).
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Dialogs

SettingsPage {
    id: root

    readonly property int _restore: Number(RdEffects.values[RdEffects.optionKey("restore-playback-pos")] ?? 0)
    readonly property bool _scrobbler: scrobblerRow.checked

    SettingsSection {
        title: qsTr("History")

        SettingsOption {
            option: "save-recentplay"
            text: qsTr("Save recently played items")
        }

        // VLC's choice is Never / Ask / Always (Settings > Playback "Continue where you left
        // off"); here ON is "Always"
        SettingsRow {
            text: qsTr("Remember the playback position")
            description: RdEffects.optionDescription("restore-playback-pos")
            keywords: "restore-playback-pos resume continue"

            Widgets.RdToggle {
                checked: root._restore !== 0
                Accessible.name: qsTr("Remember the playback position")
                onToggled: RdEffects.setOption("restore-playback-pos", checked ? 2 : 0)
            }
        }

        SettingsRow {
            text: qsTr("Clear history now")
            description: qsTr("Forgets every file and stream played so far: the Recent list of the library and the positions to continue from.")
            keywords: "recent history clear forget"
            available: MainCtx.mediaLibraryAvailable

            Widgets.RdButton {
                text: qsTr("Clear")
                onClicked: {
                    if (DialogsProvider.questionDialog(qsTr("Forget everything you played?"), qsTr("Clear history")))
                        SettingsCatalog.clearHistory()
                }
            }
        }
    }

    SettingsSection {
        title: qsTr("Network")

        SettingsOption {
            option: "metadata-network-access"
            text: qsTr("Fetch titles and cover art from the internet")
        }

        SettingsOption {
            option: "qt-privacy-ask"
            text: qsTr("Ask about internet access when VLC starts")
        }

        SettingsInterfaceToggle {
            id: scrobblerRow

            module: "audioscrobbler"
            text: qsTr("Submit played tracks to last.fm")
            description: qsTr("Sends the titles of the songs you play to your last.fm profile. VLC uses this setting the next time it starts.")
            shown: SettingsCatalog.exists("lastfm-username")
        }

        SettingsOption {
            option: "lastfm-username"
            text: qsTr("Last.fm username")
            available: root._scrobbler
        }

        SettingsOption {
            option: "lastfm-password"
            text: qsTr("Last.fm password")
            kind: "password"
            available: root._scrobbler
        }

        SettingsOption {
            option: "scrobbler-url"
            text: qsTr("Last.fm submission URL")
            available: root._scrobbler
        }
    }
}
