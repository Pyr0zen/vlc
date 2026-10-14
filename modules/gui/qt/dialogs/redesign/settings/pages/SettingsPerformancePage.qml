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

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Dialogs

SettingsPage {
    id: root

    function _option(name) {
        return RdEffects.values[RdEffects.optionKey(name)]
    }

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

        // VLC's "hw-dec" turns hardware decoding on, "dec-dev" picks the device: Automatic,
        // a device, or Off in one list (Figma: one dropdown, "Automatic")
        SettingsRow {
            text: qsTr("Hardware-accelerated decoding")
            description: RdEffects.optionDescription("hw-dec")
            keywords: "hw-dec dec-dev hardware gpu dxva d3d11"
            shown: SettingsCatalog.exists("hw-dec")

            Widgets.RdDropdown {
                readonly property bool _enabled: root._option("hw-dec") !== false
                readonly property string _device: String(root._option("dec-dev") ?? "any")
                readonly property var entries: {
                    const list = [{ device: "any", text: qsTr("Automatic") }]
                    for (const c of RdEffects.optionChoices("dec-dev")) {
                        if (c.value !== "any" && c.value !== "none" && c.value !== "")
                            list.push({ device: c.value, text: c.text })
                    }
                    list.push({ device: "", text: qsTr("Off") })
                    return list
                }

                implicitWidth: VLCStyle.dp(320)
                implicitHeight: VLCStyle.dp(36)
                model: entries.map((e) => e.text)
                // "none" (VLC's own Disable) is off too
                currentIndex: !_enabled || _device === "none" ? entries.length - 1
                                                              : Math.max(0, entries.findIndex((e) => e.device === _device))
                Accessible.name: qsTr("Hardware-accelerated decoding")
                onActivated: (index) => {
                    const device = entries[index].device
                    RdEffects.setOption("hw-dec", device !== "")
                    if (device !== "")
                        RdEffects.setOption("dec-dev", device)
                }
            }
        }

        // the quality is read by VLC's post-processing filter, which runs while it is in the
        // video filters: Off takes it out
        SettingsRow {
            text: qsTr("Video post-processing")
            description: RdEffects.optionDescription("postproc-q")
            keywords: "postproc-q postproc post-processing"
            shown: SettingsCatalog.exists("postproc-q")

            Widgets.RdDropdown {
                // only asked when the filter exists (VLC logs a missing filter module)
                readonly property bool _on: SettingsCatalog.exists("postproc-q")
                                            && RdEffects.values[RdEffects.videoFilterKey("postproc")] === true
                readonly property int _quality: Number(root._option("postproc-q") ?? 6)
                readonly property var levels: [qsTr("Off"), qsTr("Lowest"), qsTr("Low"), qsTr("Medium"),
                                               qsTr("High"), qsTr("Very high"), qsTr("Highest")]

                implicitWidth: VLCStyle.dp(320)
                implicitHeight: VLCStyle.dp(36)
                model: levels
                currentIndex: _on ? Math.max(1, Math.min(6, _quality)) : 0
                Accessible.name: qsTr("Video post-processing")
                onActivated: (index) => {
                    // also the running filter's quality
                    if (index > 0)
                        RdEffects.setVideoValue("postproc-q", index)
                    if (RdEffects.videoFilterEnabled("postproc") !== (index > 0))
                        RdEffects.setVideoFilterEnabled("postproc", index > 0)
                }
            }
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
