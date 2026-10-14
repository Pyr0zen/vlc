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

// Redesign menu panel (Figma "menu", "folder context menu", "Sorting Options" ...):
// BG/A3 95%, radius 10, padding 4, effect "bg blur + shadow". Put RdOptionRow and RdMenuDivider
// items inside; the panel closes when an option is clicked (closeOnClick).
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style

T.Popup {
    id: control

    default property alias items: column.data
    property bool closeOnClick: true
    property bool withShadow: true

    readonly property SystemPalette rdPalette: VLCStyle.palette

    implicitWidth: VLCStyle.rd_menuWidth
    implicitHeight: column.implicitHeight + topPadding + bottomPadding

    padding: VLCStyle.dp(4)

    modal: false
    focus: true
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutsideParent

    // as RdCascadeMenu: fades in (video 5:08, 60 fps), closes at once
    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: VLCStyle.rd_menuFadeDuration
            easing.type: Easing.OutQuad
        }
    }

    contentItem: Column {
        id: column

        width: control.availableWidth

        property var _connected: []

        onChildrenChanged: {
            // rows of a Repeater are destroyed and recreated: forget the ones that are gone (a
            // destroyed object's wrapper stays truthy in a JS array)
            _connected = _connected.filter((c) => Array.prototype.indexOf.call(children, c) >= 0)
            for (let i = 0; i < children.length; ++i) {
                const child = children[i]
                if (child.clicked !== undefined && _connected.indexOf(child) < 0) {
                    _connected.push(child)
                    child.clicked.connect(() => { if (control.closeOnClick && !child.hasSubmenu) control.close() })
                }
                if (child.width !== undefined)
                    child.width = Qt.binding(() => column.width)
            }
        }
    }

    background: Rectangle {
        radius: VLCStyle.rd_radius_panel
        // opaque over the native video (Figma's 95 % assumes a background blur)
        color: Qt.alpha(control.rdPalette.rdBgA3Transparent, 1.0)

        RdShadow {
            visible: control.withShadow
        }
    }
}
