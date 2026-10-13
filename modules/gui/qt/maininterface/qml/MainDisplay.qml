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

// redesign: the full-window library (video 10:12-10:59, 11:48-11:56, 13:48-13:55, 20:52-20:59;
// P5-06, P5-26, P5-27, P6-21): the window's top bar (cone, "...", the centered window title,
// the window buttons; 11:48 no sidebar toggle or folder chip), the library (RdLibraryView,
// shared with the compact library next to the video) and the mini player at the bottom right.
// Without the media library, VLC's own home page is shown.
import QtQuick
import QtQuick.Window

import VLC.Style
import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Playlist
import VLC.Player
import VLC.Menus as Menus

import VLC.Util
import VLC.Dialogs

FocusScope {
    id: g_mainDisplay

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Main display")
    AccessibleCompat.id: "mainDisplay"

    property bool _showCSD: MainCtx.clientSideDecoration
        && !(MainCtx.intfMainWindow.visibility === Window.FullScreen)

    Component.onCompleted: {
        // without a picture-in-picture video, the video cannot keep playing in the library
        if (!MainCtx.canShowVideoPIP && MainCtx.hasEmbededVideo)
            MainPlaylistController.stop()
    }

    Keys.onPressed: (event) => {
        //unhandled keys are forwarded as hotkeys
        if (!event.accepted)
            MainCtx.sendHotkey(event.key, event.modifiers)
    }

    ColorContext {
        id: theme
        palette: VLCStyle.palette
        colorSet: ColorContext.View
    }

    Rectangle {
        anchors.fill: parent
        color: VLCStyle.palette.rdBgB1
    }

    MenuTopbar {
        id: menuTopbar
        z: 6

        visible: MainCtx.hasToolbarMenu
        enabled: visible

        anchors {
            top: parent.top
            right: parent.right
            left: parent.left
        }
    }

    // window top bar (Figma "topbar": 40 px, BG/A3; title Inter 400 14 FG/A2, centered)
    Rectangle {
        id: topBar

        z: 5
        anchors.top: menuTopbar.visible ? menuTopbar.bottom : parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: VLCStyle.applicationVerticalMargin + VLCStyle.rd_topBarHeight
        color: VLCStyle.palette.rdBgA3

        //drag and dbl click the titlebar in CSD mode
        Loader {
            anchors.fill: parent
            active: g_mainDisplay._showCSD
            source: "qrc:///qt/qml/VLC/Widgets/CSDTitlebarTapNDrapHandler.qml"
        }

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: VLCStyle.rd_topBarHeight

            Row {
                id: leftGroup

                anchors.left: parent.left
                anchors.leftMargin: VLCStyle.dp(6, VLCStyle.scale) + VLCStyle.applicationHorizontalMargin
                anchors.verticalCenter: parent.verticalCenter
                spacing: VLCStyle.dp(7, VLCStyle.scale)

                Item {
                    width: VLCStyle.dp(38, VLCStyle.scale)
                    height: VLCStyle.dp(28, VLCStyle.scale)

                    Widgets.RdIcon {
                        anchors.centerIn: parent
                        name: "vlc"
                        accentColor: theme.accent
                    }
                }

                Widgets.IconToolButton {
                    id: menuButton

                    anchors.verticalCenter: parent.verticalCenter
                    width: VLCStyle.rd_iconButtonWidth
                    height: VLCStyle.rd_iconButtonHeight
                    font.pixelSize: VLCStyle.rd_iconSize

                    text: VLCIcons.more
                    rdIcon: "more"
                    description: qsTr("Menu")
                    checked: globalMenu.shown

                    onClicked: globalMenu.popup(this.mapToGlobal(0, height))

                    Menus.QmlGlobalMenu {
                        id: globalMenu

                        ctx: MainCtx
                    }
                }
            }

            Text {
                readonly property real _maxWidth: Math.max(0, parent.width - 2 * Math.max(leftGroup.x + leftGroup.width,
                                                                                           parent.width - rightGroup.x))

                anchors.centerIn: parent
                width: Math.min(implicitWidth, _maxWidth)
                visible: width > 0
                text: qsTr("VLC Media Player")
                elide: Text.ElideRight
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: VLCStyle.palette.rdFgA2
            }

            Item {
                id: rightGroup

                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.applicationHorizontalMargin
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: g_mainDisplay._showCSD ? csdDecorations.width : fullscreenButton.width + VLCStyle.dp(6, VLCStyle.scale)

                Loader {
                    id: csdDecorations

                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right

                    focus: false
                    active: g_mainDisplay._showCSD
                    visible: g_mainDisplay._showCSD
                    source: VLCStyle.palette.hasCSDImage
                        ? "qrc:///qt/qml/VLC/Widgets/CSDThemeButtonSet.qml"
                        : "qrc:///qt/qml/VLC/Widgets/CSDWindowButtonSet.qml"

                    onLoaded: {
                        if (item.showFullscreenButton !== undefined)
                            item.showFullscreenButton = true
                    }
                }

                Widgets.IconToolButton {
                    id: fullscreenButton

                    visible: !g_mainDisplay._showCSD || !(csdDecorations.item && csdDecorations.item.showFullscreenButton !== undefined)
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: g_mainDisplay._showCSD ? csdDecorations.left : parent.right
                    anchors.rightMargin: g_mainDisplay._showCSD ? 0 : VLCStyle.dp(6, VLCStyle.scale)
                    width: VLCStyle.rd_iconButtonWidth
                    height: VLCStyle.rd_iconButtonHeight
                    font.pixelSize: VLCStyle.rd_iconSize

                    text: (MainCtx.intfMainWindow.visibility === Window.FullScreen) ? VLCIcons.defullscreen : VLCIcons.fullscreen
                    rdIcon: (MainCtx.intfMainWindow.visibility === Window.FullScreen) ? "fullscreen_state-active" : "fullscreen"
                    description: qsTr("Fullscreen")

                    onClicked: MainCtx.toggleInterfaceFullScreen()
                }
            }
        }
    }

    // the library (VLC's own home page without the media library)
    Loader {
        id: library

        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: loaderUpdatePane.top
        anchors.leftMargin: VLCStyle.applicationHorizontalMargin
        anchors.rightMargin: VLCStyle.applicationHorizontalMargin

        focus: true
        source: MainCtx.mediaLibraryAvailable ? "qrc:///qt/qml/VLC/MediaLibrary/RdLibraryView.qml"
                                              : "qrc:///qt/qml/VLC/MainInterface/NoMedialibHome.qml"
    }

    // the mini player and its queue (W5.8), over the library at the bottom right
    RdMiniPlayer {
        id: miniPlayer

        parent: library
        z: 4
        visible: Player.isStarted

        onFolderClicked: {
            if (library.item && library.item.revealMrl)
                library.item.revealMrl(Player.url.toString())
        }
    }

    Loader {
        id: loaderUpdatePane

        z: 2

        // WARNING: Object name is used from C++ side to acknowledge the modern update pane is loaded,
        //          if C++ side does not get this acknowledgement, the old update dialog is shown as
        //          fallback.
        objectName: "updatePaneLoader"

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        readonly property bool updateModelIsAvailable: (typeof UpdateModel !== 'undefined')

        active: updateModelIsAvailable && (shouldShow || height > 0.0)

        property int _updateStatusOnDismissal: -1

        readonly property bool shouldShow: {
            if (!updateModelIsAvailable)
                return false

            if (UpdateModel.explicitCheck) {
                return (UpdateModel.updateStatus !== UpdateModel.Unchecked)
            } else {
                if (UpdateModel.updateStatus === _updateStatusOnDismissal)
                    return false // already dismissed with the same status

                switch (UpdateModel.updateStatus) {
                    case UpdateModel.Unchecked:
                    case UpdateModel.Checking:
                    case UpdateModel.UpToDate:
                        return false
                    default:
                        return true
                }
            }
        }

        function dismiss() {
            if (updateModelIsAvailable)
                _updateStatusOnDismissal = UpdateModel.updateStatus

            height = 0.0
        }

        onShouldShowChanged: {
            if (shouldShow)
                height = Qt.binding(() => { return implicitHeight })
        }

        onActiveChanged: {
            if (updateModelIsAvailable && !active) {
                UpdateModel.explicitCheck = undefined // Resets the property
            }
        }

        height: 0
        clip: (height < implicitHeight)

        Behavior on height {
            NumberAnimation {
                easing.type: Easing.InOutSine
                duration: VLCStyle.duration_long
            }
        }

        source: "qrc:///qt/qml/VLC/MainInterface/UpdatePane.qml"

        onLoaded: {
            item.leftPadding = Qt.binding(function() { return VLCStyle.margin_large + VLCStyle.applicationHorizontalMargin })
            item.rightPadding = Qt.binding(function() { return VLCStyle.margin_large + VLCStyle.applicationHorizontalMargin })
            item.bottomPadding = Qt.binding(function() { return VLCStyle.margin_small + VLCStyle.applicationVerticalMargin })

            item.dismissRequested.connect(loaderUpdatePane, loaderUpdatePane.dismiss)
        }
    }

    Dialogs {
        z: 10
        bgContent: g_mainDisplay

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
    }

    Widgets.FloatingNotification {
        id: notif
        z: 11

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            margins: VLCStyle.margin_large
        }
    }

    // a video that starts opens the player (VLC's behavior)
    Connections {
        target: Player
        function onHasVideoOutputChanged() {
            if (Player.hasVideoOutput && MainCtx.hasEmbededVideo)
                MainCtx.playerView = true
        }
    }

    MouseArea {
        /// handles mouse navigation buttons
        z: 9
        anchors.fill: parent
        acceptedButtons: Qt.BackButton | Qt.ForwardButton
        cursorShape: undefined
        onClicked: (mouse) => {
            if (!library.item)
                return
            if (mouse.button === Qt.BackButton && library.item.goBack)
                library.item.goBack()
            else if (mouse.button === Qt.ForwardButton && library.item.goForward)
                library.item.goForward()
        }
    }
}
