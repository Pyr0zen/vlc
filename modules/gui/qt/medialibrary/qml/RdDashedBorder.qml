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

// redesign: dashed border of the New Playlist drop zone (Figma "Frame 86": 2 px stroke, dashes
// 4 / 4; IB-30). VLC's Qt has no Shapes or Canvas, so the dashes are small rectangles along
// the edges (a static item, drawn once).
import QtQuick

import VLC.MainInterface
import VLC.Style

Item {
    id: root

    property color color: VLCStyle.palette.rdDividerBright
    property real lineWidth: VLCStyle.dp(2)
    property real dash: VLCStyle.dp(4)
    property real gap: VLCStyle.dp(4)

    readonly property real _step: dash + gap

    Repeater {
        model: Math.max(0, Math.floor(root.width / root._step))

        delegate: Item {
            required property int index

            Rectangle {
                x: index * root._step
                width: root.dash
                height: root.lineWidth
                color: root.color
            }

            Rectangle {
                x: index * root._step
                y: root.height - root.lineWidth
                width: root.dash
                height: root.lineWidth
                color: root.color
            }
        }
    }

    Repeater {
        model: Math.max(0, Math.floor(root.height / root._step))

        delegate: Item {
            required property int index

            Rectangle {
                y: index * root._step
                width: root.lineWidth
                height: root.dash
                color: root.color
            }

            Rectangle {
                x: root.width - root.lineWidth
                y: index * root._step
                width: root.lineWidth
                height: root.dash
                color: root.color
            }
        }
    }
}
