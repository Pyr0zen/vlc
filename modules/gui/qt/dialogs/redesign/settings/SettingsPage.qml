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
// redesign: base of every category page of the Settings dialog (video 16:03-16:30 "basic
// settings, scroll down, advanced settings"; Figma "Settings - *" content column: sections
// 20 px apart, then the "Advanced Options" bar, then the advanced sections).
//
// Page API (W6.2 fills the 13 pages with it):
//   SettingsPage {
//       SettingsSection { title: qsTr("Loading Subtitles")
//           SettingsRow { text: qsTr("..."); description: ...; available: <parent setting on>
//                         Widgets.RdToggle { ... } }
//       }
//       advanced: [ SettingsSection { ... } ]     // optional; adds the Advanced Options bar
//   }
// The dialog sets `filterText` (search) and `settingsDialog`; rows and sections register
// themselves, so the dialog knows which pages match a search without any extra index.
import QtQuick
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style

ColumnLayout {
    id: root

    default property alias content: basic.data
    property alias advanced: advancedArea.data
    property bool advancedExpanded: false

    // set by the dialog
    property string filterText: ""
    property Item settingsDialog: null

    readonly property bool isSettingsPage: true
    readonly property bool filtering: _words.length > 0
    readonly property bool hasAdvanced: advancedArea.children.length > 0
    readonly property bool advancedShown: hasAdvanced
                                          && (advancedExpanded || (filtering && advancedMatchCount > 0))
    // rows shown by the current search (all rows without a search); counted once per change of
    // the search or of the rows (recount()), not in a binding that every row's `matches` would
    // re-run: with a few hundred rows that was quadratic on each keystroke
    readonly property int matchCount: _basicMatchCount + advancedMatchCount
    property int advancedMatchCount: 0
    property int _basicMatchCount: 0

    readonly property var _words: filterText.toLowerCase().split(/\s+/).filter((w) => w !== "")
    // plain arrays changed in place: a page or a plugin that opens registers its rows in bulk
    readonly property var _rows: []
    readonly property var _advancedRows: []

    // true when every word of the search appears in one of the texts
    function textMatches(texts) {
        if (_words.length === 0)
            return true
        const haystack = texts.join(" ").toLowerCase()
        return _words.every((w) => haystack.includes(w))
    }

    function registerRow(row) {
        (_isAdvanced(row) ? _advancedRows : _rows).push(row)
        recount()
    }

    function unregisterRow(row) {
        for (const rows of [_rows, _advancedRows]) {
            const i = rows.indexOf(row)
            if (i >= 0)
                rows.splice(i, 1)
        }
        recount()
    }

    // asks for the counts again, once for every change made in the same pass
    function recount() {
        Qt.callLater(_recount)
    }

    function _recount() {
        _basicMatchCount = _count(_rows)
        advancedMatchCount = _count(_advancedRows)
    }

    onFilterTextChanged: recount()

    function _isAdvanced(item) {
        for (let p = item.parent; p && p !== root; p = p.parent) {
            if (p === advancedArea)
                return true
        }
        return false
    }

    function _count(rows) {
        let n = 0
        for (const row of rows) {
            if (row && row.shown && row.matches)
                ++n
        }
        return n
    }

    spacing: VLCStyle.dp(20)

    ColumnLayout {
        id: basic

        Layout.fillWidth: true
        spacing: VLCStyle.dp(20)
    }

    SettingsAdvancedBar {
        visible: root.hasAdvanced && (!root.filtering || root.advancedMatchCount > 0)
        Layout.fillWidth: true
        expanded: root.advancedShown
        onClicked: root.advancedExpanded = !root.advancedShown
    }

    ColumnLayout {
        id: advancedArea

        visible: root.advancedShown
        Layout.fillWidth: true
        spacing: VLCStyle.dp(20)
    }
}
