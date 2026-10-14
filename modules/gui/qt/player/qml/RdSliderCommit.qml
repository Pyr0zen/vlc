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

// redesign: passes a settings slider's value on to VLC at a pace VLC can take (UX logic rule:
// dragging must never stall playback). While the slider is dragged the moved value is shown at
// once and committed at most every `dragInterval` ms (-1: only when the slider is released);
// key steps are committed `keyDelay` ms after the last one. The last commit of a gesture (on
// release, after the key steps) is `last` and is sent even if that value was committed while
// dragging. `shown` is the value to display: the value being moved, then VLC's value once it has
// caught up (no jump back on release).
//
//     readonly property RdSliderCommit delay: RdSliderCommit {
//         pressed: delaySlider.pressed
//         current: Player.audioDelayMS / 1000
//         onCommit: (v) => Player.audioDelayMS = Math.round(v * 1000)
//     }
//     RdParamSlider { id: delaySlider; value: delay.shown; onMoved: (v) => delay.push(v) }
import QtQuick

QtObject {
    id: root

    // the slider is held down
    property bool pressed: false
    // the value as VLC has it
    property real current: 0
    // ms between two commits while dragging, -1 to commit only on release
    property int dragInterval: -1
    // ms after the last key step
    property int keyDelay: 300
    // two values closer than this are the same (VLC rounds what it stores)
    property real tolerance: 0.0005

    property real pending: 0
    property bool holding: false

    readonly property real shown: holding ? pending : current

    signal commit(real value, bool last)

    function push(value) {
        pending = value
        holding = true
        _dirty = true
        _settleTimer.stop()
        if (pressed) {
            if (dragInterval >= 0 && !_applyTimer.running) {
                _applyTimer.interval = dragInterval
                _applyTimer.start()
            }
        } else if (keyDelay <= 0) {
            flush()
        } else {
            _applyTimer.interval = keyDelay
            _applyTimer.restart()
        }
    }

    // ends the gesture: commits the value moved last
    function flush() {
        _applyTimer.stop()
        if (!holding)
            return
        _dirty = false
        commit(pending, true)
        _settleTimer.restart()
    }

    property bool _dirty: false

    readonly property Timer _applyTimer: Timer {
        repeat: false
        onTriggered: {
            if (root.pressed) {
                if (root._dirty) {
                    root._dirty = false
                    root.commit(root.pending, false)
                }
            } else {
                root.flush()
            }
        }
    }

    // VLC reports the committed value asynchronously: keep showing it until then
    readonly property Timer _settleTimer: Timer {
        interval: 1000
        onTriggered: root.holding = false
    }

    onPressedChanged: {
        if (!pressed)
            flush()
    }

    onCurrentChanged: {
        if (holding && !pressed && !_dirty && Math.abs(current - pending) <= tolerance) {
            _settleTimer.stop()
            holding = false
        }
    }
}
