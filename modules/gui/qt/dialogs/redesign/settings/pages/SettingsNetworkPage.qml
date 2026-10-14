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
// redesign: Settings > Network ("Network Connections & Security", video 18:18-18:19, Figma
// "Settings - network"); rows: P8-15. Buffering in words; the four buffer sizes below it are
// dimmed until "Custom" is chosen (Figma).
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Dialogs

SettingsPage {
    id: root

    readonly property var _cachingOptions: ["file-caching", "disc-caching", "network-caching", "live-caching"]
    // milliseconds for local files, discs, network streams and live capture; "Normal" is VLC's
    readonly property var _presets: [
        { text: qsTr("Low latency"), values: [300, 300, 300, 100] },
        { text: qsTr("Normal"), values: [1000, 300, 1000, 300] },
        { text: qsTr("More buffering"), values: [3000, 1000, 3000, 1000] }
    ]
    readonly property var _current: _cachingOptions.map((name) => Number(RdEffects.values[RdEffects.optionKey(name)] ?? 0))
    readonly property int _presetIndex: _presets.findIndex((p) => p.values.every((v, i) => v === _current[i]))
    // chosen "Custom" stays custom while the values still equal a preset
    property bool _customChosen: false
    readonly property bool _custom: _customChosen || _presetIndex < 0

    SettingsSection {
        title: qsTr("Buffering")

        SettingsRow {
            text: qsTr("Buffering")
            description: qsTr("How much of a file or stream VLC reads ahead before playing it. More buffering plays more smoothly on slow connections; less starts and reacts faster.")
            keywords: "caching cache buffer latency"

            Widgets.RdDropdown {
                implicitWidth: VLCStyle.dp(320)
                implicitHeight: VLCStyle.dp(36)
                model: root._presets.map((p) => p.text).concat([qsTr("Custom")])
                currentIndex: root._custom ? root._presets.length : root._presetIndex
                Accessible.name: qsTr("Buffering")
                onActivated: (index) => {
                    root._customChosen = index === root._presets.length
                    if (root._customChosen)
                        return
                    root._presets[index].values.forEach((v, i) => RdEffects.setOption(root._cachingOptions[i], v))
                }
            }
        }

        SettingsOption {
            option: "file-caching"
            text: qsTr("Local files")
            unit: qsTr("ms")
            available: root._custom
        }

        SettingsOption {
            option: "disc-caching"
            text: qsTr("Discs")
            unit: qsTr("ms")
            available: root._custom
        }

        SettingsOption {
            option: "network-caching"
            text: qsTr("Network streams")
            unit: qsTr("ms")
            available: root._custom
        }

        SettingsOption {
            option: "live-caching"
            text: qsTr("Live capture")
            unit: qsTr("ms")
            available: root._custom
        }
    }

    SettingsSection {
        title: qsTr("Proxy")

        SettingsOption {
            option: "http-proxy"
            text: qsTr("HTTP proxy")
            placeholder: qsTr("System proxy")
        }

        SettingsOption {
            option: "http-proxy-pwd"
            text: qsTr("HTTP proxy password")
        }
    }

    SettingsSection {
        title: qsTr("Security")

        SettingsOption {
            option: "gnutls-system-trust"
            text: qsTr("Verify certificates against the system trust store")
        }

        SettingsOption {
            option: "gnutls-priorities"
            text: qsTr("Cipher preference")
            choices: [
                { value: "PERFORMANCE", text: qsTr("Fastest") },
                { value: "NORMAL", text: qsTr("Balanced") },
                { value: "SECURE128", text: qsTr("Secure") },
                { value: "SECURE256", text: qsTr("Most secure") }
            ]
        }
    }

    advanced: [
        SettingsSection {
            SettingsOption {
                option: "ipv4-timeout"
                text: qsTr("Connection timeout")
                valueScale: 1000
                decimals: 1
                unit: qsTr("s")
            }

            SettingsOption {
                option: "mtu"
                text: qsTr("Network packet size (MTU)")
                unit: qsTr("bytes")
            }
        },

        SettingsMoreOptions {
            category: "network"
        }
    ]
}
