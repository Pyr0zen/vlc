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
// redesign: the last section of a page's Advanced Options: every other VLC option of the
// category, grouped by plugin (W6.2; video 16:03-16:30: "basic settings, scroll down, advanced
// settings" on the same page, so no option of VLC needs the old preferences). The options come
// from SettingsCatalog (VLC's own category of each option); the ones the page shows by name are
// left out. Built once, in the background, when Advanced Options first opens or the dialog's
// search first runs; the settings of a plugin are created when it is opened.
import QtQuick
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style
import VLC.Dialogs

SettingsSection {
    id: root

    // SettingsCatalog category ("general", "audio", ...)
    required property string category

    // once built, it stays: closing Advanced Options or clearing the search must not rebuild it
    property bool _wanted: false
    readonly property bool _requested: !!_page && (_page.advancedExpanded || _page.filtering)
    on_RequestedChanged: _build()
    // the page may be created while the search runs
    Component.onCompleted: Qt.callLater(_build)

    function _build() {
        if (!_requested || _wanted)
            return
        _wanted = true
        SettingsCatalog.load()
    }

    title: qsTr("All Other Options")
    keywords: qsTr("plugins modules")

    // nothing left to show for this category
    readonly property bool _empty: groupsLoader.status === Loader.Ready && groupsLoader.item.count === 0
    // SettingsSection decides while the search runs
    Binding on visible {
        when: root._empty
        value: false
    }

    Loader {
        id: groupsLoader

        Layout.fillWidth: true
        active: root._wanted && SettingsCatalog.ready
        asynchronous: true

        sourceComponent: Column {
            readonly property int count: groups.count

            Repeater {
                id: groups

                model: SettingsCatalog.groups(root.category)

                delegate: SettingsOptionGroup {
                    required property var modelData

                    width: root.width
                    group: modelData
                }
            }
        }
    }
}
