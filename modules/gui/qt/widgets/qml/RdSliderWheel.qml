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

// redesign: mouse wheel fine-tuning of a slider (Decision 51). Over its area (the slider's bar and
// label row) one wheel notch is one step: `stepped(steps)`, positive to increase (wheel up or
// right; on a mirrored horizontal slider right decreases, like the arrow keys). Takes no clicks.
// The slider moves its value as for a drag or a key step (RdSliderCommit paces what reaches
// VLC); stepSlider(slider, steps) does it for a plain T.Slider.
// - High-resolution wheels and touchpads send fractions of a notch: they add up to whole steps
//   (angleDelta, 120 per notch; pixelDelta, `pixelsPerStep` per step, where only that is sent).
// - Every wheel event over the slider is taken, also at its ends, so the wheel never scrolls the
//   list or reaches the player behind it. Except: a wheel gesture that is scrolling a list (the
//   list still moving, or it scrolled or this slider let an event through less than `latch` ms
//   ago) keeps going to the list when the slider passes under the pointer; at the list's end the
//   panel takes it.
// - Natural scrolling reported by the system (`inverted`: macOS, Linux) is turned back to the
//   finger direction; on Windows a touchpad follows the scroll direction set in Windows, as for a
//   wheel.
import QtQuick

MouseArea {
    id: root

    // a mirrored horizontal slider (right to left)
    property bool mirrored: false
    // a scroll that only reports pixels: this many pixels make one step
    property real pixelsPerStep: 24
    // ms between two events of one wheel gesture
    property int latch: 400

    signal stepped(int steps)

    // notches not used yet (less than a step)
    property real _accum: 0
    property double _lastTaken: 0
    property double _lastPassed: 0
    // the list (Flickable) holding the slider and when it last scrolled
    property Item _list: null
    property double _listMovedAt: 0

    acceptedButtons: Qt.NoButton

    // moves a T.Slider `steps` times by its stepSize, as its arrow keys do (the value's binding
    // stays), and reports the move with its moved() signal
    function stepSlider(slider, steps) {
        const old = slider.value
        for (let i = 0; i < Math.abs(steps); ++i) {
            if (steps > 0)
                slider.increase()
            else
                slider.decrease()
        }
        if (slider.value !== old)
            slider.moved()
    }

    function _findList() {
        for (let p = root.parent; p; p = p.parent) {
            if (p.contentY !== undefined && p.moving !== undefined)
                return p
        }
        return null
    }

    Component.onCompleted: _list = _findList()
    onParentChanged: _list = _findList()

    Connections {
        target: root._list

        function onContentYChanged() {
            root._listMovedAt = Date.now()
        }
    }

    // a list holding the slider is scrolling
    function _listMoving() {
        for (let p = root.parent; p; p = p.parent) {
            if (p.moving === true)
                return true
        }
        return false
    }

    onWheel: (wheel) => {
        const now = Date.now()
        if (!_list)
            _list = _findList()
        if (now - _lastPassed < latch || now - _listMovedAt < latch || _listMoving()) {
            _lastPassed = now
            wheel.accepted = false
            return
        }
        wheel.accepted = true

        let x = wheel.angleDelta.x
        let y = wheel.angleDelta.y
        let unit = 120
        if (x === 0 && y === 0) {
            x = wheel.pixelDelta.x
            y = wheel.pixelDelta.y
            unit = pixelsPerStep
        }
        // natural scrolling (see above): back to the direction the fingers moved
        if (wheel.inverted) {
            x = -x
            y = -y
        }
        // up increases; a positive x is a scroll to the left
        const delta = Math.abs(y) >= Math.abs(x) ? y : (mirrored ? x : -x)
        if (delta === 0)
            return

        // a new gesture or a change of direction starts from a whole notch
        if (now - _lastTaken > latch || (delta > 0) !== (_accum > 0))
            _accum = 0
        _lastTaken = now

        _accum += delta / unit
        const steps = Math.trunc(_accum + (_accum > 0 ? 1e-6 : -1e-6))
        if (steps === 0)
            return
        _accum -= steps
        root.stepped(steps)
    }
}
