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

// redesign: tracks popup (video 4:30-4:56, Figma "Controls" variants subtitles / audio / video).
// Tabs Video / Audio / Subtitles sit above the panel, over the video (no background); the active
// tab has an accent icon and a 2 px accent underline. Panel: 400 wide, BG/B1 95%, radius 10.
// Sections: "Embedded Tracks", then "External Tracks" (+) for subtitles or "Output Device"
// (refresh) for audio; full-width "Show Preferences" bar at the bottom.
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Dialogs

Item {
    id: root

    readonly property string tab: RdPanels.tracksOpen ? RdPanels.current : "subtitles"
    readonly property SystemPalette rdPalette: VLCStyle.palette

    implicitWidth: VLCStyle.rd_sidePanelWidth
    implicitHeight: tabs.height + panel.implicitHeight

    visible: RdPanels.tracksOpen

    // tab header (over the video)
    Row {
        id: tabs

        anchors.right: parent.right
        height: VLCStyle.rd_sidePanelTabHeight

        Repeater {
            model: [
                { key: "video", label: qsTr("Video"), icon: "video" },
                { key: "audio", label: qsTr("Audio"), icon: "audio" },
                { key: "subtitles", label: qsTr("Subtitles"), icon: "subtitles" }
            ]

            delegate: T.AbstractButton {
                id: tabButton

                required property var modelData
                readonly property bool active: root.tab === modelData.key

                width: VLCStyle.dp(129, VLCStyle.scale)
                height: tabs.height

                Accessible.name: modelData.label
                onClicked: RdPanels.open(modelData.key)

                contentItem: Item {
                    Row {
                        anchors.centerIn: parent
                        spacing: VLCStyle.dp(8, VLCStyle.scale)

                        Widgets.RdIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: tabButton.active ? tabButton.modelData.icon + "_state-active" : tabButton.modelData.icon
                            size: VLCStyle.dp(20, VLCStyle.scale)
                            color: root.rdPalette.rdFgA3
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tabButton.modelData.label
                            font.family: VLCStyle.rd_fontFamily
                            font.pixelSize: VLCStyle.rd_fontSize_label
                            color: tabButton.active ? root.rdPalette.rdFg2
                                                    : (tabButton.hovered ? root.rdPalette.rdFgA2 : root.rdPalette.rdFgA3)
                        }
                    }
                }

                background: Item {
                    Rectangle {
                        visible: tabButton.active
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - VLCStyle.dp(16, VLCStyle.scale)
                        height: VLCStyle.dp(2, VLCStyle.scale)
                        color: root.rdPalette.rdAccentMain
                    }
                }
            }
        }
    }

    Widgets.RdPanel {
        id: panel

        anchors.top: tabs.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        implicitHeight: content.implicitHeight + VLCStyle.dp(20, VLCStyle.scale)
        height: implicitHeight

        ColumnLayout {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 0

            SectionLabel {
                text: qsTr("Embedded Tracks")
            }

            TrackList {
                model: root.tab === "audio" ? Player.audioTracks
                     : root.tab === "video" ? Player.videoTracks
                     : Player.subtitleTracks
            }

            // subtitles: external tracks (+ adds a subtitle file)
            Widgets.RdMenuDivider {
                visible: root.tab === "subtitles"
                Layout.fillWidth: true
            }

            SectionLabel {
                visible: root.tab === "subtitles"
                text: qsTr("External Tracks")
                actionIcon: "add"
                actionDescription: qsTr("Add subtitle file")
                onActionTriggered: DialogsProvider.loadSubtitlesFile()
            }

            // audio: output device (refresh re-reads the device list)
            Widgets.RdMenuDivider {
                visible: root.tab === "audio"
                Layout.fillWidth: true
            }

            SectionLabel {
                visible: root.tab === "audio"
                text: qsTr("Output Device")
                actionIcon: "refresh"
                actionDescription: qsTr("Refresh output devices")
                onActionTriggered: Player.audioDevices.refresh()
            }

            TrackList {
                visible: root.tab === "audio"
                model: Player.audioDevices
            }

            Item {
                Layout.preferredHeight: VLCStyle.dp(20, VLCStyle.scale)
            }

            Widgets.RdButton {
                Layout.fillWidth: true
                Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
                Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)

                style: Widgets.RdButton.Style.Bar
                text: qsTr("Show Preferences")

                // until the settings sidebar tabs exist (W4.3-W4.6) this opens VLC's effects dialog
                onClicked: {
                    RdPanels.close()
                    DialogsProvider.extendedDialog()
                }
            }
        }
    }

    // section label row (Figma "Frame 60": 60 px, padding 0,28, FG/A3 14 px) with an optional icon
    // action on the right
    component SectionLabel: Item {
        id: section

        property alias text: label.text
        // Figma icon name (Widgets.RdIcon)
        property string actionIcon: ""
        property string actionDescription: ""
        signal actionTriggered()

        Layout.fillWidth: true
        Layout.preferredHeight: VLCStyle.dp(60, VLCStyle.scale)

        Text {
            id: label

            anchors.left: parent.left
            anchors.leftMargin: VLCStyle.dp(28, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: VLCStyle.palette.rdFgA3
        }

        Widgets.IconToolButton {
            visible: section.actionIcon !== ""
            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.dp(24, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            width: VLCStyle.rd_iconButtonWidth
            height: VLCStyle.rd_iconButtonHeight
            font.pixelSize: VLCStyle.rd_iconSize
            text: VLCIcons.add
            rdIcon: section.actionIcon
            description: section.actionDescription
            onClicked: section.actionTriggered()
        }
    }

    // track / device rows: accent check on the left, label FG/2 (selected) or FG/A1, 32 px rows, gap 12
    component TrackList: ColumnLayout {
        id: list

        property var model

        Layout.fillWidth: true
        Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
        Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
        spacing: VLCStyle.dp(12, VLCStyle.scale)

        Repeater {
            model: list.model

            delegate: T.AbstractButton {
                id: row

                required property var model
                required property int index

                Layout.fillWidth: true
                implicitHeight: VLCStyle.rd_rowHeight

                Accessible.role: Accessible.RadioButton
                Accessible.name: row.model.display
                Accessible.checked: row.model.checked

                onClicked: row.model.checked = true

                background: Rectangle {
                    radius: VLCStyle.rd_radius_small
                    color: row.hovered ? VLCStyle.palette.rdBgA2 : "transparent"
                }

                contentItem: Item {
                    Widgets.RdIcon {
                        id: check

                        x: VLCStyle.dp(4, VLCStyle.scale)
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !!row.model.checked
                        name: "check_state-active"
                    }

                    Text {
                        x: VLCStyle.dp(36, VLCStyle.scale)
                        width: parent.width - x
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: row.model.display
                        font.family: VLCStyle.rd_fontFamily
                        font.pixelSize: VLCStyle.rd_fontSize_label
                        color: (row.model.checked || row.hovered) ? VLCStyle.palette.rdFg2 : VLCStyle.palette.rdFgA1
                    }
                }
            }
        }
    }
}
