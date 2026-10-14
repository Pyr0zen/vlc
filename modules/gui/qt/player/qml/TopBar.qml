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

// redesign: single 40 px top bar (video 3:35-5:14, 11:24-11:40; Figma "topbar"):
// [cone] [...] [sidebar toggle] | [folder chip]      title      [minimize maximize fullscreen close]
// Background BG/A3. Title Inter 400 14 FG/A2, centered on the window.
import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import QtQuick.Window


import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.PlayerControls
import VLC.Playlist
import VLC.Widgets as Widgets
import VLC.Menus as Menus
import VLC.Util

FocusScope{
    id: root

    // Properties (same interface as before the redesign, used by Player.qml)

    required property int textWidth

    // For now, used for d&d functionality
    // Not strictly necessary to set
    property Item plListView

    property int reservedHeight: implicitHeight

    property int topMargin: 0
    property int sideMargin: 0

    property string title

    property bool showCSD: false
    property bool showToolbar: false
    property bool pinControls: false

    property bool playlistVisible: false

    // the compact library is open (sidebar toggle shown active)
    property bool libraryOpen: false
    // the sidebar toggle and the folder chip belong to the player; the full library's top bar
    // (MainDisplay.qml, Figma Player-3.png) has only the cone, "...", the title and the window
    // buttons
    property bool showLibraryButtons: true
    property string accessibleName: qsTr("Player topbar")

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    // Parent folder of the playing file, shown in the folder chip (video 11:24-11:31)
    readonly property string folderName: {
        const url = Player.url ? Player.url.toString() : ""
        if (url === "")
            return ""
        const parts = decodeURIComponent(url).replace(/\\/g, "/").split("/").filter((p) => p !== "")
        return parts.length >= 2 ? parts[parts.length - 2] : ""
    }

    // Signals

    signal togglePlaylistVisibility()
    signal requestLockUnlockAutoHide(bool lock)
    signal backRequested()
    // sidebar toggle and folder chip: open or close the compact library (Player.qml)
    signal libraryToggleRequested()
    signal folderRequested()

    ///incomming signal to request all menu and popup to close
    signal forceUnlock()

    // Settings

    implicitHeight: topMargin + VLCStyle.rd_topBarHeight

    Accessible.role: Accessible.ToolBar
    Accessible.name: accessibleName
    AccessibleCompat.id: "playerTopBar"

    // Children

    // Figma "topbar": BG/A3 in the dark Player frames, BG/A3 Transparent in "Player - Light"
    Rectangle {
        anchors.fill: parent
        color: VLCStyle.palette.isDark ? VLCStyle.palette.rdBgA3 : VLCStyle.palette.rdBgA3Transparent
    }

    //drag and dbl click the titlebar in CSD mode
    Loader {
        id: tapNDrag

        anchors.fill: parent
        active: root.showCSD
        source: "qrc:///qt/qml/VLC/Widgets/CSDTitlebarTapNDrapHandler.qml"

        Connections {
            target: tapNDrag.item
            enabled: tapNDrag.status === Loader.Ready
            function onCsdMenuVisibleChanged() {
                root.requestLockUnlockAutoHide(tapNDrag.item.csdMenuVisible)
            }
        }
    }

    Item {
        id: bar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: VLCStyle.rd_topBarHeight

        Row {
            id: leftGroup

            anchors.left: parent.left
            anchors.leftMargin: VLCStyle.dp(6, VLCStyle.scale) + root.sideMargin
            anchors.verticalCenter: parent.verticalCenter

            // Figma "topbar" (1920x40, padding 6): cone cell 38, gap 7, "..." and sidebar icons 28
            // wide 10 apart ("Frame 50"), the divider in a 24 wide cell ("Frame 6"), folder chip
            spacing: 0

            // cone (Figma "Frame 8", 38x28 cell, Figma "vlc" icon in Accent/Logo, derived from the
            // live accent: video 17:46)
            Item {
                width: VLCStyle.dp(38, VLCStyle.scale)
                height: VLCStyle.dp(28, VLCStyle.scale)

                Widgets.RdIcon {
                    anchors.centerIn: parent
                    name: "vlc"
                    accentColor: VLCStyle.palette.rdAccentLogo
                }
            }

            Item {
                width: VLCStyle.dp(7, VLCStyle.scale)
                height: 1
            }

            Widgets.IconToolButton {
                id: menuSelector

                anchors.verticalCenter: parent.verticalCenter
                width: VLCStyle.dp(28, VLCStyle.scale)
                height: VLCStyle.rd_iconButtonHeight
                font.pixelSize: VLCStyle.rd_iconSize

                text: VLCIcons.more
                rdIcon: "more"
                description: qsTr("Menu")

                AccessibleCompat.id: "topBarMenuButton"

                focus: true
                checked: contextMenu.visible

                Navigation.parentItem: root
                Navigation.rightItem: root.showLibraryButtons ? sidebarButton : null

                onClicked: contextMenu.popupBelow(menuSelector, visualFocus)

                onHoveredChanged: root.requestLockUnlockAutoHide(hovered)

                // redesign: the main menu in the Figma style (W4.9)
                Menus.RdMainMenu {
                    id: contextMenu

                    onAboutToShow: root.requestLockUnlockAutoHide(true)
                    onAboutToHide: root.requestLockUnlockAutoHide(false)
                }

                Connections {
                    target: root

                    function onForceUnlock() {
                        contextMenu.close()
                    }
                }
            }

            // sidebar toggle (video 11:37): opens and closes the compact library
            Item {
                visible: root.showLibraryButtons
                width: VLCStyle.dp(10, VLCStyle.scale)
                height: 1
            }

            Widgets.IconToolButton {
                id: sidebarButton

                visible: root.showLibraryButtons
                anchors.verticalCenter: parent.verticalCenter
                width: VLCStyle.dp(28, VLCStyle.scale)
                height: VLCStyle.rd_iconButtonHeight
                font.pixelSize: VLCStyle.rd_iconSize

                text: VLCIcons.panel_left
                rdIcon: "sidebar_direction-left"
                // Figma "sidebar" icon state=active: the filled panel, in the icon's own color
                rdIconChecked: "sidebar_state-active"
                checked: root.libraryOpen
                color: colorContext.fg.primary
                description: qsTr("Library")

                AccessibleCompat.id: "topBarBackButton"

                Navigation.parentItem: root
                Navigation.leftItem: menuSelector
                Navigation.rightItem: folderChip

                onClicked: root.libraryToggleRequested()
                onHoveredChanged: root.requestLockUnlockAutoHide(hovered)
            }

            Item {
                visible: folderChip.visible
                anchors.verticalCenter: parent.verticalCenter
                width: VLCStyle.dp(24, VLCStyle.scale)
                height: VLCStyle.dp(28, VLCStyle.scale)

                // Figma "Vector 26": an 18 px line, 1.5 px stroke with round caps (19.5 x 1.5 drawn,
                // 3 px wide in the 2x export). Not rounded through dp(): 1.5 would become 2.
                Rectangle {
                    anchors.centerIn: parent
                    width: 1.5 * VLCStyle.scale
                    height: 19.5 * VLCStyle.scale
                    radius: width / 2
                    color: VLCStyle.palette.rdDividerBright
                }
            }

            // folder chip (Figma "Frame 12": 82x28 min, radius 6, gap 4): folder icon + folder name
            T.AbstractButton {
                id: folderChip

                visible: root.showLibraryButtons && root.folderName !== ""
                anchors.verticalCenter: parent.verticalCenter

                implicitHeight: VLCStyle.dp(28, VLCStyle.scale)
                implicitWidth: Math.max(VLCStyle.dp(82, VLCStyle.scale), chipRow.implicitWidth + VLCStyle.dp(8, VLCStyle.scale))

                Accessible.name: qsTr("Open folder %1 in the library").arg(root.folderName)

                Navigation.parentItem: root
                Navigation.leftItem: sidebarButton

                onClicked: root.folderRequested()
                onHoveredChanged: root.requestLockUnlockAutoHide(hovered)

                background: Rectangle {
                    radius: VLCStyle.rd_radius_normal
                    color: folderChip.hovered ? VLCStyle.palette.rdHoverOverlay : "transparent"
                }

                contentItem: Row {
                    id: chipRow

                    spacing: VLCStyle.dp(4, VLCStyle.scale)
                    leftPadding: VLCStyle.dp(4, VLCStyle.scale)

                    Widgets.RdIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "folder"
                        color: VLCStyle.palette.rdFgA2
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.folderName
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, VLCStyle.dp(220, VLCStyle.scale))
                        font.family: VLCStyle.rd_fontFamily
                        font.pixelSize: VLCStyle.rd_fontSize_label
                        color: VLCStyle.palette.rdFgA2
                    }
                }
            }
        }

        T.Label {
            id: centerTitleText

            readonly property real _maxWidth: Math.max(0, Math.min(root.width - 2 * Math.max(leftGroup.width + leftGroup.x,
                                                                                                root.width - rightGroup.x),
                                                                     root.width))

            anchors.centerIn: parent
            width: Math.min(implicitWidth, _maxWidth)

            visible: width > 0

            text: root.title
            color: VLCStyle.palette.rdFgA2
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }

        Item {
            id: rightGroup

            anchors.right: parent.right
            // Figma: the window buttons end 6 from the edge (topbar padding)
            anchors.rightMargin: root.sideMargin + (root.showCSD ? VLCStyle.dp(6, VLCStyle.scale) : 0)
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            width: root.showCSD ? csdDecorations.width : fullscreenButton.width + VLCStyle.dp(6, VLCStyle.scale)

            Loader {
                id: csdDecorations

                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right

                focus: false
                active: root.showCSD
                enabled: root.showCSD
                visible: root.showCSD
                source:  VLCStyle.palette.hasCSDImage
                    ? "qrc:///qt/qml/VLC/Widgets/CSDThemeButtonSet.qml"
                    : "qrc:///qt/qml/VLC/Widgets/CSDWindowButtonSet.qml"

                onLoaded: {
                    if (item.showFullscreenButton !== undefined)
                        item.showFullscreenButton = true
                }

                Connections {
                    target: csdDecorations.item
                    enabled: csdDecorations.status === Loader.Ready
                    function onButtonHoveredChanged() { root.requestLockUnlockAutoHide(csdDecorations.item.buttonHovered) }
                }
            }

            // fullscreen when the window has native decorations (or a themed CSD set)
            Widgets.IconToolButton {
                id: fullscreenButton

                visible: !root.showCSD || !(csdDecorations.item && csdDecorations.item.showFullscreenButton !== undefined)
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: root.showCSD ? csdDecorations.left : parent.right
                anchors.rightMargin: root.showCSD ? 0 : VLCStyle.dp(6, VLCStyle.scale)
                width: VLCStyle.rd_iconButtonWidth
                height: VLCStyle.rd_iconButtonHeight
                font.pixelSize: VLCStyle.rd_iconSize

                text: (MainCtx.intfMainWindow.visibility === Window.FullScreen) ? VLCIcons.defullscreen : VLCIcons.fullscreen
                rdIcon: (MainCtx.intfMainWindow.visibility === Window.FullScreen) ? "fullscreen_state-active" : "fullscreen"
                description: qsTr("Fullscreen")

                onClicked: MainCtx.toggleInterfaceFullScreen()
                onHoveredChanged: root.requestLockUnlockAutoHide(hovered)
            }
        }
    }
}
