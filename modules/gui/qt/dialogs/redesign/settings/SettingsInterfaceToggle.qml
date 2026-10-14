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
// redesign: a Settings toggle that starts one of VLC's extra interfaces with VLC (Last.fm
// submission, the web remote control), as VLC's preferences do it (src/config/intf.c
// config_AddIntf / config_RemoveIntf): ON adds the module to "extraintf", OFF removes it from
// "extraintf" and "control" (colon-separated lists).
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Dialogs

SettingsRow {
    id: root

    // VLC's module name ("audioscrobbler", "http")
    required property string module

    readonly property var _extra: _split(RdEffects.values[RdEffects.optionKey("extraintf")])
    readonly property var _control: _split(RdEffects.values[RdEffects.optionKey("control")])
    readonly property bool checked: _extra.indexOf(module) >= 0 || _control.indexOf(module) >= 0

    function _split(value) {
        return String(value ?? "").split(":").filter((m) => m !== "")
    }

    function _set(enabled) {
        if (enabled) {
            if (!checked)
                RdEffects.setOption("extraintf", _extra.concat([module]).join(":"))
            return
        }
        if (_extra.indexOf(module) >= 0)
            RdEffects.setOption("extraintf", _extra.filter((m) => m !== module).join(":"))
        if (_control.indexOf(module) >= 0)
            RdEffects.setOption("control", _control.filter((m) => m !== module).join(":"))
    }

    keywords: module + " extraintf"

    Widgets.RdToggle {
        checked: root.checked
        Accessible.name: root.text
        onToggled: root._set(checked)
    }
}
