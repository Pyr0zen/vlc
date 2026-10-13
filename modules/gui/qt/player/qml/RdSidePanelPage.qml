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

// redesign: one page of the right sidebar (RdSidePanel). The content scrolls vertically;
// sections are separated by 1 px Divider/Dim lines (video 8:29, IA-36). The page fades in and
// out when its tab is selected (video 8:40).
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

Flickable {
    id: root

    required property string key
    default property alias content: column.data

    readonly property bool active: !!parent && parent.currentKey === key

    anchors.fill: parent

    opacity: active ? 1 : 0
    visible: opacity > 0
    enabled: active

    Behavior on opacity {
        NumberAnimation {
            duration: VLCStyle.duration_short
            easing.type: Easing.InOutSine
        }
    }

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    contentWidth: width
    contentHeight: column.implicitHeight

    T.ScrollBar.vertical: Widgets.ScrollBarExt { }

    ColumnLayout {
        id: column

        width: root.width
        spacing: 0
    }
}
