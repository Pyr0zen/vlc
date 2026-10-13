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

// redesign: the picture of a library row or card (F-13, IB-06, IB-14, IB-22, IB-34): the
// thumbnail or cover cropped to its box with a small radius, or the item's icon; the orange
// watched bar along the bottom of the picture (full width once watched, the watched part while
// in progress; video 10:57, 11:41); the darkened picture with an orange play triangle for the
// file that is playing (11:41).
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

Item {
    id: root

    property url source: ""
    // shown instead of a picture, and while it loads
    property string iconName: ""
    property real iconSize: VLCStyle.rd_iconSize
    // picture box: false = the icon alone (folder, playlist, artist rows)
    property bool boxed: true
    property real radius: VLCStyle.rd_radius_xsmall
    property real progress: -1
    property bool watched: false
    property bool playing: false
    // the watched bar is inset like the Figma row thumbnail (28x3 in a 32x32 box)
    property real barInset: VLCStyle.dp(2)
    property real barHeight: VLCStyle.dp(3)

    readonly property bool _hasPicture: source.toString() !== "" && picture.status === Image.Ready

    Rectangle {
        anchors.fill: parent
        visible: root.boxed
        radius: root.radius
        color: VLCStyle.palette.rdBgA1
        clip: true

        Image {
            id: picture

            anchors.fill: parent
            source: root.source
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
            visible: status === Image.Ready
        }

        Rectangle {
            anchors.fill: parent
            visible: root.playing
            color: VLCStyle.palette.rdBgB2Transparent
        }
    }

    Widgets.RdIcon {
        anchors.centerIn: parent
        visible: !root._hasPicture && root.iconName !== "" && !root.playing
        name: root.iconName
        size: root.iconSize
        color: VLCStyle.palette.rdFgA2
    }

    Widgets.RdIcon {
        anchors.centerIn: parent
        visible: root.playing
        name: "playback_two-tone-yes"
        size: Math.min(VLCStyle.rd_iconSize, root.height)
        color: VLCStyle.palette.rdAccentMain
        color2: VLCStyle.palette.rdAccentMain
    }

    Rectangle {
        readonly property real fraction: root.progress >= 0 ? root.progress : (root.watched ? 1 : 0)

        visible: fraction > 0 && root.boxed
        x: root.barInset
        anchors.bottom: parent.bottom
        width: (root.width - 2 * root.barInset) * fraction
        height: root.barHeight
        radius: root.barHeight / 2
        color: VLCStyle.palette.rdAccentMain
    }
}
