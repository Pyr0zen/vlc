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

// redesign: a library grid card (full library grid view, video 10:57-10:59, IB-06, P5-17; Home
// cards 13:48-13:55, IB-34): the picture (16:9 for videos, square for songs, albums, folders and
// playlists) with a small radius, no border or shadow; the title under it in small gray text,
// dimmer once watched; the artist on a second, dimmer line for songs and albums.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style

T.AbstractButton {
    id: card

    property string title: ""
    property string subtitle: ""
    property string iconName: ""
    property url thumbnail: ""
    property bool wide: true
    property real progress: -1
    property bool watched: false
    property bool playing: false
    property bool showMore: true
    property var dragUrls: []

    signal moreClicked(Item button)

    readonly property real pictureHeight: wide ? width * 9 / 16 : width

    implicitWidth: VLCStyle.dp(211)
    implicitHeight: pictureHeight + VLCStyle.dp(8) + titleText.implicitHeight
                    + (subtitle !== "" ? subtitleText.implicitHeight + VLCStyle.dp(2) : 0)

    focusPolicy: Qt.StrongFocus
    hoverEnabled: true

    Accessible.role: Accessible.ListItem
    Accessible.name: title

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    background: Item { }

    contentItem: Item {
        RdLibraryThumb {
            id: picture

            width: parent.width
            height: card.pictureHeight
            source: card.thumbnail
            iconName: card.iconName
            radius: VLCStyle.rd_radius_small
            progress: card.progress
            watched: card.watched
            playing: card.playing
            barInset: 0
        }

        Rectangle {
            anchors.fill: picture
            radius: picture.radius
            visible: card.hovered || card.visualFocus
            color: VLCStyle.palette.rdHoverOverlay
        }

        RdLibraryIconButton {
            anchors.right: picture.right
            anchors.top: picture.top
            anchors.margins: VLCStyle.dp(6)
            visible: card.showMore && (card.hovered || card.visualFocus || hovered)
            iconName: "more"
            description: qsTr("More")
            onClicked: card.moreClicked(this)
        }

        Text {
            id: titleText

            anchors.top: picture.bottom
            anchors.topMargin: VLCStyle.dp(8)
            width: parent.width
            text: card.title
            elide: Text.ElideRight
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: card.playing ? VLCStyle.palette.rdAccentMain
                 : (card.hovered || card.visualFocus) ? VLCStyle.palette.rdFg2
                 : card.watched ? VLCStyle.palette.rdFgA3
                 : VLCStyle.palette.rdFgA1
        }

        Text {
            id: subtitleText

            anchors.top: titleText.bottom
            anchors.topMargin: VLCStyle.dp(2)
            width: parent.width
            visible: card.subtitle !== ""
            text: card.subtitle
            elide: Text.ElideRight
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: VLCStyle.palette.rdFgA3
        }
    }

    Item {
        id: ghost

        parent: card.Window.contentItem
        visible: dragHandler.active
        width: VLCStyle.dp(337)
        height: VLCStyle.rd_rowHeight
        opacity: 0.5
        z: 1000

        Drag.active: dragHandler.active
        Drag.dragType: Drag.Internal
        Drag.hotSpot.x: VLCStyle.dp(16)
        Drag.hotSpot.y: height / 2
        Drag.keys: ["text/uri-list"]
        readonly property var rdDragUrls: card.dragUrls

        // created only while dragging: the rows do not load their picture twice
        Loader {
            anchors.fill: parent
            active: dragHandler.active

            sourceComponent: Row {
                spacing: VLCStyle.dp(10)

                RdLibraryThumb {
                    width: VLCStyle.dp(32)
                    height: VLCStyle.dp(32)
                    anchors.verticalCenter: parent.verticalCenter
                    source: card.thumbnail
                    iconName: card.iconName
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.title
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_label
                    color: VLCStyle.palette.rdFg1
                }
            }
        }
    }

    DragHandler {
        id: dragHandler

        enabled: card.dragUrls.length > 0
        target: null
        dragThreshold: VLCStyle.dp(8)

        onCentroidChanged: {
            if (!active || !ghost.parent)
                return
            const p = card.mapToItem(ghost.parent, centroid.position.x, centroid.position.y)
            ghost.x = p.x - ghost.Drag.hotSpot.x
            ghost.y = p.y - ghost.Drag.hotSpot.y
        }

        onActiveChanged: {
            if (!active)
                ghost.Drag.drop()
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.PointingHandCursor
    }
}
