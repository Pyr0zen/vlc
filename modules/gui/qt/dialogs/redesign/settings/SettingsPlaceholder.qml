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
// redesign: stand-in for the settings of a category page until its rows are mapped to VLC's
// options (BUILD_PLAN.md W6.2): points to VLC's complete preferences, where every option stays
// reachable. Hidden while the dialog's search is active.
import QtQuick
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

ColumnLayout {
    id: root

    property string text: qsTr("The settings of this category are moving here. Until then, they are in All VLC Settings.")

    property Item _page: null

    visible: !_page || !_page.filtering
    Layout.fillWidth: true
    spacing: VLCStyle.dp(12)

    Component.onCompleted: {
        for (let item = root.parent; item; item = item.parent) {
            if (item.isSettingsPage === true) {
                root._page = item
                break
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: VLCStyle.dp(10)
        text: root.text
        wrapMode: Text.WordWrap
        font.family: VLCStyle.rd_fontFamily
        font.pixelSize: VLCStyle.rd_fontSize_label
        color: VLCStyle.palette.rdFgA3
    }

    Widgets.RdButton {
        text: qsTr("All VLC Settings")
        enabled: !!root._page && !!root._page.settingsDialog
        onClicked: root._page.settingsDialog.openLegacyPreferences()
    }
}
