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

// redesign (W6.5, P3-07): Settings > Subtitles, the OpenSubtitles account behind the Add
// Subtitles dialog's "From OpenSubtitles" source (Decision 21: Figma has no such rows; built like
// the page's text rows, "Settings - subtitles"). The source stays off until an API key is entered;
// the username and password are optional and raise the daily download quota.
// Kept by AddSubtitles in the interface's settings, applied when a field is left.
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Dialogs

SettingsSection {
    id: root

    title: qsTr("OpenSubtitles")
    keywords: qsTr("opensubtitles api key account download subtitles online")

    component AccountField: Widgets.RdTextField {
        implicitWidth: VLCStyle.dp(320)
        implicitHeight: VLCStyle.dp(36)
    }

    SettingsRow {
        text: qsTr("API key")
        description: qsTr("Searching and downloading subtitles from OpenSubtitles.com needs an API key. Create a free account on opensubtitles.com, then add an API consumer in your profile to get one. Without a key, the OpenSubtitles source of Add Subtitles stays off.")
        keywords: "opensubtitles api key"

        AccountField {
            text: AddSubtitles.apiKey
            placeholderText: qsTr("Enter your API key")
            echoMode: TextInput.Password
            Accessible.name: qsTr("OpenSubtitles API key")
            onEditingFinished: AddSubtitles.apiKey = text.trim()
        }
    }

    SettingsRow {
        text: qsTr("Username")
        description: qsTr("Optional. Signing in to your OpenSubtitles account allows more downloads a day than the API key alone.")
        keywords: "opensubtitles account user login"
        available: AddSubtitles.openSubtitlesEnabled

        AccountField {
            text: AddSubtitles.username
            placeholderText: qsTr("Optional")
            Accessible.name: qsTr("OpenSubtitles username")
            onEditingFinished: AddSubtitles.username = text.trim()
        }
    }

    SettingsRow {
        text: qsTr("Password")
        description: qsTr("Optional. Kept on this computer with the interface settings.")
        keywords: "opensubtitles account password login"
        available: AddSubtitles.openSubtitlesEnabled

        AccountField {
            text: AddSubtitles.password
            placeholderText: qsTr("Optional")
            echoMode: TextInput.Password
            Accessible.name: qsTr("OpenSubtitles password")
            onEditingFinished: AddSubtitles.password = text
        }
    }
}
