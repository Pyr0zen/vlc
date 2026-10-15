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
// redesign: the seek bar preview card (P2-04 / IA-14, video 3:24-3:31, Figma "thumbnail"):
// a frame of the hovered position with its time under it. It opens and moves without
// animation (Figma prototype: "open overlay", instant). Display only: it takes no input.
import QtQuick

import VLC.Style
import VLC.Widgets as Widgets

Rectangle {
    id: root

    // the frame (an "image://rdseekthumb/..." URL), empty while none is ready
    property url source
    property string timeText: ""

    implicitWidth: VLCStyle.rd_seekPreviewPictureWidth + 2 * VLCStyle.rd_seekPreviewPadding
    implicitHeight: VLCStyle.rd_seekPreviewPadding + VLCStyle.rd_seekPreviewPictureHeight
                    + VLCStyle.rd_seekPreviewSpacing + VLCStyle.rd_seekPreviewTimeHeight
                    + VLCStyle.rd_seekPreviewPadding

    radius: VLCStyle.rd_radius_large
    // Figma BG/A3 Transparent (95 %, background blur 50), opaque like the other popups
    color: Qt.alpha(VLCStyle.palette.rdBgA3Transparent, 1.0)

    enabled: false

    // Figma "Frame 244": 252x142, radius 4; a frame of another shape is fitted inside it, the
    // rest (and the whole area until the first frame is ready) is the video background
    Rectangle {
        id: picture

        x: VLCStyle.rd_seekPreviewPadding
        y: VLCStyle.rd_seekPreviewPadding
        width: VLCStyle.rd_seekPreviewPictureWidth
        height: VLCStyle.rd_seekPreviewPictureHeight

        radius: VLCStyle.rd_radius_small
        color: VLCStyle.palette.rdBgB2

        Widgets.ImageExt {
            anchors.fill: parent

            visible: root.source.toString() !== ""
            source: root.source
            // the frame is already in memory: no loading state, no flicker between frames
            asynchronous: false
            // the thumbnailer keeps its own cache
            cache: false
            fillMode: Image.PreserveAspectFit
            radius: VLCStyle.rd_radius_small
        }
    }

    // Figma "00:02:10": Inter 400 15, FG/A2, centered under the picture
    Text {
        x: VLCStyle.rd_seekPreviewPadding
        y: picture.y + picture.height + VLCStyle.rd_seekPreviewSpacing
        width: picture.width
        height: VLCStyle.rd_seekPreviewTimeHeight

        text: root.timeText
        color: VLCStyle.palette.rdFgA2
        font.family: VLCStyle.rd_fontFamily
        font.pixelSize: VLCStyle.rd_fontSize_time
        font.weight: Font.Normal
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
