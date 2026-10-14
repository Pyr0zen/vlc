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
// redesign: Settings > Controls ("Mouse, Keyboard & Remote Controls", video 17:56-17:58, Figma
// "Settings - controls"); rows: BUILD_PLAN.md section 8, P8-08. "Edit Keyboard Shortcuts" opens
// the Keyboard Shortcuts dialog (W6.3) through settingsDialog.openExternal().
// Until its rows are mapped to VLC's options (W6.2), the page points to VLC's complete preferences.
import QtQuick

import VLC.Dialogs

SettingsPage {
    SettingsPlaceholder { }
}
