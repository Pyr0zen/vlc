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
// redesign: the segmented control of the Settings rows (Theme, Size values, sensitivity; Figma
// "Values", 320x36) that the keyboard can reach too: Tab focuses it, Left / Right choose the
// previous / next value. The look is the kit's (Widgets.RdSegmented).
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

FocusScope {
    id: root

    property alias model: segmented.model
    property alias currentIndex: segmented.currentIndex
    signal activated(int index)

    implicitWidth: VLCStyle.dp(320)
    implicitHeight: VLCStyle.dp(36)

    activeFocusOnTab: true

    Accessible.role: Accessible.PageTabList

    Keys.onLeftPressed: {
        if (currentIndex > 0)
            activated(currentIndex - 1)
    }
    Keys.onRightPressed: {
        if (currentIndex < model.length - 1)
            activated(currentIndex + 1)
    }

    Widgets.RdSegmented {
        id: segmented

        anchors.fill: parent
        onActivated: (index) => root.activated(index)
    }

    // keyboard focus
    Rectangle {
        anchors.fill: parent
        radius: VLCStyle.rd_radius_normal
        color: "transparent"
        visible: root.activeFocus
        border.width: VLCStyle.dp(1)
        border.color: VLCStyle.palette.rdFgA3
    }
}
