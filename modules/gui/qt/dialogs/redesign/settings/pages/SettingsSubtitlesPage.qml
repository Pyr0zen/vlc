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
// redesign: Settings > Subtitles ("Subtitle Defaults", video 18:09-18:14, Figma "Settings - subtitles"
// / "Settings - subtitles-1"); rows: BUILD_PLAN.md section 8, P8-12, P7-17.
// The "Loading Subtitles" section is the pattern for W6.2: real VLC options read and written
// through RdEffects (the same source as the settings sidebar, so both stay in sync), values in
// words instead of numbers (video 17:03-17:33), info popovers with VLC's explanation, a
// dependent row disabled while its parent setting is off (video 18:15, P8-14) and one setting
// under Advanced Options.
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Dialogs

SettingsPage {
    id: root

    // reading "revision" makes the bindings follow every change made through RdEffects
    readonly property bool _autodetect: (RdEffects.revision, RdEffects.option("sub-autodetect-file") === true)

    SettingsSection {
        title: qsTr("Loading Subtitles")

        SettingsRow {
            text: qsTr("Load subtitle files automatically")
            description: RdEffects.optionDescription("sub-autodetect-file")
            keywords: "sub-autodetect-file"

            Widgets.RdToggle {
                checked: root._autodetect
                Accessible.name: qsTr("Load subtitle files automatically")
                onToggled: RdEffects.setOption("sub-autodetect-file", checked)
            }
        }

        // VLC's explanation lists the numbers the video replaces with words, so this row
        // explains the choice itself
        SettingsRow {
            text: qsTr("File name matching")
            description: qsTr("How closely the name of a subtitle file has to match the name of the video for the subtitles to load automatically.")
            keywords: "sub-autodetect-fuzzy fuzziness"
            available: root._autodetect

            Widgets.RdDropdown {
                // sub-autodetect-fuzzy: 0 to 4, in the video's words (17:03-17:33)
                readonly property int fuzziness: (RdEffects.revision, Number(RdEffects.option("sub-autodetect-fuzzy")))

                implicitWidth: VLCStyle.dp(320)
                implicitHeight: VLCStyle.dp(36)
                model: [qsTr("Off"), qsTr("Any title"), qsTr("Contains title"),
                        qsTr("Title with extra characters"), qsTr("Exact title match")]
                currentIndex: Math.max(0, Math.min(4, fuzziness))
                Accessible.name: qsTr("File name matching")
                onActivated: (index) => RdEffects.setOption("sub-autodetect-fuzzy", index)
            }
        }
    }

    SettingsPlaceholder {
        text: qsTr("The other subtitle settings are moving here. Until then, they are in All VLC Settings.")
    }

    advanced: [
        SettingsSection {
            SettingsRow {
                text: qsTr("Also look for subtitles in")
                description: RdEffects.optionDescription("sub-autodetect-path")
                keywords: "sub-autodetect-path folders paths"
                available: root._autodetect

                Widgets.RdTextField {
                    readonly property string paths: (RdEffects.revision, String(RdEffects.option("sub-autodetect-path")))

                    implicitWidth: VLCStyle.dp(320)
                    implicitHeight: VLCStyle.dp(36)
                    text: paths
                    Accessible.name: qsTr("Also look for subtitles in")
                    onEditingFinished: {
                        if (text.trim() !== paths)
                            RdEffects.setOption("sub-autodetect-path", text.trim())
                    }
                }
            }
        }
    ]
}
