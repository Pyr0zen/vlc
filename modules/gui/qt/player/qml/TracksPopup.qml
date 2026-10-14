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

// redesign: tracks popup (video 4:30-4:56, Figma "Controls" variants subtitles / audio / video,
// frame "Subtitles" 400x524). One rounded panel (radius 10, BG/B1, opaque over the native
// video) whose top is the tab header: 400x50 BG/B2, tabs Video / Audio / Subtitles of 128.67 px
// (6 px side padding, 1 px apart); the active tab has a two-tone icon and a 2 px accent
// underline (tab width - 16). A 1 px gap of the panel color separates the header from the body.
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

    readonly property real _headerHeight: VLCStyle.rd_sidePanelTabHeight + VLCStyle.dp(1, VLCStyle.scale)

    implicitWidth: VLCStyle.rd_sidePanelWidth
    // Figma height (524 with the tabs), shrunk to the room above the control bar; the content
    // scrolls when it does not fit (small windows, many tracks or devices)
    implicitHeight: _headerHeight
                    + Math.min(Math.max(content.implicitHeight + VLCStyle.dp(20, VLCStyle.scale),
                                        Math.min(VLCStyle.dp(524, VLCStyle.scale), maximumHeight) - _headerHeight),
                               maximumHeight - _headerHeight)

    visible: RdPanels.tracksOpen

    Widgets.RdPanel {
        id: panel

        anchors.fill: parent

        // opaque over the native video (Figma's 95 % assumes a background blur)
        color: Qt.alpha(root.rdPalette.rdBgB1Transparent, 1.0)

        // tab header: the top of the panel, rounded like it at the top, square at the bottom
        Rectangle {
            id: header

            width: parent.width
            height: VLCStyle.rd_sidePanelTabHeight
            radius: panel.radius
            color: root.rdPalette.rdBgB2

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.radius
                color: parent.color
            }

            Row {
                id: tabs

                readonly property real sidePadding: VLCStyle.dp(6, VLCStyle.scale)

                x: sidePadding
                width: parent.width - 2 * sidePadding
                height: parent.height
                spacing: VLCStyle.dp(1, VLCStyle.scale)

                Repeater {
                    id: tabRepeater

                    model: [
                        { key: "video", label: qsTr("Video"), icon: "video" },
                        { key: "audio", label: qsTr("Audio"), icon: "audio" },
                        { key: "subtitles", label: qsTr("Subtitles"), icon: "subtitles" }
                    ]

                    delegate: T.AbstractButton {
                        id: tabButton

                        required property var modelData
                        readonly property bool active: root.tab === modelData.key

                        width: (tabs.width - (tabRepeater.count - 1) * tabs.spacing) / Math.max(1, tabRepeater.count)
                        height: tabs.height

                        focusPolicy: Qt.StrongFocus
                        Accessible.role: Accessible.PageTab
                        Accessible.name: modelData.label
                        Accessible.checkable: true
                        Accessible.checked: active

                        onClicked: RdPanels.open(modelData.key)

                        contentItem: Item {
                            Row {
                                id: tabRow

                                x: (parent.width - width) / 2
                                y: VLCStyle.dp(14, VLCStyle.scale)
                                spacing: VLCStyle.dp(8, VLCStyle.scale)

                                Widgets.RdIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: tabButton.active ? tabButton.modelData.icon + "_two-tone-yes" : tabButton.modelData.icon
                                    size: VLCStyle.dp(20, VLCStyle.scale)
                                    // Figma: FG/A3 strokes when active, FG/A4 when not (hover: FG/A3)
                                    color: (tabButton.active || tabButton.hovered) ? root.rdPalette.rdFgA3 : root.rdPalette.rdFgA4
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tabButton.modelData.label
                                    // Figma: Inter 400 12, FG/A2 when active, FG/A3 when not
                                    font.family: VLCStyle.rd_fontFamily
                                    font.pixelSize: VLCStyle.rd_fontSize_toggle
                                    color: (tabButton.active || tabButton.hovered) ? root.rdPalette.rdFgA2 : root.rdPalette.rdFgA3
                                }
                            }

                            Rectangle {
                                visible: tabButton.active
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width - VLCStyle.dp(16, VLCStyle.scale)
                                height: VLCStyle.dp(2, VLCStyle.scale)
                                color: root.rdPalette.rdAccentMain
                            }

                            Rectangle {
                                visible: tabButton.visualFocus
                                anchors.fill: parent
                                anchors.margins: VLCStyle.dp(2, VLCStyle.scale)
                                color: "transparent"
                                radius: VLCStyle.rd_radius_small
                                border.width: VLCStyle.dp(1, VLCStyle.scale)
                                border.color: root.rdPalette.rdFgA3
                            }
                        }
                    }
                }
            }
        }

        Flickable {
            id: flick

            anchors.fill: parent
            anchors.topMargin: root._headerHeight
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

                // Figma: the list frame is 138.5 tall whatever the track count (with the 20 px
                // below the rows), so the next section label stays in place
                TrackList {
                    Layout.minimumHeight: VLCStyle.dp(118.5, VLCStyle.scale)
                    model: root.tab === "audio" ? Player.audioTracks
                         : root.tab === "video" ? Player.videoTracks
                         : Player.subtitleTracks
                }

                // subtitles: external tracks; the pencil and + both add a subtitle file (Figma wires
                // both to the Add Subtitles dialog, W6.5). Figma has no divider above it on this
                // tab, only on the Audio tab.
                SectionLabel {
                    visible: root.tab === "subtitles"
                    text: qsTr("External Tracks")
                    actions: [
                        { icon: "edit", description: qsTr("Edit subtitle files") },
                        { icon: "add", description: qsTr("Add subtitle file") }
                    ]
                    onActionTriggered: (index) => DialogsProvider.loadSubtitlesFile()
                }

                // audio: output device (refresh re-reads the device list)
                Widgets.RdMenuDivider {
                    visible: root.tab === "audio"
                    Layout.fillWidth: true
                }

                SectionLabel {
                    visible: root.tab === "audio"
                    text: qsTr("Output Device")
                    actions: [ { icon: "refresh", description: qsTr("Refresh output devices") } ]
                    onActionTriggered: (index) => Player.audioDevices.refresh()
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

                    // Figma button 500:3075 hides its icon: text only
                    style: Widgets.RdButton.Style.Bar
                    text: qsTr("Show Preferences")

                    // opens the settings sidebar on the matching tab (Figma F-07)
                    onClicked: RdPanels.open(root.tab === "video" ? "videoSettings"
                                             : root.tab === "audio" ? "audioSettings" : "subtitleSettings")
                }
            }
        }
    }

    // section label row (Figma "Frame 60": 60 px, padding 0,28, FG/A3 14 px) with optional icon
    // actions on the right (Figma "Frame 61": 24 px icons 20 apart, 28 px from the right edge)
    component SectionLabel: Item {
        id: section

        property alias text: label.text
        // [{ icon, description }]; icon is a Figma icon name (Widgets.RdIcon)
        property var actions: []
        signal actionTriggered(int index)

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

        Row {
            // the 30 px buttons center their 24 px icons: 3 px of each button lie outside the icon
            readonly property real _iconInset: (VLCStyle.rd_iconButtonWidth - VLCStyle.rd_iconSize) / 2

            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.dp(28, VLCStyle.scale) - _iconInset
            anchors.verticalCenter: parent.verticalCenter
            spacing: VLCStyle.dp(20, VLCStyle.scale) - 2 * _iconInset

            Repeater {
                model: section.actions

                delegate: Widgets.IconToolButton {
                    required property var modelData
                    required property int index

                    width: VLCStyle.rd_iconButtonWidth
                    height: VLCStyle.rd_iconButtonHeight
                    font.pixelSize: VLCStyle.rd_iconSize
                    text: VLCIcons.add
                    rdIcon: modelData.icon
                    description: modelData.description
                    onClicked: section.actionTriggered(index)
                }
            }
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

        // hover BG/A2 (Figma); pressed and keyboard focus are not in Figma: pressed keeps the
        // hover fill, keyboard focus adds the FG/A3 ring of the other redesign controls
        background: Rectangle {
            radius: VLCStyle.rd_radius_small
            color: (row.hovered || row.down) ? VLCStyle.palette.rdBgA2 : "transparent"
            border.width: row.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
            border.color: VLCStyle.palette.rdFgA3
        }

        contentItem: Item {
            Widgets.RdIcon {
                x: VLCStyle.dp(4, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter
                visible: row.selected
                name: "check_state-active"
            }

            // Figma: 32 px check cell + 10 px gap
            Text {
                x: VLCStyle.dp(42, VLCStyle.scale)
                width: parent.width - x
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: row.label
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                // the selected row keeps FG/A1 (Figma): only the accent check marks it
                color: row.hovered ? VLCStyle.palette.rdFg2 : VLCStyle.palette.rdFgA1
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
