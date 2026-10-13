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

    // room available above the control bar; the Figma height (524) shrinks to fit small windows
    property real maximumHeight: VLCStyle.dp(524, VLCStyle.scale)

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
                            name: tabButton.active ? tabButton.modelData.icon + "_two-tone-yes" : tabButton.modelData.icon
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

        // Figma height (524 with the tabs), shrunk to the room above the control bar; the content
        // scrolls when it does not fit (small windows, many tracks or devices)
        implicitHeight: Math.min(Math.max(content.implicitHeight + VLCStyle.dp(20, VLCStyle.scale),
                                          Math.min(VLCStyle.dp(524, VLCStyle.scale), root.maximumHeight) - tabs.height),
                                 root.maximumHeight - tabs.height)
        height: implicitHeight

        Flickable {
            id: flick

            anchors.fill: parent
            anchors.bottomMargin: VLCStyle.dp(20, VLCStyle.scale)

            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: content.height

            ColumnLayout {
                id: content

                width: flick.width
                height: Math.max(implicitHeight, flick.height)
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
                    tracks: false
                    model: Player.audioDevices
                }

                // the panel keeps the Figma height (400x524 with the tabs); Show Preferences sits at the bottom
                Item {
                    Layout.fillHeight: true
                }

                Widgets.RdButton {
                    Layout.fillWidth: true
                    Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
                    Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)

                    style: Widgets.RdButton.Style.Bar
                    rdIcon: "settings"
                    text: qsTr("Show Preferences")

                    // opens the settings sidebar on the matching tab (Figma F-07)
                    onClicked: RdPanels.open(root.tab === "video" ? "videoSettings"
                                             : root.tab === "audio" ? "audioSettings" : "subtitleSettings")
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

    // one selectable row: accent check on the left, label FG/2 (selected or hovered) or FG/A1, 32 px
    component TrackRow: T.AbstractButton {
        id: row

        property bool selected: false
        property string label: ""

        Layout.fillWidth: true
        implicitHeight: VLCStyle.rd_rowHeight

        Accessible.role: Accessible.RadioButton
        Accessible.name: label
        Accessible.checked: selected

        background: Rectangle {
            radius: VLCStyle.rd_radius_small
            color: row.hovered ? VLCStyle.palette.rdBgA2 : "transparent"
        }

        contentItem: Item {
            Widgets.RdIcon {
                x: VLCStyle.dp(4, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter
                visible: row.selected
                name: "check_state-active"
            }

            Text {
                x: VLCStyle.dp(36, VLCStyle.scale)
                width: parent.width - x
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: row.label
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: (row.selected || row.hovered) ? VLCStyle.palette.rdFg2 : VLCStyle.palette.rdFgA1
            }
        }
    }

    // track or device list, 12 px between rows, 20 px below the last row (video 4:44).
    // Track lists start with "None" (video 4:35-4:48), which is checked when no track is selected
    // and unselects the current one; VLC names tracks "Track 1 - [English]", the design shows
    // "Track 1 - English".
    component TrackList: ColumnLayout {
        id: list

        property var model
        property bool tracks: true

        readonly property bool _anySelected: {
            for (let i = 0; i < rows.count; ++i) {
                const item = rows.itemAt(i)
                if (item && item.selected)
                    return true
            }
            return false
        }

        Layout.fillWidth: true
        Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
        Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
        Layout.bottomMargin: VLCStyle.dp(20, VLCStyle.scale)
        spacing: VLCStyle.dp(12, VLCStyle.scale)

        TrackRow {
            visible: list.tracks
            label: qsTr("None")
            selected: !list._anySelected

            onClicked: {
                for (let i = 0; i < rows.count; ++i) {
                    const item = rows.itemAt(i)
                    if (item && item.selected)
                        item.model.checked = false
                }
            }
        }

        Repeater {
            id: rows

            model: list.model

            delegate: TrackRow {
                required property var model
                required property int index

                selected: !!model.checked
                label: list.tracks ? String(model.display).replace(/ - \[(.*)\]$/, " - $1") : model.display

                onClicked: model.checked = true
            }
        }
    }
}
