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
// redesign: a preferred track language ("audio-language", "sub-language", "menu-language") as a
// list of language names instead of VLC's ISO code field (Figma "Settings - subtitles",
// "Settings - audio", "Settings - playback": "System language", "English"). VLC matches the
// two-letter ISO 639-1 codes written here against the tracks' languages. A list VLC got
// elsewhere ("eng,fre") stays shown and selected as it is.
import QtQuick

import VLC.MainInterface
import VLC.Style

SettingsOption {
    id: root

    readonly property string _systemCode: Qt.locale().name.split(/[_-]/)[0]

    readonly property var _languages: [
        { value: "en", text: qsTr("English") },
        { value: "ar", text: qsTr("Arabic") },
        { value: "bg", text: qsTr("Bulgarian") },
        { value: "ca", text: qsTr("Catalan") },
        { value: "zh", text: qsTr("Chinese") },
        { value: "hr", text: qsTr("Croatian") },
        { value: "cs", text: qsTr("Czech") },
        { value: "da", text: qsTr("Danish") },
        { value: "nl", text: qsTr("Dutch") },
        { value: "et", text: qsTr("Estonian") },
        { value: "fi", text: qsTr("Finnish") },
        { value: "fr", text: qsTr("French") },
        { value: "de", text: qsTr("German") },
        { value: "el", text: qsTr("Greek") },
        { value: "he", text: qsTr("Hebrew") },
        { value: "hi", text: qsTr("Hindi") },
        { value: "hu", text: qsTr("Hungarian") },
        { value: "is", text: qsTr("Icelandic") },
        { value: "id", text: qsTr("Indonesian") },
        { value: "it", text: qsTr("Italian") },
        { value: "ja", text: qsTr("Japanese") },
        { value: "ko", text: qsTr("Korean") },
        { value: "lv", text: qsTr("Latvian") },
        { value: "lt", text: qsTr("Lithuanian") },
        { value: "ms", text: qsTr("Malay") },
        { value: "no", text: qsTr("Norwegian") },
        { value: "fa", text: qsTr("Persian") },
        { value: "pl", text: qsTr("Polish") },
        { value: "pt", text: qsTr("Portuguese") },
        { value: "ro", text: qsTr("Romanian") },
        { value: "ru", text: qsTr("Russian") },
        { value: "sr", text: qsTr("Serbian") },
        { value: "sk", text: qsTr("Slovak") },
        { value: "sl", text: qsTr("Slovenian") },
        { value: "es", text: qsTr("Spanish") },
        { value: "sv", text: qsTr("Swedish") },
        { value: "th", text: qsTr("Thai") },
        { value: "tr", text: qsTr("Turkish") },
        { value: "uk", text: qsTr("Ukrainian") },
        { value: "vi", text: qsTr("Vietnamese") }
    ]

    kind: "dropdown"
    // the system's language is listed once, as "System language (English)"
    choices: {
        const system = _languages.find((l) => l.value === _systemCode)
        return [{ value: "", text: qsTr("Automatic") },
                { value: _systemCode, text: system ? qsTr("System language (%1)").arg(system.text) : qsTr("System language") }]
               .concat(_languages.filter((l) => l.value !== _systemCode))
    }
}
