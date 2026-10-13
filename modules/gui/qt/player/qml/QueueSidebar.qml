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

// redesign: queue sidebar (video 9:29-9:34 and 15:08-15:16, Decision 3; Figma "queue",
// "bookmarks", "chapters"). Tabs Queue / Bookmarks / Chapters over VLC's play queue, the media
// library bookmarks of the current file and the chapters of the current title.
import QtQuick
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Playlist
import VLC.Widgets as Widgets

RdSidePanel {
    id: root

    tabs: [
        { key: "queue", label: qsTr("Queue"), icon: "queue", width: 129 },
        { key: "bookmarks", label: qsTr("Bookmarks"), icon: "bookmarks", width: 129 },
        { key: "chapters", label: qsTr("Chapters"), icon: "chapters", width: 129 }
    ]
    currentKey: RdPanels.queueOpen ? RdPanels.current : "queue"
    onTabClicked: (key) => RdPanels.open(key)

    function durationText(duration) {
        if (!duration || !duration.valid())
            return ""
        const minutes = Math.floor(duration.toSeconds() / 60)
        return minutes >= 60 ? qsTr("%1h %2m").arg(Math.floor(minutes / 60)).arg(minutes % 60)
                             : qsTr("%1m").arg(minutes)
    }

    /* Queue */

    RdSidePanelPage {
        id: queuePage

        key: "queue"

        property int selectedIndex: -1

        PlaylistListModel {
            id: queueModel

            playlist: MainPlaylistController.playlist
            onCountChanged: queuePage.selectedIndex = -1
        }

        Header {
            text: qsTr("%n item(s)", "", queueModel.count)
                  + (queueModel.duration.valid() ? " - " + root.durationText(queueModel.duration) : "")

            HeaderButton {
                rdIcon: "sort"
                description: qsTr("Sort by title")
                onClicked: MainPlaylistController.sort(PlaylistController.SORT_KEY_TITLE,
                                                       MainPlaylistController.sortOrder === PlaylistController.SORT_ORDER_ASC
                                                           ? PlaylistController.SORT_ORDER_DESC
                                                           : PlaylistController.SORT_ORDER_ASC)
            }

            HeaderButton {
                rdIcon: "repeat_direction-right"
                description: qsTr("Repeat")
                checked: MainPlaylistController.repeatMode !== PlaylistController.PLAYBACK_REPEAT_NONE
                onClicked: MainPlaylistController.toggleRepeatMode()
            }

            HeaderButton {
                rdIcon: "shuffle_direction-right"
                description: qsTr("Shuffle")
                checked: MainPlaylistController.random
                onClicked: MainPlaylistController.toggleRandom()
            }

            HeaderButton {
                rdIcon: "remove"
                description: qsTr("Remove the selected item")
                enabled: queuePage.selectedIndex >= 0
                onClicked: {
                    queueModel.removeItems([queuePage.selectedIndex])
                    queuePage.selectedIndex = -1
                }
            }

            HeaderButton {
                rdIcon: "add"
                description: qsTr("Add files to the queue")
                onClicked: DialogsProvider.simpleOpenDialog(false)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: VLCStyle.dp(20)
            Layout.rightMargin: VLCStyle.dp(20)
            spacing: VLCStyle.dp(12)

            Repeater {
                model: queueModel

                // a click selects the row (for "remove"), a double click plays it; the handle
                // drags it to another place in the queue
                delegate: Widgets.RdListRow {
                    id: queueRow

                    required property int index
                    required property var model

                    title: model.title ?? ""
                    detail: model.duration && model.duration.valid() ? model.duration.formatHMS() : ""
                    current: !!model.isCurrent
                    selected: queuePage.selectedIndex === index || drag.active
                    leftPadding: VLCStyle.dp(32)

                    onClicked: queuePage.selectedIndex = index
                    onDoubleClicked: MainPlaylistController.goTo(index, true)

                    z: drag.active ? 1 : 0
                    transform: Translate {
                        y: drag.active ? drag.translation.y : 0
                    }

                    Widgets.RdIcon {
                        x: VLCStyle.dp(4)
                        anchors.verticalCenter: parent.verticalCenter
                        name: "move"
                        color: VLCStyle.palette.rdFgA3

                        DragHandler {
                            id: drag

                            target: null
                            xAxis.enabled: false
                            cursorShape: Qt.SizeVerCursor

                            onActiveChanged: {
                                if (active)
                                    return
                                const step = queueRow.height + VLCStyle.dp(12)
                                const target = Math.max(0, Math.min(queueModel.count - 1,
                                                                    queueRow.index + Math.round(translation.y / step)))
                                if (target < queueRow.index)
                                    queueModel.moveItemsPre([queueRow.index], target)
                                else if (target > queueRow.index)
                                    queueModel.moveItemsPost([queueRow.index], target)
                            }
                        }
                    }
                }
            }
        }
    }

    /* Bookmarks */

    RdSidePanelPage {
        key: "bookmarks"

        Header {
            text: qsTr("%n Bookmark(s)", "", bookmarkLoader.item ? bookmarkLoader.item.count : 0)

            // Ctrl+B and the instant bookmark are new features (BUILD_PLAN.md W4.8b); until then
            // both buttons open VLC's bookmark editor
            HeaderButton {
                rdIcon: "remove"
                description: qsTr("Edit bookmarks")
                onClicked: DialogsProvider.bookmarksDialog()
            }

            HeaderButton {
                rdIcon: "add"
                description: qsTr("Edit bookmarks")
                onClicked: DialogsProvider.bookmarksDialog()
            }
        }

        // VLC keeps bookmarks in the media library
        Loader {
            id: bookmarkLoader

            Layout.fillWidth: true
            Layout.leftMargin: VLCStyle.dp(20)
            Layout.rightMargin: VLCStyle.dp(20)
            active: MainCtx.mediaLibraryAvailable
            source: "qrc:///qt/qml/VLC/MediaLibrary/RdBookmarkList.qml"
        }
    }

    /* Chapters */

    RdSidePanelPage {
        key: "chapters"

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: VLCStyle.dp(20)
            Layout.rightMargin: VLCStyle.dp(20)
            Layout.topMargin: VLCStyle.dp(20)
            spacing: VLCStyle.dp(12)

            Repeater {
                model: Player.chapters

                delegate: Widgets.RdListRow {
                    required property int index
                    required property var model

                    number: index + 1
                    title: model.display ?? ""
                    detail: model.time ? model.time.formatHMS() : ""
                    current: !!model.checked
                    onClicked: Player.chapters.selectChapter(index)
                }
            }

            Text {
                visible: Player.chapters.count === 0
                Layout.fillWidth: true
                leftPadding: VLCStyle.dp(4)
                text: qsTr("This media has no chapters")
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: VLCStyle.palette.rdFgA3
            }
        }
    }

    /* parts */

    // Figma "Frame 60": 400x68, padding 20,20,20,28, count on the left, icons on the right
    component Header: Item {
        property alias text: label.text
        default property alias buttons: buttonRow.data

        Layout.fillWidth: true
        Layout.preferredHeight: VLCStyle.dp(68)

        Text {
            id: label

            anchors.left: parent.left
            anchors.leftMargin: VLCStyle.dp(28)
            anchors.right: buttonRow.left
            anchors.rightMargin: VLCStyle.dp(10)
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: VLCStyle.palette.rdFgA3
        }

        Row {
            id: buttonRow

            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.dp(20)
            anchors.verticalCenter: parent.verticalCenter
            spacing: VLCStyle.dp(12)
        }
    }

    // queue header icon: accent while its mode is on (repeat, shuffle)
    component HeaderButton: Widgets.IconToolButton {
        width: VLCStyle.rd_iconButtonWidth
        height: VLCStyle.rd_iconButtonHeight
        font.pixelSize: VLCStyle.rd_iconSize
        text: VLCIcons.more
        color: checked ? colorContext.accent : (hovered ? VLCStyle.palette.rdFgA1 : VLCStyle.palette.rdFgA2)
    }
}
