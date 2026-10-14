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
// playlists), Figma Player-3 / Player-5: radius 12, base #171717 (#1E1E1E for folders), a 20 %
// black layer over video pictures, a 48 px icon on square cards without a picture, the 4 px
// watched bar; 20 below it the title (Inter 400 16, FG/A1, FG/A3 once watched), 10 below that
// the artist (16, FG/A3) for songs and albums.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.MediaLibrary

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

    implicitWidth: VLCStyle.dp(316)
    implicitHeight: pictureHeight + VLCStyle.dp(20) + titleText.implicitHeight
                    + (subtitle !== "" ? subtitleText.implicitHeight + VLCStyle.dp(10) : 0)

    focusPolicy: Qt.StrongFocus
    hoverEnabled: true

    Accessible.role: Accessible.ListItem
    Accessible.name: title

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            card.clicked()
            event.accepted = true
            return
        }
        Navigation.defaultKeyAction(event)
    }

    // VLC's Navigation takes the arrows and Escape: the arrows walk the keyboard focus chain
    // and Escape goes back in the library, unless the view sets its own (RdLibraryPage's grid)
    Navigation.upAction: () => RdLibraryNav.focusStep(card, false)
    Navigation.downAction: () => RdLibraryNav.focusStep(card, true)
    Navigation.leftAction: () => RdLibraryNav.focusStep(card, false)
    Navigation.rightAction: () => RdLibraryNav.focusStep(card, true)
    Navigation.cancelAction: () => RdLibraryNav.goBack()

    background: Item { }

    contentItem: Item {
        RdLibraryThumb {
            id: picture

            width: parent.width
            height: card.pictureHeight
            source: card.thumbnail
            iconName: card.iconName
            iconSize: card.wide ? VLCStyle.rd_iconSize : VLCStyle.dp(48)
            radius: VLCStyle.rd_radius_card
            baseColor: card.iconName === "folder" ? VLCStyle.palette.rdFolderCardBase
                                                  : VLCStyle.palette.rdCardBase
            shaded: card.wide
            progress: card.progress
            watched: card.watched
            playing: card.playing
            barTrim: 0
            barHeight: VLCStyle.dp(4)
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
            anchors.topMargin: VLCStyle.dp(20)
            width: parent.width
            text: card.title
            elide: Text.ElideRight
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_header
            color: card.playing ? VLCStyle.palette.rdAccentMain
                 : (card.hovered || card.visualFocus) ? VLCStyle.palette.rdFg2
                 : card.watched ? VLCStyle.palette.rdFgA3
                 : VLCStyle.palette.rdFgA1
        }

        Text {
            id: subtitleText

            anchors.top: titleText.bottom
            anchors.topMargin: VLCStyle.dp(10)
            width: parent.width
            visible: card.subtitle !== ""
            text: card.subtitle
            elide: Text.ElideRight
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_header
            color: VLCStyle.palette.rdFgA3
        }
    }

    Item {
        id: ghost

        // over the whole window only while dragging (set by the drag handler)
        parent: card
        visible: dragHandler.active
        width: VLCStyle.dp(337)
        height: VLCStyle.rd_rowHeight
        opacity: 0.5
        z: 1000

        // started and dropped by the handler below (a binding could turn the drag off before
        // the drop, losing it)
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
        // as VLC's own list and grid items: touch flicks the list, the mouse drags; the drag
        // takes the press over from the row's button (an item), lists may take it over again
        acceptedDevices: PointerDevice.AllDevices & ~(PointerDevice.TouchScreen)
        grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.CanTakeOverFromHandlersOfDifferentType
                         | PointerHandler.ApprovesTakeOverByAnything
        target: null

        onCentroidChanged: {
            if (!active || !ghost.parent)
                return
            const p = card.mapToItem(ghost.parent, centroid.position.x, centroid.position.y)
            ghost.x = p.x - ghost.Drag.hotSpot.x
            ghost.y = p.y - ghost.Drag.hotSpot.y
        }

        onActiveChanged: {
            if (active) {
                ghost.parent = card.Window.contentItem
                ghost.Drag.active = true
            } else {
                ghost.Drag.drop()
                ghost.parent = card
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.PointingHandCursor
    }
}
