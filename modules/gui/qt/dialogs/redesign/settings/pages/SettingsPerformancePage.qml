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
// redesign: Settings > Performance ("Performance Settings", video 18:20-18:22, Figma
// "Settings - performance"); rows: P8-16. Decoding and smooth playback first, VLC's clock
// settings under "Developer" in the Advanced Options.
import QtQuick

import VLC.Dialogs

SettingsPage {
    id: root

    // VLC tries the listed decoders first, then all the others ("codec" is not strict)
    readonly property var _decoderChoices: {
        const list = [{ value: "any", text: qsTr("Automatic") }]
        if (SettingsCatalog.exists("avcodec-threads"))
            list.push({ value: "avcodec", text: qsTr("FFmpeg") })
        if (SettingsCatalog.exists("dav1d-thread-frames"))
            list.push({ value: "dav1d", text: qsTr("dav1d (AV1)") })
        if (SettingsCatalog.exists("mft-debug"))
            list.push({ value: "mft", text: qsTr("Media Foundation") })
        return list
    }

    // 0 lets FFmpeg pick the number of threads
    readonly property var _threadChoices: {
        const list = [{ value: 0, text: qsTr("Automatic") }]
        for (let i = 1; i <= 16; ++i)
            list.push({ value: i, text: String(i) })
        return list
    }

    SettingsSection {
        title: qsTr("Decoding")

        SettingsOption {
            option: "dec-dev"
            text: qsTr("Hardware-accelerated decoding")
        }

        SettingsOption {
            option: "postproc-q"
            text: qsTr("Video post-processing")
            choices: [
                { value: 0, text: qsTr("Off") },
                { value: 1, text: qsTr("Lowest") },
                { value: 2, text: qsTr("Low") },
                { value: 3, text: qsTr("Medium") },
                { value: 4, text: qsTr("High") },
                { value: 5, text: qsTr("Very high") },
                { value: 6, text: qsTr("Highest") }
            ]
        }

        SettingsOption {
            option: "avcodec-skiploopfilter"
            text: qsTr("Skip the H.264 loop filter")
            choices: [
                { value: 0, text: qsTr("Never") },
                { value: 1, text: qsTr("For non-reference frames") },
                { value: 2, text: qsTr("For bidirectional frames") },
                { value: 3, text: qsTr("For non-key frames") },
                { value: 4, text: qsTr("Always") }
            ]
        }

        SettingsOption {
            option: "avcodec-threads"
            text: qsTr("Decoding threads")
            choices: root._threadChoices
        }
    }

    SettingsSection {
        title: qsTr("Smooth Playback")

        SettingsOption {
            option: "drop-late-frames"
            text: qsTr("Drop frames when the system can't keep up")
        }

        // Windows: VLC raises its process priority when it starts
        SettingsOption {
            option: "high-priority"
            text: qsTr("Give VLC high priority")
            restartRequired: true
        }
    }

    advanced: [
        SettingsSection {
            title: qsTr("Developer")

            SettingsOption {
                option: "codec"
                text: qsTr("Decoder")
                choices: root._decoderChoices
            }

            SettingsOption {
                option: "clock-synchro"
                text: qsTr("Clock synchronisation")
            }

            SettingsOption {
                option: "clock-jitter"
                text: qsTr("Clock jitter")
                unit: qsTr("ms")
            }

            SettingsOption {
                option: "cr-average"
                text: qsTr("Clock reference averaging")
            }

            SettingsOption {
                option: "clock-master"
                text: qsTr("Clock source")
                choices: [
                    { value: "auto", text: qsTr("Automatic") },
                    { value: "input", text: qsTr("Input (PCR)") },
                    { value: "audio", text: qsTr("Audio") },
                    { value: "monotonic", text: qsTr("System clock") }
                ]
            }
        },

        SettingsMoreOptions {
            category: "performance"
        }
    ]
}
