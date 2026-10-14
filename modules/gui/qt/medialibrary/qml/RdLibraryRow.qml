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

// redesign: a library list row (Figma "media" and "playlist" components, 337x32, gap 10,
// F-13; video 11:40-11:59, IB-14): a 32x32 picture or icon, the title in Inter 14. Unwatched
// titles FG/A1, watched FG/A3, the playing file in accent; hovering brightens the title to
// FG/2 and shows a "..." button at the end of the row (no row background). Media rows can be
// dragged to the queue (11:44, IB-15): the ghost is the row content only, semi-transparent.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

T.AbstractButton {
    id: row

    property string title: ""
    property string iconName: ""
    property url thumbnail: ""
    property bool boxed: true
    property real progress: -1
    property bool watched: false
    property bool playing: false
    // containers and action rows ("+ Add") use the secondary text color
    property bool secondary: false
    property bool showMore: true
    // drag to the queue: URLs of the dragged media, empty for rows that cannot be dragged
    property var dragUrls: []

    signal moreClicked(Item button)

    implicitWidth: VLCStyle.dp(337)
    implicitHeight: VLCStyle.rd_rowHeight

    focusPolicy: Qt.StrongFocus
    hoverEnabled: true

    Accessible.role: Accessible.ListItem
    Accessible.name: title

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    background: Item { }

    contentItem: Item {
        Row {
            id: content

            anchors.fill: parent
            spacing: VLCStyle.dp(10)

            RdLibraryThumb {
                id: thumb

                width: VLCStyle.dp(32)
                height: VLCStyle.dp(32)
                anchors.verticalCenter: parent.verticalCenter
                source: row.thumbnail
                iconName: row.iconName
                boxed: row.boxed
                progress: row.progress
                watched: row.watched
                playing: row.playing
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: content.width - thumb.width - content.spacing
                       - (moreButton.visible ? moreButton.width + content.spacing : 0)
                text: row.title
                elide: Text.ElideRight
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: row.playing ? VLCStyle.palette.rdAccentMain
                     : (row.hovered || row.visualFocus) ? VLCStyle.palette.rdFg2
                     : row.watched ? VLCStyle.palette.rdFgA3
                     : row.secondary ? VLCStyle.palette.rdFgA2
                     : VLCStyle.palette.rdFgA1
            }
        }

        RdLibraryIconButton {
            id: moreButton

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: row.showMore && (row.hovered || row.visualFocus || hovered)
            iconName: "more"
            description: qsTr("More")
            showHoverBackground: false
            onClicked: row.moreClicked(moreButton)
        }
    }

    // drag to the queue
    Item {
        id: ghost

        parent: row.Window.contentItem
        visible: dragHandler.active
        width: row.width
        height: row.height
        opacity: 0.5
        z: 1000

        Drag.active: dragHandler.active
        Drag.dragType: Drag.Internal
        Drag.hotSpot.x: VLCStyle.dp(16)
        Drag.hotSpot.y: height / 2
        Drag.keys: ["text/uri-list"]
        // read by the drop areas of the queue (RdQueueDropArea)
        readonly property var rdDragUrls: row.dragUrls

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
                    source: row.thumbnail
                    iconName: row.iconName
                    boxed: row.boxed
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.title
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_label
                    color: VLCStyle.palette.rdFg1
                }
            }
        }
    }

    DragHandler {
        id: dragHandler

        enabled: row.dragUrls.length > 0
        target: null
        dragThreshold: VLCStyle.dp(8)

        onCentroidChanged: {
            if (!active || !ghost.parent)
                return
            const p = row.mapToItem(ghost.parent, centroid.position.x, centroid.position.y)
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
