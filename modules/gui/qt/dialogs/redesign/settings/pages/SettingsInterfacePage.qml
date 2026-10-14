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
// redesign: Settings > Interface ("Interface Settings", video 17:50-17:51, Figma
// "Settings - interface" / "Settings - interface-1"); rows: P8-06.
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

    readonly property bool _skin: String(_option("intf")) === "skins2"
    readonly property bool _tray: _option("qt-system-tray") === true

    SettingsSection {
        title: qsTr("Skin")

        SettingsOption {
            option: "intf"
            text: qsTr("Use a custom skin")
            description: qsTr("Replaces this interface with VLC's skinnable one, drawn by a skin file. VLC uses it the next time it starts.")
            kind: "toggle"
            checkedValue: "skins2"
            uncheckedValue: ""
        }

        SettingsOption {
            option: "skins2-last"
            text: qsTr("Skin file")
            kind: "file"
            available: root._skin
        }
    }

    SettingsSection {
        title: qsTr("Window")

        SettingsOption {
            option: "embedded-video"
            text: qsTr("Play video inside main window")
            restartRequired: true
        }

        SettingsOption {
            option: "qt-video-autoresize"
            text: qsTr("Resize window to fit video")
            choices: [
                { value: false, text: qsTr("Never") },
                { value: true, text: qsTr("When a video starts") }
            ]
        }

        SettingsOption {
            option: "video-on-top"
            text: qsTr("Keep window above other windows")
        }

        SettingsOption {
            option: "qt-titlebar"
            text: qsTr("Show window decorations")
            restartRequired: true
        }

        SettingsOption {
            option: "qt-name-in-title"
            text: qsTr("Show the file name in the title bar")
        }

        SettingsOption {
            option: "qt-fullscreen-screennumber"
            text: qsTr("Open fullscreen on")
            choices: {
                const list = [{ value: -1, text: qsTr("Current screen") }]
                const screens = Qt.application.screens
                for (let i = 0; i < screens.length; ++i)
                    list.push({ value: i, text: qsTr("Screen %1 (%2)").arg(i + 1).arg(screens[i].name) })
                return list
            }
        }
    }

    SettingsSection {
        title: qsTr("Playback Controls")

        SettingsOption {
            option: "qt-minimal-view"
            text: qsTr("Start in compact mode")
        }

        // Decision 30: the bars float over the video and hide; "pin video controls" keeps
        // them in a window
        SettingsOption {
            option: "qt-pin-controls"
            text: qsTr("Auto-hide the controls")
            choices: [
                { value: false, text: qsTr("Always") },
                { value: true, text: qsTr("In fullscreen only") }
            ]
        }

        SettingsOption {
            option: "mouse-hide-timeout"
            text: qsTr("Hide after")
            kind: "slider"
            valueScale: 1000
            from: 0
            to: 10
            step: 0.5
            labels: [qsTr("0 s"), qsTr("5 s"), qsTr("10 s")]
        }

        SettingsOption {
            option: "qt-fs-controller"
            text: qsTr("Show controls in fullscreen")
        }
    }

    SettingsSection {
        title: qsTr("Notifications and System Tray")

        SettingsOption {
            option: "qt-system-tray"
            text: qsTr("Show a system tray icon")
            restartRequired: true
        }

        SettingsOption {
            option: "qt-start-minimized"
            text: qsTr("Start minimized to the tray")
            available: root._tray
        }

        SettingsOption {
            option: "qt-close-to-system-tray"
            text: qsTr("Close to the tray")
            available: root._tray
        }

        SettingsOption {
            option: "qt-notification"
            text: qsTr("Show a popup when the track changes")
        }
    }

    SettingsSection {
        title: qsTr("Playlist")

        SettingsOption {
            option: "playlist-tree"
            text: qsTr("Show the playlist as a tree")
        }
    }

    advanced: [
        SettingsSection {
            SettingsOption {
                option: "qt-opacity"
                text: qsTr("Window opacity")
                kind: "slider"
                valueScale: 0.01
                from: 10
                to: 100
                step: 5
                labels: [qsTr("10%"), qsTr("100%")]
            }

            SettingsOption {
                option: "qt-pause-minimized"
                text: qsTr("Pause video when window is minimized")
            }

            SettingsOption {
                option: "qt-auto-raise"
                text: qsTr("Bring VLC to the front when playback starts")
            }

            SettingsOption {
                option: "qt-bgcone"
                text: qsTr("Show cover art in the window when playing audio")
            }

            SettingsOption {
                option: "qt-embedded-open"
                text: qsTr("Show the file browser inside the open dialog")
            }

            SettingsOption {
                option: "qt-icon-change"
                text: qsTr("Allow the app icon to change")
            }

            SettingsOption {
                option: "qt-fs-opacity"
                text: qsTr("Fullscreen controls opacity")
                kind: "slider"
                valueScale: 0.01
                from: 10
                to: 100
                step: 5
                labels: [qsTr("10%"), qsTr("100%")]
            }

            SettingsOption {
                option: "qt-menubar"
                text: qsTr("Show the menu bar")
                restartRequired: true
            }

            SettingsOption {
                option: "qt-interface-scale"
                text: qsTr("Interface size")
                restartRequired: true
                choices: [
                    { value: -1, text: qsTr("Automatic") },
                    { value: 0.75, text: qsTr("75%") },
                    { value: 1, text: qsTr("100%") },
                    { value: 1.25, text: qsTr("125%") },
                    { value: 1.5, text: qsTr("150%") },
                    { value: 2, text: qsTr("200%") }
                ]
            }

            SettingsOption {
                option: "qt-smooth-scrolling"
                text: qsTr("Smooth scrolling")
            }

            SettingsOption {
                option: "qt-backdrop-blur"
                text: qsTr("Blur behind panels")
                restartRequired: true
            }

            SettingsOption {
                option: "qt-pip-mode"
                text: qsTr("Keep playing video in a corner while browsing")
                restartRequired: true
            }

            SettingsOption {
                option: "qt-safe-area"
                text: qsTr("Safe area around the interface")
                kind: "number"
                unit: "%"
            }
        },

        SettingsMoreOptions {
            category: "interface"
        }
    ]
}
