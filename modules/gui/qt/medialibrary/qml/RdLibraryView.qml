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

// redesign: the full-window library (video 10:12-10:59, 11:48-11:56, 13:48-13:55, 20:08-20:19,
// 20:52-20:59; P5-06, P5-26, P6-21, P8-33, IB-47): the rail with labels on the left; on the right
// one header row (back, forward, address line | count, sort, view, search field, "...") over a
// thin divider, and the page in grid or list view. Same places as the compact library.
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.MediaLibrary

FocusScope {
    id: root

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Library")

    // space kept free at the bottom for the mini player
    property real bottomInset: 0
    // the header and its divider, which the mini player keeps clear of
    readonly property real headerHeight: main.y + divider.y + divider.height

    // the mini player's folder chip: the folder of the playing file
    function revealMrl(mrl) {
        if (!mrl)
            return
        RdLibraryStore.resolveFolder(mrl, (result) => {
            if (result)
                RdLibraryNav.openFolderPath(result)
        })
    }

    // the swipe-back gesture (MainInterface.qml) only goes back when there is somewhere to go
    readonly property bool canGoBack: RdLibraryNav.canGoBack

    // mouse back and forward buttons
    function goBack() {
        RdLibraryNav.goBack()
    }

    function goForward() {
        RdLibraryNav.goForward()
    }

    // Ctrl+F
    function focusSearch() {
        header.focusSearch()
    }

    Rectangle {
        anchors.fill: parent
        color: VLCStyle.palette.rdBgB1
    }

    RdLibraryRail {
        id: rail

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        showLabels: true
    }

    Item {
        id: main

        anchors.left: rail.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        RdLibraryHeader {
            id: header

            // Figma "Frame 20" (Player-1..5): padding 20
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: VLCStyle.dp(20)
            anchors.rightMargin: VLCStyle.dp(20)
            anchors.topMargin: VLCStyle.dp(20)

            compact: false
            page: content.page
        }

        Rectangle {
            id: divider

            anchors.left: header.left
            anchors.right: header.right
            // Figma: 17 below the header
            anchors.top: header.bottom
            anchors.topMargin: VLCStyle.dp(17)
            height: VLCStyle.dp(1)
            color: VLCStyle.palette.rdDividerDim
        }

        RdLibraryContent {
            id: content

            anchors.left: header.left
            anchors.right: header.right
            // Figma: the content starts 20 below the divider's line (17 + 20 below the header)
            anchors.top: divider.top
            anchors.topMargin: VLCStyle.dp(20)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.bottomInset

            compact: false
            focus: true
        }
    }
}
