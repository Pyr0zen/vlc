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

// redesign: the sleep timer of the settings sidebar's Playback tab (video 9:11-9:13, P4-34;
// Decision 23): Off, 15 / 30 / 45 / 60 minutes or the end of the current file. When it fires,
// playback stops and the timer goes back to Off. The choice is kept while VLC runs (it is not
// saved). Nothing runs while it is Off: a minute choice uses one single-shot timer, the end of
// the file uses the play queue's "stop after the current media" action (VLC's play-and-stop).
pragma Singleton

import QtQml

import VLC.Player
import VLC.Playlist

QtObject {
    id: root

    // the choices, in the dropdown's order: 0 = Off, 1 to 4 = minutes, 5 = end of the file
    readonly property var minuteChoices: [0, 15, 30, 45, 60]
    readonly property int endOfFile: 5

    // the current choice (an index into the choices above)
    readonly property int choice: _choice
    // a minute choice is counting down
    readonly property bool counting: _choice > 0 && _choice < endOfFile
    // when the countdown ends, in ms since the epoch (0 when it does not count down)
    readonly property double deadline: _deadline

    function set(index) {
        if (index === endOfFile && _choice === endOfFile)
            return

        _leaveEndOfFile()
        _countdown.stop()
        _deadline = 0
        _choice = index

        if (counting) {
            _deadline = Date.now() + minuteChoices[index] * 60000
            _countdown.interval = minuteChoices[index] * 60000
            _countdown.start()
        } else if (index === endOfFile) {
            _savedStopAction = MainPlaylistController.mediaStopAction
            _ownsStopAction = true
            MainPlaylistController.mediaStopAction = PlaylistController.MEDIA_STOPPED_STOP
        }
    }

    property int _choice: 0
    property double _deadline: 0

    // the play queue's action after a media before "End of current file" replaced it, given
    // back when the timer ends unless another setting changed it meanwhile
    property int _savedStopAction: PlaylistController.MEDIA_STOPPED_CONTINUE
    property bool _ownsStopAction: false

    function _leaveEndOfFile() {
        if (!_ownsStopAction)
            return
        _ownsStopAction = false
        MainPlaylistController.mediaStopAction = _savedStopAction
    }

    function _finish() {
        _leaveEndOfFile()
        _countdown.stop()
        _deadline = 0
        _choice = 0
    }

    property Timer _countdown: Timer {
        repeat: false

        onTriggered: {
            // a long single-shot timer may fire a little early: wait for the rest
            const rest = root._deadline - Date.now()
            if (rest > 500) {
                interval = rest
                start()
                return
            }
            root._finish()
            MainPlaylistController.stop()
        }
    }

    // "End of current file": the play queue stops after the media instead of going on, and
    // the player reports that it stopped (also when the user stops it)
    property Connections _player: Connections {
        target: Player
        enabled: root._choice === root.endOfFile

        function onPlayingStateChanged() {
            if (Player.playingState === Player.PLAYING_STATE_STOPPED)
                root._finish()
        }
    }

    // another setting (Quit at the end of the play queue, the Settings dialog) changed the
    // action after a media: it wins over the timer
    property Connections _queue: Connections {
        target: MainPlaylistController
        enabled: root._choice === root.endOfFile

        function onMediaStopActionChanged() {
            if (MainPlaylistController.mediaStopAction !== PlaylistController.MEDIA_STOPPED_STOP) {
                root._ownsStopAction = false
                root._finish()
            }
        }
    }
}
