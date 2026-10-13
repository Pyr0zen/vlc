/*****************************************************************************
 * Copyright (C) 2020 VLC authors and VideoLAN
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

// redesign: resume toast near the playback controls (video 13:55-14:10, Figma "continue":
// 552x52 pill, radius 16, BG/A3 95%, Inter 16 FG/2 text with the time in bold, "Continue Watching"
// primary button 146x32, dark 44x32 close button).
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T


import VLC.MainInterface
import VLC.Player
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Util

FocusScope {
    id: resumePanel

    property int maxWidth: VLCStyle.dp(552, VLCStyle.scale)

    implicitHeight: VLCStyle.dp(52, VLCStyle.scale)
    implicitWidth: Math.min(maxWidth, content.implicitWidth + VLCStyle.dp(30, VLCStyle.scale))

    baselineOffset: label.baselineOffset

    visible: false
    enabled: visible

    Accessible.role: Accessible.Dialog
    Accessible.name: qsTr("Resume dialog")

    signal hidden()

    // a file watched to its last 20 seconds starts over without asking (Tony, 2026-10-13); the
    // length is often only known once playback has started
    readonly property bool _watchedToEnd: _lengthKnown && Player.restoreProgress > 0
                                          && (1 - Player.restoreProgress) * Player.length.toSeconds() < 20

    // Player.length still holds the previous file's length until the new one is reported
    property bool _lengthKnown: false

    Connections {
        target: Player
        // only the "cleared" emissions (media change, stop) reset the length: the positive
        // answer can come from the media library thread after lengthChanged
        function onPlaybackRestoreQueried() {
            if (!Player.canRestorePlayback)
                resumePanel._lengthKnown = false
        }
        function onLengthChanged() {
            resumePanel._lengthKnown = Player.length.valid()
        }
    }

    on_WatchedToEndChanged: {
        if (_watchedToEnd && visible)
            hideResumePanel()
    }

    function showResumePanel ()
    {
        if (_watchedToEnd)
            return
        resumePanel.visible = true
        continueBtn.forceActiveFocus()
        resumeTimeout.start()
    }

    function hideResumePanel() {
        resumeTimeout.stop()
        resumePanel.visible = false
        Player.acknowledgeRestoreCallback()
        hidden()
    }

    Timer {
        id: resumeTimeout
        interval: 10000
        onTriggered: {
            resumePanel.visible = false
            hidden()
        }
    }

    Connections {
        target: Player
        function onCanRestorePlaybackChanged() {
            if (Player.canRestorePlayback) {
                showResumePanel()
            } else {
                hideResumePanel()
            }
        }
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    Component.onCompleted: {
        if (Player.canRestorePlayback) {
            showResumePanel()
        }
    }

    Navigation.cancelAction: function() {
        hideResumePanel()
    }

    Rectangle {
        anchors.fill: parent
        radius: VLCStyle.rd_radius_toast
        color: VLCStyle.palette.rdBgA3Transparent
    }

    RowLayout {
        id: content

        anchors.fill: parent
        anchors.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
        anchors.rightMargin: VLCStyle.dp(10, VLCStyle.scale)
        spacing: VLCStyle.dp(10, VLCStyle.scale)

        T.Label {
            id: label

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            textFormat: Text.StyledText
            elide: Text.ElideRight
            color: VLCStyle.palette.rdFg2
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_header

            // the saved progress times the file length (known once playback starts)
            readonly property bool _hasRestoreTime: resumePanel._lengthKnown && Player.restoreProgress > 0

            text: _hasRestoreTime
                  ? qsTr("You already watched till %1")
                        .arg("<b>" + Player.length.scale(Player.restoreProgress).formatHHMMSS() + "</b>")
                  : qsTr("Do you want to restart the playback where you left off?")
        }

        Widgets.RdButton {
            id: continueBtn

            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: VLCStyle.dp(50, VLCStyle.scale)

            style: Widgets.RdButton.Style.Primary
            text: qsTr("Continue Watching")

            AccessibleCompat.id: "resumeContinueButton"

            focus: true
            onClicked: {
                Player.restorePlaybackPos()
                hideResumePanel()
            }

            Navigation.parentItem: resumePanel
            Navigation.rightItem: closeBtn
        }

        T.Button {
            id: closeBtn

            Layout.alignment: Qt.AlignVCenter
            implicitWidth: VLCStyle.dp(44, VLCStyle.scale)
            implicitHeight: VLCStyle.dp(32, VLCStyle.scale)

            AccessibleCompat.id: "resumeDismissButton"
            Accessible.name: qsTr("Dismiss")

            onClicked: hideResumePanel()

            Navigation.parentItem: resumePanel
            Navigation.leftItem: continueBtn
            Keys.priority: Keys.AfterItem
            Keys.onPressed: (event) => closeBtn.Navigation.defaultKeyAction(event)

            background: Rectangle {
                radius: VLCStyle.rd_radius_normal
                color: closeBtn.hovered ? VLCStyle.palette.rdBgA2 : VLCStyle.palette.rdBgA1
            }

            contentItem: Item {
                Widgets.RdIcon {
                    anchors.centerIn: parent
                    name: "close"
                    color: VLCStyle.palette.rdFgA2
                }
            }
        }
    }
}
