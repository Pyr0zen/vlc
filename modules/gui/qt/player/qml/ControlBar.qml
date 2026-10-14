/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
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

import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import QtQml.Models


import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.Util

T.Pane {
    id: root

    enum TimeTextPosition {
        Hide,
        AboveSlider,
        LeftRightSlider,
        // redesign: one 54 px row, the seek row sits between the left and right controls
        Inline
    }

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    // redesign: the inline row has no slider row above it, so the background covers the whole
    // 54 px bar (Figma "Controls": padding 11 inside the background, visual audit A1)
    topInset: textPosition === ControlBar.TimeTextPosition.Inline ? 0 : sliderY

    bottomPadding: VLCStyle.margin_xsmall

    readonly property real sliderY: mapFromItem(contentItem, 0, contentItem.sliderY).y
    property int textPosition: ControlBar.TimeTextPosition.AboveSlider
    property int identifier: -1
    property real sliderHeight: VLCStyle.heightBar_xxsmall
    property real bookmarksHeight: VLCStyle.controlBarBookmarksHeight
    property bool showRemainingTime: true

    property var menu: undefined

    signal requestLockUnlockAutoHide(bool lock)

    ///incomming signal to request all menu and popup to close
    signal forceUnlock()

    enabled: visible

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => root.Navigation.defaultKeyAction(event)
    Navigation.cancelAction: function() { History.previous(Qt.BacktabFocusReason) }

    Accessible.name: qsTr("Player controls")
    AccessibleCompat.id: "playerControlBar"

    function showChapterMarks() {
        if (contentItem.trackPositionSlider)
            contentItem.trackPositionSlider.showChapterMarks()
    }

    function applyMenu(menu) {
        if (root.menu === menu)
            return

        // NOTE: When applying a new menu we hide the previous one.
        if (menu)
            dismiss()

        root.menu = menu
    }

    function dismiss() {
        if ((typeof menu === undefined) || !menu)
            return
        if (menu.hasOwnProperty("dismiss"))
            menu.dismiss()
        else if (menu.hasOwnProperty("close"))
            menu.close()
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    TextMetrics {
        id: timeTextMetrics
        // redesign: Figma "Current Time" / "Duration": Inter 400 15
        font.pixelSize: (textPosition === ControlBar.TimeTextPosition.LeftRightSlider) ? VLCStyle.fontSize_small
                      : (textPosition === ControlBar.TimeTextPosition.Inline) ? VLCStyle.rd_fontSize_time
                                                                               : VLCStyle.fontSize_normal
        text: {
            // This text metrics is used for both the time and length, as we want them to have the same width.
            // Length might not be reported in some cases, for that reason we should check both and use the bigger one.

            // Some extra space to compensate non-monospaced fonts ("-" takes more space than ":", double "-" for guarantee)
            return (Player.time.isSubHour() && Player.length.isSubHour()) ? "00--00" : "00--00--00"
        }
    }

    // redesign: seek row (time, thick seek bar, duration) shown inside the controls row;
    // PlayerControlLayout moves it into its middle slot
    readonly property Item inlineSeekRow: inlineSeekRowItem

    // redesign: narrow window. The right controls are hidden first (from the queue button
    // inwards, VLC's ControlRepeater rule) while the seek row keeps both times; when even the
    // room left with no right control is too small, the duration goes, then the current time.
    // The seek bar itself never gets narrower than rd_seekBarMinimumWidth.
    readonly property real _inlineSpacing: VLCStyle.dp(8, VLCStyle.scale)
    readonly property real _inlineTimeSlot: VLCStyle.rd_timeLabelWidth + _inlineSpacing
    readonly property bool _inlineShowsTime: playerControlLayout.middleRoom >= VLCStyle.rd_seekBarMinimumWidth + _inlineTimeSlot
    readonly property bool _inlineShowsLength: playerControlLayout.middleRoom >= VLCStyle.rd_seekBarMinimumWidth + 2 * _inlineTimeSlot

    // redesign: Figma "Controls": BG/A3, no stroke (the 1 px top line was not in the design)
    background: Rectangle {
        color: root.textPosition === ControlBar.TimeTextPosition.Inline ? VLCStyle.palette.rdBgA3Transparent
                                                                         : theme.bg.primary
    }

    // keeps the seek row in the control bar's item tree (it inherits the colors from it) without
    // being managed by a layout before it is moved into the middle slot
    Item {
        visible: false

        RowLayout {
            id: inlineSeekRowItem

            visible: root.textPosition === ControlBar.TimeTextPosition.Inline
            spacing: root._inlineSpacing
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            width: parent ? parent.width : 0
            height: VLCStyle.rd_seekBarHeight

            children: (root.textPosition === ControlBar.TimeTextPosition.Inline) ? [mediaTime, trackPositionSlider, mediaRemainingTime] : []
        }
    }

    contentItem: ColumnLayout {
        spacing: VLCStyle.margin_xsmall

        readonly property real sliderY: row2.y

        property alias trackPositionSlider: trackPositionSlider

        property alias mediaRemainingTime: mediaRemainingTime

        property alias playerControlLayout: playerControlLayout

        readonly property list<Item> strayItems: [
            T.Label {
                id: mediaTime

                Layout.preferredWidth: (textPosition === ControlBar.TimeTextPosition.Inline) ? VLCStyle.rd_timeLabelWidth
                                     : (textPosition === ControlBar.TimeTextPosition.LeftRightSlider) ? timeTextMetrics.width : -1
                // redesign: Figma "Current Time" is a fixed 76 px box, the text centered in it
                Layout.minimumWidth: (textPosition === ControlBar.TimeTextPosition.Inline) ? VLCStyle.rd_timeLabelWidth : -1
                Layout.preferredHeight: (textPosition === ControlBar.TimeTextPosition.Inline) ? VLCStyle.rd_seekBarHeight : -1
                verticalAlignment: Text.AlignVCenter

                visible: (textPosition !== ControlBar.TimeTextPosition.Inline) || root._inlineShowsTime

                text: {
                    const length = Player.length
                    if (textPosition === ControlBar.TimeTextPosition.Inline)
                        return Player.time.formatHHMMSS()
                    return Player.time.formatHMS(length.isSubSecond() ? VLCTick.SubSecondFormattedAsMS : 0)
                }
                color: mediaTime.editing ? "transparent"
                       : (textPosition === ControlBar.TimeTextPosition.Inline) ? VLCStyle.palette.rdFgA2 : theme.fg.primary
                font: timeTextMetrics.font
                horizontalAlignment: Text.AlignHCenter

                // redesign: hover background BG/B2 (Figma "Current Time" state=hover)
                background: Rectangle {
                    visible: textPosition === ControlBar.TimeTextPosition.Inline && (mediaTimeHover.hovered || mediaTime.editing)
                    radius: VLCStyle.rd_radius_normal
                    color: VLCStyle.palette.rdBgB2
                }

                HoverHandler {
                    id: mediaTimeHover
                }

                // redesign: click the current time to type a time and jump there; Enter confirms,
                // Escape or leaving the field cancels (Figma "Current Time" state=click, F-02)
                property bool editing: false

                function _commitEdit(text) {
                    const parts = text.trim().split(":").map((p) => parseInt(p, 10))
                    if (parts.length === 0 || parts.some((p) => isNaN(p) || p < 0))
                        return
                    const seconds = parts.reduce((acc, p) => acc * 60 + p, 0)
                    const length = Player.length.valid() ? Player.length.toSeconds() : 0
                    if (length > 0)
                        Player.position = Math.min(1, seconds / length)
                }

                TapHandler {
                    enabled: textPosition === ControlBar.TimeTextPosition.Inline && Player.seekable
                    onTapped: {
                        mediaTime.editing = true
                        timeEditor.text = mediaTime.text
                        timeEditor.selectAll()
                        timeEditor.forceActiveFocus()
                        root.requestLockUnlockAutoHide(true)
                    }
                }

                TextInput {
                    id: timeEditor

                    anchors.fill: parent
                    visible: mediaTime.editing
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font: mediaTime.font
                    color: VLCStyle.palette.rdFg2
                    selectionColor: VLCStyle.palette.rdAccentDim
                    selectedTextColor: VLCStyle.palette.rdSelectionText
                    selectByMouse: true
                    inputMethodHints: Qt.ImhPreferNumbers
                    validator: RegularExpressionValidator { regularExpression: /^[0-9:]{0,9}$/ }

                    cursorDelegate: Rectangle {
                        width: VLCStyle.dp(1, VLCStyle.scale)
                        color: VLCStyle.palette.rdAccentMain
                    }

                    function _finish(commit) {
                        if (!mediaTime.editing)
                            return
                        if (commit)
                            mediaTime._commitEdit(text)
                        mediaTime.editing = false
                        root.requestLockUnlockAutoHide(false)
                    }

                    Keys.onReturnPressed: _finish(true)
                    Keys.onEnterPressed: _finish(true)
                    Keys.onEscapePressed: _finish(false)
                    onActiveFocusChanged: if (!activeFocus) _finish(false)
                }

                // TODO: Do not use `Binding` when minimum Qt is 6.12:
                Binding {
                    target: mediaTime
                    property: "mutabilityGroup"
                    when: (mediaTime.mutabilityGroup !== undefined)
                    value: (Player.playingState === Player.PLAYING_STATE_PLAYING) ? Item.ModerateMutabilityGroup
                                                                                  : Item.StaticMutabilityGroup
                }

                anchors.left: (parent === pseudoRow) ? parent.left : undefined
                anchors.verticalCenter: (parent === pseudoRow) ? parent.verticalCenter : undefined
            },
            T.Label {
                id: mediaRemainingTime

                Layout.preferredWidth: (textPosition === ControlBar.TimeTextPosition.Inline) ? VLCStyle.rd_timeLabelWidth
                                     : (textPosition === ControlBar.TimeTextPosition.LeftRightSlider) ? timeTextMetrics.width : -1
                // redesign: Figma "Duration" is a fixed 76 px box, the text centered in it
                Layout.minimumWidth: (textPosition === ControlBar.TimeTextPosition.Inline) ? VLCStyle.rd_timeLabelWidth : -1
                Layout.preferredHeight: (textPosition === ControlBar.TimeTextPosition.Inline) ? VLCStyle.rd_seekBarHeight : -1
                verticalAlignment: Text.AlignVCenter

                readonly property bool showRemainingTime: (MainCtx.showRemainingTime && Player.remainingTime.valid())

                readonly property bool _inline: textPosition === ControlBar.TimeTextPosition.Inline

                text: showRemainingTime
                      ? "-" + (_inline ? Player.remainingTime.formatHHMMSS() : Player.remainingTime.formatHMS())
                      : (_inline ? Player.length.formatHHMMSS() : Player.length.formatHMS())
                color: mediaTime.color
                font: timeTextMetrics.font
                horizontalAlignment: Text.AlignHCenter

                visible: (textPosition === ControlBar.TimeTextPosition.Inline) ? root._inlineShowsLength
                                                                               : root.showRemainingTime

                // redesign: hover background BG/B2 like the current time label
                background: Rectangle {
                    visible: textPosition === ControlBar.TimeTextPosition.Inline && mediaRemainingTimeHover.hovered
                    radius: VLCStyle.rd_radius_normal
                    color: VLCStyle.palette.rdBgB2
                }

                // TODO: Do not use `Binding` when minimum Qt is 6.12:
                Binding {
                    target: mediaRemainingTime
                    property: "mutabilityGroup"
                    when: (mediaRemainingTime.mutabilityGroup !== undefined)
                    value: ((Player.playingState === Player.PLAYING_STATE_PLAYING) &&
                            mediaRemainingTime.showRemainingTime) ? Item.ModerateMutabilityGroup
                                                                  : Item.StaticMutabilityGroup
                }

                anchors.right: (parent === pseudoRow) ? parent.right : undefined
                anchors.verticalCenter: (parent === pseudoRow) ? parent.verticalCenter : undefined

                TapHandler {
                    onTapped: (eventPoint, button) => {
                        MainCtx.showRemainingTime = !MainCtx.showRemainingTime
                    }
                }

                HoverHandler {
                    id: mediaRemainingTimeHover
                }

                Widgets.ToolTipExt {
                    colorContext.palette: theme.palette

                    visible: mediaRemainingTimeHover.hovered && MainCtx.showRemainingTime && Player.rate !== 1
                    delay: VLCStyle.delayToolTipAppear
                    text: {
                        if (!visible)
                            return ""

                        const playbackSpeed = Math.abs(Player.rate)
                        const adjustedRemainingTime = Player.remainingTime.scale(1 / playbackSpeed)
                            ? Player.remainingTime.scale(1 / playbackSpeed)
                            : Player.remainingTime

                        return qsTr("%1 (%2x)")
                            .arg(adjustedRemainingTime.formatHMS())
                            .arg(+Player.rate.toFixed(2))
                    }

                    x: (parent.width - width) / 2
                }
            },
            SliderBar {
                id: trackPositionSlider

                barHeight: (textPosition === ControlBar.TimeTextPosition.Inline) ? VLCStyle.rd_seekBarHeight : root.sliderHeight
                thick: textPosition === ControlBar.TimeTextPosition.Inline

                Accessible.role: Accessible.Slider
                Accessible.name: qsTr("Progress")
                AccessibleCompat.id: "progressSlider"

                Layout.fillWidth: true
                Layout.minimumWidth: (textPosition === ControlBar.TimeTextPosition.Inline) ? VLCStyle.rd_seekBarMinimumWidth : -1
                enabled: Player.playingState === Player.PLAYING_STATE_PLAYING || Player.playingState === Player.PLAYING_STATE_PAUSED

                Navigation.parentItem: root
                Navigation.downItem: playerControlLayout

                activeFocusOnTab: true

                focus: true

                Keys.onPressed: (event) => {
                    Navigation.defaultKeyAction(event)
                }
            },
            Loader {
                id: bookmarksLoader

                parent: root
                active: MainCtx.mediaLibraryAvailable && (textPosition !== ControlBar.TimeTextPosition.Inline)
                source: "qrc:///qt/qml/VLC/MediaLibrary/Bookmarks.qml"

                x: root.leftPadding + trackPositionSlider.x + row2.Layout.leftMargin
                y: row2.y + row2.height + VLCStyle.margin_xxsmall
                width: trackPositionSlider.width

                onLoaded: {
                   item.barHeight = Qt.binding(function() { return bookmarksHeight })
                   item.controlBarHovered = Qt.binding(function() { return root.hovered })
                   item.yShift = Qt.binding(function() { return row2.height + VLCStyle.margin_xxsmall })
                }
            }
        ]

        Item {
            // BUG: RowLayout can not be used here
            // because of a Qt bug. (Height is
            // incorrectly determined. Could be
            // about nested layouting).

            id: pseudoRow
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.leftMargin: VLCStyle.margin_normal
            Layout.rightMargin: VLCStyle.margin_normal

            implicitHeight: visible ? Math.max(mediaTime.implicitHeight, mediaRemainingTime.implicitHeight) : 0

            visible: children.length > 0

            children: {
                switch (textPosition) {
                case ControlBar.TimeTextPosition.AboveSlider:
                    return [mediaTime, mediaRemainingTime]
                case ControlBar.TimeTextPosition.Hide:
                case ControlBar.TimeTextPosition.LeftRightSlider:
                case ControlBar.TimeTextPosition.Inline:
                default:
                    return []
                }
            }
        }

        RowLayout {
            id: row2

            children: {
                switch (textPosition) {
                case ControlBar.TimeTextPosition.Hide:
                case ControlBar.TimeTextPosition.AboveSlider:
                    return [trackPositionSlider]
                case ControlBar.TimeTextPosition.LeftRightSlider:
                    return [mediaTime, trackPositionSlider, mediaRemainingTime]
                case ControlBar.TimeTextPosition.Inline:
                default:
                    return []
                }
            }

            visible: children.length > 0

            spacing: VLCStyle.margin_xsmall

            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.leftMargin: (textPosition === ControlBar.TimeTextPosition.LeftRightSlider) ? VLCStyle.margin_xsmall
                                                                                              : 0

            Layout.rightMargin: Layout.leftMargin
        }

        PlayerControlLayout {
            id: playerControlLayout

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: (textPosition === ControlBar.TimeTextPosition.Inline) ? VLCStyle.rd_controlBarSpacing : VLCStyle.margin_large
            Layout.rightMargin: Layout.leftMargin

            identifier: root.identifier

            middleItem: (textPosition === ControlBar.TimeTextPosition.Inline) ? inlineSeekRow : null
            middleItemMinimumWidth: VLCStyle.rd_seekBarMinimumWidth + (root._inlineShowsTime ? root._inlineTimeSlot : 0)
                                    + (root._inlineShowsLength ? root._inlineTimeSlot : 0)
            spacing: (textPosition === ControlBar.TimeTextPosition.Inline) ? root._inlineSpacing : VLCStyle.margin_normal
            layoutSpacing: (textPosition === ControlBar.TimeTextPosition.Inline) ? VLCStyle.rd_controlBarSpacing : VLCStyle.margin_xxlarge
            figmaGaps: textPosition === ControlBar.TimeTextPosition.Inline
            trailingIconSpacing: (textPosition === ControlBar.TimeTextPosition.Inline) ? VLCStyle.rd_iconButtonSpacing : spacing

            implicitHeight: (textPosition === ControlBar.TimeTextPosition.Inline) ? VLCStyle.rd_controlBarHeight - 2 * VLCStyle.rd_controlBarPaddingV
                          : MainCtx.pinVideoControls ? VLCStyle.controlLayoutHeightPinned
                                                     : VLCStyle.controlLayoutHeight

            visible: !model?.empty ?? false

            Navigation.upItem: trackPositionSlider.enabled ? trackPositionSlider : root.Navigation.upItem

            onRequestLockUnlockAutoHide: (lock) => root.requestLockUnlockAutoHide(lock)

            onMenuOpened: (menu) => root.applyMenu(menu)

            Component.onCompleted: {
                root.forceUnlock.connect(playerControlLayout.forceUnlock)
            }
        }
    }
}
