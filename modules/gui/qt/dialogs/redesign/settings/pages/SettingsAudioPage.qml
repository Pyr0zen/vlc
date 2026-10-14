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
// redesign: Settings > Audio ("Audio Defaults", video 18:06-18:08 and 20:33-20:36, Figma
// "Settings - audio" / "Settings - audio-1"); rows: P8-11, P8-44. The effects are the settings
// sidebar's (RdEffects): they apply to what plays and are kept.
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

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

    function _filterOn(module) {
        return RdEffects.values[RdEffects.audioFilterKey(module)] === true
    }

    readonly property string _aout: String(_option("aout") ?? "")
    // the device and start volume options of the output in use (VLC's preferences do the same)
    readonly property string _deviceOption: _aout === "directsound" ? "directx-audio-device"
                                          : _aout === "waveout" ? "waveout-audio-device"
                                          : "mmdevice-audio-device"
    readonly property string _volumeOption: _aout === "waveout" ? "waveout-volume" : "mmdevice-volume"
    readonly property bool _rememberVolume: _option("volume-save") === true
    readonly property int _eqPreset: RdEffects.values.equalizerPreset
    // spatial audio: the room spatializer or the headphone virtualization filter; the mode
    // shown is the filter that is on, else the one last chosen here
    readonly property var _spatialModes: ["headphone_channel_mixer", "spatializer"]
    property string _preferredSpatialMode: "headphone_channel_mixer"
    readonly property string _spatialMode: _filterOn("spatializer") ? "spatializer"
                                         : _filterOn("headphone_channel_mixer") ? "headphone_channel_mixer"
                                         : _preferredSpatialMode
    readonly property bool _spatial: _filterOn("spatializer") || _filterOn("headphone_channel_mixer")

    function _setSpatial(enabled, mode) {
        for (const m of _spatialModes) {
            const on = enabled && m === mode
            if (_filterOn(m) !== on)
                RdEffects.setAudioFilterEnabled(m, on)
        }
    }

    SettingsSection {
        title: qsTr("Output")

        SettingsOption {
            option: "audio"
            text: qsTr("Enable audio")
        }

        SettingsOption {
            option: root._deviceOption
            text: qsTr("Output device")
        }

        SettingsOption {
            option: "mix-mode"
            text: qsTr("Speaker setup")
            choices: RdEffects.optionChoices("mix-mode").map((c, i) => i === 0 ? { value: c.value, text: qsTr("Automatic") } : c)
        }
    }

    SettingsSection {
        title: qsTr("Volume")

        SettingsOption {
            option: "qt-max-volume"
            text: qsTr("Maximum volume")
            kind: "slider"
            from: 100
            to: 300
            step: 25
            labels: [qsTr("100%"), qsTr("200%"), qsTr("300%")]
        }

        // Figma "Values" (stacked): remember the last volume, or always start at a level
        SettingsRow {
            text: qsTr("Startup volume")
            description: RdEffects.optionDescription("volume-save")
            keywords: "volume-save " + root._volumeOption

            Rectangle {
                implicitWidth: VLCStyle.dp(320)
                implicitHeight: VLCStyle.dp(78)
                radius: VLCStyle.rd_radius_normal
                color: VLCStyle.palette.rdBgB2

                Column {
                    anchors.fill: parent
                    anchors.margins: VLCStyle.dp(2)
                    spacing: VLCStyle.dp(2)

                    VolumeChoice {
                        width: parent.width
                        selected: root._rememberVolume
                        text: qsTr("Remember last volume")
                        onClicked: RdEffects.setOption("volume-save", true)
                    }

                    VolumeChoice {
                        id: fixedChoice

                        width: parent.width
                        selected: !root._rememberVolume
                        text: qsTr("Always starts at:")
                        onClicked: RdEffects.setOption("volume-save", false)

                        Widgets.RdValueBox {
                            anchors.right: parent.right
                            anchors.rightMargin: VLCStyle.dp(2)
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: VLCStyle.dp(182)
                            implicitHeight: VLCStyle.dp(32)
                            visible: SettingsCatalog.exists(root._volumeOption)
                            text: Math.round(Number(root._option(root._volumeOption) ?? 1) * 100) + "%"
                            Accessible.name: qsTr("Startup volume")
                            onEdited: (text) => {
                                const percent = parseFloat(text)
                                if (isNaN(percent))
                                    return
                                RdEffects.setOption("volume-save", false)
                                const max = RdEffects.optionRange(root._volumeOption).max ?? 1.25
                                RdEffects.setOption(root._volumeOption, Math.max(0, Math.min(max, percent / 100)))
                            }
                        }
                    }
                }
            }
        }

        // VLC's step is on its 0-256 scale (256 = 100%)
        SettingsOption {
            option: "volume-step"
            text: qsTr("Volume step")
            valueScale: 2.56
            unit: "%"
        }
    }

    SettingsSection {
        title: qsTr("Loudness")

        FilterToggle {
            module: "normvol"
            description: qsTr("Keeps the loudness even, so quiet and loud parts end up closer to the same level.")
            text: qsTr("Normalize loudness")
        }

        SettingsOption {
            option: "norm-max-level"
            text: qsTr("Target level")
            decimals: 1
            available: root._filterOn("normvol")
        }

        SettingsOption {
            option: "audio-replay-gain-mode"
            text: qsTr("Replay gain")
            choices: [
                { value: "none", text: qsTr("Off") },
                { value: "track", text: qsTr("Track") },
                { value: "album", text: qsTr("Album") }
            ]
        }

        SettingsOption {
            option: "audio-replay-gain-preamp"
            text: qsTr("Replay gain preamp")
            decimals: 1
            unit: qsTr("dB")
            available: String(root._option("audio-replay-gain-mode")) !== "none"
        }
    }

    SettingsSection {
        title: qsTr("Effects")

        SettingsRow {
            text: qsTr("Equalizer")
            description: qsTr("Raises or lowers ten bands of frequencies, from the deep bass to the high treble.")
            keywords: "equalizer eq"

            Widgets.RdToggle {
                checked: root._eqPreset >= 0
                Accessible.name: qsTr("Equalizer")
                onToggled: {
                    if (checked)
                        RdEffects.setAudioFilterEnabled("equalizer", true)
                    else
                        RdEffects.setEqualizerPreset(-1)
                }
            }
        }

        SettingsRow {
            text: qsTr("Equalizer preset")
            description: qsTr("Ready-made settings of the equalizer for a kind of music or place.")
            keywords: "equalizer preset eq"

            Widgets.RdDropdown {
                implicitWidth: VLCStyle.dp(320)
                implicitHeight: VLCStyle.dp(36)
                model: [qsTr("None")].concat(RdEffects.equalizerPresetNames())
                currentIndex: root._eqPreset + 1
                Accessible.name: qsTr("Equalizer preset")
                onActivated: (index) => RdEffects.setEqualizerPreset(index - 1)
            }
        }

        SettingsEqualizer {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
        }

        SettingsRow {
            text: qsTr("Two-pass")
            description: RdEffects.optionDescription("equalizer-2pass")
            keywords: "equalizer-2pass"

            Widgets.RdToggle {
                checked: RdEffects.values[RdEffects.audioFlagKey("equalizer-2pass")] === true
                Accessible.name: qsTr("Two-pass")
                onToggled: RdEffects.setAudioFlag("equalizer-2pass", checked)
            }
        }

        SettingsRow {
            text: qsTr("Spatial audio")
            description: qsTr("Makes the sound seem to come from around you: in a room, or through headphones.")
            keywords: "spatializer headphone"

            Widgets.RdToggle {
                checked: root._spatial
                Accessible.name: qsTr("Spatial audio")
                onToggled: root._setSpatial(checked, root._spatialMode)
            }
        }

        SettingsRow {
            text: qsTr("Spatial audio mode")
            description: qsTr("Headphone virtualization places the speakers around you in headphones; Room adds the echo of a room.")
            keywords: "spatializer headphone"

            Widgets.RdDropdown {
                implicitWidth: VLCStyle.dp(320)
                implicitHeight: VLCStyle.dp(36)
                model: [qsTr("Headphone virtualization"), qsTr("Room")]
                currentIndex: root._spatialModes.indexOf(root._spatialMode)
                Accessible.name: qsTr("Spatial audio mode")
                onActivated: (index) => {
                    root._preferredSpatialMode = root._spatialModes[index]
                    if (root._spatial)
                        root._setSpatial(true, root._preferredSpatialMode)
                }
            }
        }

        FilterToggle {
            module: "stereo_widen"
            description: qsTr("Makes the stereo sound wider, as if the speakers were further apart.")
            text: qsTr("Stereo widening")
        }

        FilterToggle {
            module: "compressor"
            description: qsTr("Narrows the gap between the quiet and the loud parts, so dialogue stays audible without loud scenes being too loud.")
            text: qsTr("Compressor")
        }

        // the pitch shifter is on while the pitch is not 0 (as in the settings sidebar)
        SettingsRow {
            text: qsTr("Pitch shift")
            description: RdEffects.optionDescription("pitch-shift")
            keywords: "pitch-shift scaletempo_pitch semitones"

            Widgets.RdValueBox {
                readonly property real pitch: root._filterOn("scaletempo_pitch")
                                              ? Number(RdEffects.values[RdEffects.audioKey("pitch-shift")] ?? 0) : 0

                text: pitch.toFixed(2)
                Accessible.name: qsTr("Pitch shift")
                onEdited: (text) => {
                    const v = parseFloat(text.replace(",", "."))
                    if (isNaN(v))
                        return
                    const pitch = Math.max(-12, Math.min(12, v))
                    RdEffects.setAudioValue("pitch-shift", pitch)
                    if ((pitch !== 0) !== RdEffects.audioFilterEnabled("scaletempo_pitch"))
                        RdEffects.setAudioFilterEnabled("scaletempo_pitch", pitch !== 0)
                }
            }
        }

        FilterToggle {
            module: "chorus_flanger"
            description: qsTr("Adds a chorus or flanger effect: copies of the sound, slightly delayed.")
            text: qsTr("Chorus/flanger")
        }

        FilterToggle {
            module: "karaoke"
            description: qsTr("Removes the voice from songs where it is mixed in the center.")
            text: qsTr("Karaoke")
        }
    }

    SettingsSection {
        title: qsTr("Tracks")

        SettingsLanguageOption {
            option: "audio-language"
            text: qsTr("Preferred audio language")
        }

        SettingsOption {
            option: "audio-desync"
            text: qsTr("Audio delay")
            valueScale: 1000
            decimals: 2
            unit: qsTr("s")
        }
    }

    SettingsSection {
        title: qsTr("Visualization")

        SettingsOption {
            option: "audio-visual"
            text: qsTr("Visualizer")
        }
    }

    advanced: [
        SettingsSection {
            SettingsOption {
                option: "mmdevice-passthrough"
                text: qsTr("Pass compressed audio to the receiver")
            }

            SettingsOption {
                option: "force-dolby-surround"
                text: qsTr("Detect Dolby Surround")
                choices: [
                    { value: 0, text: qsTr("Automatic") },
                    { value: 1, text: qsTr("On") },
                    { value: 2, text: qsTr("Off") }
                ]
            }

            SettingsOption {
                option: "audio-resampler"
                text: qsTr("Resampler")
            }

            SettingsOption {
                option: "role"
                text: qsTr("Media role")
            }

            SettingsOption {
                option: "effect-width"
                text: qsTr("Visualization width")
                unit: qsTr("px")
            }

            SettingsOption {
                option: "effect-height"
                text: qsTr("Visualization height")
                unit: qsTr("px")
            }

            SettingsOption {
                option: "aout"
                text: qsTr("Audio output")
                restartRequired: true
            }

            SettingsOption {
                option: "audio-time-stretch"
                text: qsTr("Keep the pitch when the speed changes")
            }

            SettingsOption {
                option: "stereo-mode"
                text: qsTr("Stereo mode")
            }

            SettingsOption {
                option: "gain"
                text: qsTr("Audio gain")
                decimals: 2
            }

            SettingsOption {
                option: "audio-filter"
                text: qsTr("Audio filters")
            }
        },

        SettingsMoreOptions {
            category: "audio"
        }
    ]

    // an audio filter of the settings sidebar turned on or off
    component FilterToggle: SettingsRow {
        id: filterRow

        property string module

        keywords: module

        Widgets.RdToggle {
            checked: RdEffects.values[RdEffects.audioFilterKey(filterRow.module)] === true
            Accessible.name: filterRow.text
            onToggled: RdEffects.setAudioFilterEnabled(filterRow.module, checked)
        }
    }

    // a row of the startup volume choice (Figma "Values": 316x36, padding 12; BG/Accent
    // Bright + Accent/Main when chosen, BG/A4 + FG/A3 otherwise)
    component VolumeChoice: T.AbstractButton {
        id: choice

        property bool selected: false

        implicitHeight: VLCStyle.dp(36)
        leftPadding: VLCStyle.dp(12)

        focusPolicy: Qt.StrongFocus
        hoverEnabled: true

        Accessible.role: Accessible.RadioButton
        Accessible.checked: selected

        Keys.onReturnPressed: clicked()
        Keys.onEnterPressed: clicked()

        background: Rectangle {
            radius: VLCStyle.rd_radius_small
            color: choice.selected ? VLCStyle.palette.rdBgAccentBright
                                   : (choice.hovered ? VLCStyle.palette.rdBgA2 : VLCStyle.palette.rdBgA4)
            border.width: choice.visualFocus ? VLCStyle.dp(1) : 0
            border.color: VLCStyle.palette.rdFgA3
        }

        contentItem: Text {
            verticalAlignment: Text.AlignVCenter
            text: choice.text
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: choice.selected ? VLCStyle.palette.rdAccentMain : VLCStyle.palette.rdFgA3
        }
    }
}
