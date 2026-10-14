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
// redesign: Settings > Controls ("Mouse, Keyboard & Remote Controls", video 17:56-17:58, Figma
// "Settings - controls"); rows: P8-08. The shortcuts themselves are edited in the Keyboard
// Shortcuts dialog (P7-12).
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

    // VLC's wheel modes: -1 nothing, 0 volume, 2 seek, 3 seek in the other direction
    readonly property int _yWheel: Number(_option("hotkeys-y-wheel-mode") ?? 0)
    readonly property int _xWheel: Number(_option("hotkeys-x-wheel-mode") ?? 2)
    readonly property bool _webRemote: webRemoteRow.checked

    Component {
        id: hotkeysModelComponent

        HotkeysModel {
            ctx: MainCtx
        }
    }

    SettingsSection {
        title: qsTr("Keyboard Shortcuts")

        SettingsRow {
            text: qsTr("Defaults")
            description: qsTr("Opens the list of every keyboard shortcut, where each one can be changed.")
            keywords: "hotkeys keys shortcuts edit"

            Widgets.RdButton {
                text: qsTr("Edit Keyboard Shortcuts")
                enabled: !!root.settingsDialog
                onClicked: root.settingsDialog.openExternal(() => DialogsProvider.keyboardShortcutsDialog())
            }
        }

        SettingsRow {
            text: qsTr("Reset all shortcuts")
            description: qsTr("Puts every keyboard shortcut back to VLC's own.")
            keywords: "hotkeys keys shortcuts reset defaults"

            Widgets.RdButton {
                text: qsTr("Reset")
                onClicked: {
                    if (!DialogsProvider.questionDialog(qsTr("Put every keyboard shortcut back to VLC's own?"),
                                                        qsTr("Reset all shortcuts")))
                        return
                    const model = hotkeysModelComponent.createObject(root)
                    model.reload()
                    model.resetAll()
                    model.save()
                    model.destroy()
                }
            }
        }
    }

    SettingsSection {
        title: qsTr("Skip Amounts")

        SettingsOption {
            option: "extrashort-jump-size"
            text: qsTr("Very short skip")
            unit: qsTr("s")
        }

        SettingsOption {
            option: "short-jump-size"
            text: qsTr("Short skip")
            unit: qsTr("s")
        }

        SettingsOption {
            option: "medium-jump-size"
            text: qsTr("Medium skip")
            unit: qsTr("s")
        }

        SettingsOption {
            option: "long-jump-size"
            text: qsTr("Long skip")
            unit: qsTr("s")
        }
    }

    SettingsSection {
        title: qsTr("Mouse")

        SettingsOption {
            option: "mouse-pause-policy"
            text: qsTr("Single click on the video")
            choices: [
                { value: "auto", text: qsTr("Play / Pause") },
                { value: "pause-on-released", text: qsTr("Play / Pause when released") },
                { value: "disabled", text: qsTr("Nothing") }
            ]
        }

        WheelRow {
            option: "hotkeys-y-wheel-mode"
            text: qsTr("Scroll wheel")
            mode: root._yWheel
        }

        WheelRow {
            option: "hotkeys-x-wheel-mode"
            text: qsTr("Horizontal scroll")
            mode: root._xWheel
        }

        // VLC reverses seeking only (mode 3)
        SettingsRow {
            text: qsTr("Reverse scroll direction")
            description: qsTr("Scrolling seeks the other way. Applies to the wheels set to Seek.")
            keywords: "hotkeys-y-wheel-mode hotkeys-x-wheel-mode reverse"
            available: root._yWheel >= 2 || root._xWheel >= 2

            Widgets.RdToggle {
                checked: root._yWheel === 3 || root._xWheel === 3
                Accessible.name: qsTr("Reverse scroll direction")
                onToggled: {
                    const mode = checked ? 3 : 2
                    if (root._yWheel >= 2)
                        RdEffects.setOption("hotkeys-y-wheel-mode", mode)
                    if (root._xWheel >= 2)
                        RdEffects.setOption("hotkeys-x-wheel-mode", mode)
                }
            }
        }
    }

    SettingsSection {
        title: qsTr("Remotes")

        SettingsInterfaceToggle {
            id: webRemoteRow

            module: "http"
            text: qsTr("Web remote control")
            description: qsTr("Lets a web browser on this computer or your network control VLC. VLC uses this setting the next time it starts.")
        }

        SettingsOption {
            option: "http-port"
            text: qsTr("Port")
            available: root._webRemote
        }

        SettingsOption {
            option: "http-password"
            text: qsTr("Password")
            kind: "password"
            available: root._webRemote
        }
    }

    advanced: [
        SettingsSection {
            SettingsOption {
                option: "mouse-events"
                text: qsTr("Handle mouse clicks on the video")
            }

            SettingsOption {
                option: "keyboard-events"
                text: qsTr("Handle keys pressed on the video")
            }

            SettingsOption {
                option: "qt-disable-volume-keys"
                text: qsTr("Ignore the keyboard's volume keys")
            }
        },

        SettingsMoreOptions {
            category: "controls"
        }
    ]

    // a mouse wheel's action in words; the reversed seek (3) shows as Seek
    component WheelRow: SettingsRow {
        id: wheelRow

        property string option
        property int mode

        description: RdEffects.optionDescription(option)
        keywords: option

        Widgets.RdDropdown {
            readonly property var values: [0, 2, -1]

            implicitWidth: VLCStyle.dp(320)
            implicitHeight: VLCStyle.dp(36)
            model: [qsTr("Volume"), qsTr("Seek"), qsTr("Nothing")]
            currentIndex: values.indexOf(wheelRow.mode === 3 ? 2 : wheelRow.mode)
            Accessible.name: wheelRow.text
            onActivated: (index) => RdEffects.setOption(wheelRow.option, values[index])
        }
    }
}
