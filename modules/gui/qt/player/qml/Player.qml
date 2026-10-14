/*****************************************************************************
 * Copyright (C) 2024 VLC authors and VideoLAN
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
import QtQuick.Layouts
import QtQml.Models
import QtQuick.Window
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Playlist
import VLC.Player
import VLC.PlayerControls
import VLC.Dialogs
import VLC.Util

FocusScope {
    id: rootPlayer

    // Properties

    //behave like a Page
    property var pagePrefix: []

    readonly property int positionSliderY: controlBar.y + controlBar.sliderY

    readonly property string coverSource: {
        if (Player.artwork &&
            Player.artwork.toString())
            return Player.artwork
        else if (Player.hasVideoOutput)
            return VLCStyle.noArtVideoCover
        else
            return VLCStyle.noArtAlbumCover
    }

    // Only applicable in video mode:
    // redesign: no shadow gradients behind the bars; the bars have their own background
    property bool displayFadeRectangles: false
    property real implicitFadeRectangleHeight: VLCStyle.dp(206, VLCStyle.scale)

    // Private

    property bool _controlsUnderVideo: (MainCtx.pinVideoControls
                                        &&
                                        (MainCtx.intfMainWindow.visibility !== Window.FullScreen)
                                        && !RdPanels.uiHidden)

    readonly property bool _windowed: MainCtx.intfMainWindow.visibility !== Window.FullScreen

    property bool _keyPressed: false

    // redesign: the compact library docked on the left between the bars (video 11:37-11:59,
    // P5-23 / P5-25 / F-16; Figma Player.png): the top bar's sidebar toggle and folder chip open
    // and close it with the Figma smart animate "slow" (208 ms), the video area sits to its
    // right. Without the media library the toggle opens VLC's own library view instead.
    readonly property bool _libraryShown: MainCtx.mediaLibraryAvailable && RdPanels.libraryOpen
                                          && !RdPanels.uiHidden
    // 0 closed, 1 open
    property real _libraryProgress: _libraryShown ? 1 : 0
    Behavior on _libraryProgress {
        NumberAnimation {
            duration: VLCStyle.rd_librarySlideDuration
            easing.type: Easing.OutCubic
        }
    }
    readonly property real _libraryFullWidth: VLCStyle.rd_libraryRailWidth + VLCStyle.rd_libraryPanelWidth
    readonly property real _libraryWidth: _libraryFullWidth * _libraryProgress
    // left edge of the video area. The library slides over the video, which takes its new size
    // once, when the opening ends or the closing starts: the native video surface is resized
    // once instead of on every frame of the slide (performance first)
    readonly property real _videoInset: (_libraryShown && _libraryProgress >= 1) ? _libraryFullWidth : 0
    // the library is built on its first opening and then kept, so it reopens within a frame
    property bool _libraryActivated: false
    // built in the background when the player starts with it open (the player shows first)
    property bool _libraryAsync: false

    // open already when the player comes back from the full library
    Component.onCompleted: {
        if (_libraryShown) {
            _libraryAsync = true
            _libraryActivated = true
        }
    }

    on_LibraryShownChanged: {
        if (_libraryShown) {
            // opened by the user: built at once (the folder chip reveals in it right away)
            _libraryAsync = false
            _libraryActivated = true
        } else if (librarySidebar.activeFocus) {
            // keys must not go on to the hidden library
            topBar.forceActiveFocus()
        }
        _updatePanelLock()
    }

    // sidebar toggle (reveal = false) and folder chip (reveal = true): open or close the compact
    // library; the folder chip opens it on the folder of the playing file (11:24-11:31)
    function toggleLibrary(reveal) {
        if (!MainCtx.mediaLibraryAvailable) {
            if (MainCtx.hasEmbededVideo && !MainCtx.canShowVideoPIP)
                MainPlaylistController.stop()
            MainCtx.playerView = false
            return
        }

        if (RdPanels.libraryOpen) {
            RdPanels.libraryOpen = false
            return
        }

        RdPanels.libraryOpen = true
        if (reveal && librarySidebar.item)
            librarySidebar.item.revealMrl(Player.url.toString())
    }

    // redesign (Decision 30): in a window both bars show while the mouse moves over the player and
    // fade out a few seconds after it stops; in fullscreen each bar shows while the mouse is near
    // it (video 3:46-3:55). Menus, panels, keyboard use and audio mode show both bars (in
    // fullscreen except the far one while the mouse is in the other bar's zone).
    readonly property real _barHoverZone: VLCStyle.dp(40, VLCStyle.scale)
    readonly property bool _mouseNearTop: !_windowed && _cursorY >= 0 && _cursorY <= topBar.height + _barHoverZone
    readonly property bool _mouseNearBottom: !_windowed && _cursorY >= 0
                                             && _cursorY >= height - controlBar.height - _barHoverZone
    readonly property bool _showBothBars: playerToolbarVisibilityFSM.isVisible
                                          && (_windowed || !MainCtx.hasEmbededVideo
                                              || playerToolbarVisibilityFSM.keyboardShown)
    // Hide UI (W4.10, Ctrl + \) hides both bars whatever the mouse does
    // (the compact library sits between both bars and keeps them, also in fullscreen)
    readonly property bool _topBarVisible: !RdPanels.uiHidden
                                           && (_controlsUnderVideo || _showBothBars || _mouseNearTop
                                               || _libraryShown
                                               || (playerToolbarVisibilityFSM.isLocked && !_mouseNearBottom))
    readonly property bool _controlBarVisible: !RdPanels.uiHidden
                                               && (_controlsUnderVideo || _showBothBars || _mouseNearBottom
                                                   || _libraryShown
                                                   || (playerToolbarVisibilityFSM.isLocked && !_mouseNearTop))

    // cursor height inside the player, -1 outside, from mouse events (no polling): the hover
    // handler below sees the moves over the bars and panels; the video surface accepts its hover
    // events, so the handler is not hovered over the video, where the surface reports the moves
    // as in upstream VLC and its own hover handler tells when the cursor is over it
    // (_videoHovered). Hover events reach Qt Quick while another app is active, so a window also
    // shows its bars then.
    property real _cursorY: -1
    property bool _videoHovered: false

    // the cursor left the player only when neither the player nor the video is hovered (moving
    // from a bar onto the video unhovers the player handler)
    function _cursorMaybeLeft() {
        if (!playerHover.hovered && !_videoHovered)
            _cursorY = -1
    }

    HoverHandler {
        id: playerHover

        // only the video player hides its bars and cursor
        enabled: MainCtx.hasEmbededVideo

        onPointChanged: {
            if (hovered)
                cursorTracker.track(point.scenePosition.x, point.scenePosition.y)
        }
        onHoveredChanged: {
            if (!hovered)
                rootPlayer._cursorMaybeLeft()
        }
        // without video nothing is tracked
        onEnabledChanged: {
            if (!enabled)
                rootPlayer._cursorY = -1
        }
    }

    QtObject {
        id: cursorTracker

        // last cursor position in scene and in screen coordinates
        property bool valid: false
        property real sceneX: 0
        property real sceneY: 0
        property real globalX: 0
        property real globalY: 0

        // Window moves, resizes and fullscreen switches move the player under a still cursor and
        // cause hover events without a mouse move: they do not count as moves (they would end the
        // keyboard mode and show the bars).
        function track(x, y) {
            const tolerance = 0.01
            let p
            if (valid && Math.abs(x - sceneX) < tolerance && Math.abs(y - sceneY) < tolerance) {
                // same position in the window (Qt's hover check after the scene changed): the
                // cursor is still where it was on the screen
                p = rootPlayer.mapFromGlobal(globalX, globalY)
            } else {
                p = rootPlayer.mapFromItem(null, x, y)
                const g = rootPlayer.mapToGlobal(p.x, p.y)
                // the window moved under a still cursor if only the position in the window changed
                const moved = !valid || Math.abs(g.x - globalX) >= tolerance
                                     || Math.abs(g.y - globalY) >= tolerance
                valid = true
                sceneX = x
                sceneY = y
                globalX = g.x
                globalY = g.y
                // (ends the keyboard "show both bars" mode and shows the auto-hidden cursor again)
                if (moved && inside(p)) {
                    if (Player.isInteractive)
                        interactiveAutoHideTimer.restart()
                    else
                        playerToolbarVisibilityFSM.mouseMove()
                }
            }
            rootPlayer._cursorY = inside(p) ? p.y : -1
        }

        function inside(p) {
            return p.x >= 0 && p.y >= 0 && p.x <= rootPlayer.width && p.y <= rootPlayer.height
        }
    }

    // Settings

    Accessible.role: Accessible.Client
    Accessible.name: qsTr("Player")
    AccessibleCompat.id: "playerView"

    // Events

    // keys go to VLC's hotkeys, except while a modal redesign popup is open (RdPanels.modalCount).
    // In the compact library a row with keyboard focus or the search field still gets its keys
    // (InterfaceWindowHandler::applyKeyEvent), a row clicked with the mouse does not: Space
    // pauses as everywhere else in the player.
    // _leaving keeps the binding off while the view is destroyed: a menu released during the
    // destruction would otherwise turn the hotkeys back on for the library
    property bool _leaving: false
    Binding {
        target: MainCtx
        property: "preferHotkeys"
        value: !rootPlayer._leaving && RdPanels.modalCount === 0
    }
    Component.onDestruction: {
        rootPlayer._leaving = true
        MainCtx.preferHotkeys = false
        RdPanels.close()
        RdPanels.uiHidden = false
    }

    Keys.priority: Keys.AfterItem

    // Ctrl+F searches the compact library while it is shown: the shortcut override comes
    // before VLC's global Ctrl+F "Open Folder" shortcut and before the hotkeys (the key press
    // itself may go to the hotkeys); with the library closed Ctrl+F stays Open Folder
    Keys.onShortcutOverride: (event) => {
        if (rootPlayer._libraryShown && librarySidebar.item && KeyHelper.matchSearch(event)) {
            event.accepted = true
            librarySidebar.item.focusSearch()
        }
    }

    Keys.onPressed: (event) => {
        if (event.accepted)
            return

        // Ctrl+F reaching the player (focus in the library search): stays there
        if (rootPlayer._libraryShown && librarySidebar.item && KeyHelper.matchSearch(event)) {
            librarySidebar.item.focusSearch()
            event.accepted = true
            return
        }

        _keyPressed = true

        rootPlayer.Navigation.defaultKeyAction(event)

        //unhandled keys are forwarded as hotkeys
        if (!event.accepted || controlBar.state !== "visible")
            MainCtx.sendHotkey(event.key, event.modifiers);
    }

    Keys.onReleased: (event) => {
        if (event.accepted || _keyPressed === false)
            return

        _keyPressed = false

        rootPlayer.Navigation.defaultKeyReleaseAction(event)
    }

    on_ControlsUnderVideoChanged: {
        if (_controlsUnderVideo && !playerToolbarVisibilityFSM.isVisible)
            playerToolbarVisibilityFSM.askShow()
        // the hide timeout was blocked while pinned: start it again, keeping the keyboard mode
        // (pressing F while pinned keeps both bars up as long as after any key)
        else if (!_controlsUnderVideo && playerToolbarVisibilityFSM.isVisible && !Player.isInteractive) {
            if (playerToolbarVisibilityFSM.keyboardShown)
                playerToolbarVisibilityFSM.keyboardMove()
            else
                playerToolbarVisibilityFSM.mouseMove()
        }
    }

    // Functions

    function lockUnlockAutoHide(lock) {
        if (lock) {
            // a hidden FSM ignores lock() (fullscreen bars shown by their edge zone, a panel or the
            // time field opened from such a bar): show it first, so every lock is counted and the
            // matching unlock() cannot release another component's lock
            if (!playerToolbarVisibilityFSM.isVisible)
                playerToolbarVisibilityFSM.askShow()
            playerToolbarVisibilityFSM.lock()
        } else {
            playerToolbarVisibilityFSM.unlock()
        }
    }

    // Private

    function _onNavigationCancel() {
        if (MainCtx.hasEmbededVideo && !MainCtx.canShowVideoPIP) {
            MainPlaylistController.stop()
        }

        History.previous()
    }

    //we draw both the view and the window here
    ColorContext {
        id: windowTheme

        // redesign: the player follows the theme over the video too (Figma "Player - Light",
        // video 17:43), instead of VLC's night theme forced while a video plays
        palette: VLCStyle.palette

        colorSet: ColorContext.Window
    }

    PlayerToolbarVisibilityFSM {
        id: playerToolbarVisibilityFSM

        pinned: rootPlayer._controlsUnderVideo
        // a window uses the redesign's 3 s; fullscreen keeps VLC's "hide cursor and fullscreen
        // controller" preference (mouse-hide-timeout)
        hideDelay: rootPlayer._windowed ? VLCStyle.rd_barsHideDelay : MainCtx.mouseHideTimeout

        onForceUnlock:{
            controlBar.forceUnlock()

            topBar.forceUnlock()
        }
    }

    PlayerPlaylistVisibilityFSM {
        id: playlistVisibility

        onIsPlaylistVisibleChanged: lockUnlockAutoHide(isPlaylistVisible)
    }

    Connections {
        target: MainCtx

        //playlist
        function onHasEmbededVideoChanged() {
            playlistVisibility.updateVideoEmbed()
            playerToolbarVisibilityFSM.updateVideoEmbed()
        }
        function onAskShow() {
            playerToolbarVisibilityFSM.askShow()
        }
    }


    Connections {
        target: MainCtx.playqueuePanel

        //playlist
        function onDockedChanged() {
            playlistVisibility.updatePlaylistDocked()
        }
        function onVisibleChanged() {
            playlistVisibility.updatePlaylistVisible()
        }
    }


    Loader {
        id: playerSpecializationLoader

        objectName: "playerSpecializationLoader"

        anchors {
            left: parent.left
            // the video area starts right of the compact library
            leftMargin: rootPlayer._videoInset
            right: parent.right
            top: (MainCtx.hasEmbededVideo && rootPlayer._controlsUnderVideo) ? topBar.bottom : parent.top
            bottom: (MainCtx.hasEmbededVideo && rootPlayer._controlsUnderVideo) ? controlBar.top : parent.bottom
        }

        sourceComponent: MainCtx.hasEmbededVideo ? videoComponent : audioComponent

        property int cursorShape

        // Have padding here, so that the content (unlike background) does not go behind the top bar or the control bar:
        property real topPadding: (anchors.top === parent.top) ? topBar.height : 0
        property real bottomPadding: (anchors.bottom === parent.bottom) ? controlBar.height : 0

        component TouchDragHandler : DragHandler {
            id: touchDragHandler

            acceptedDevices: PointerDevice.TouchScreen

            minimumPointCount: 1
            maximumPointCount: 1

            target: null

            dragThreshold: VLCStyle.margin_normal

            property vector2d lastActiveTranslation

            // TODO: Use `createComponent()` and load directly from module instead, since
            //       it is pointless to keep the `QQmlComponent` around for this object.
            readonly property Component wheelToVLCConverterComponent: Component { WheelToVLCConverter { } }

            property WheelToVLCConverter wheelToVLCConverter

            // We synthesize wheel event with pixel delta. It is a to-do to handle
            // touch properly with precision adjustment, like on Android:
            onActiveTranslationChanged: {
                if (active) {
                    console.assert(wheelToVLCConverter)

                    const delta = Qt.point(activeTranslation.x - lastActiveTranslation.x,
                                           activeTranslation.y - lastActiveTranslation.y)

                    // WheelToVLCConverter can not handle sole pixel delta now, so we also
                    // use angle delta. This is similar to wheel events on some platforms:
                    wheelToVLCConverter.customWheelEvent(delta,
                                                         delta,
                                                         Qt.NoButton,
                                                         Qt.NoModifier,
                                                         true)

                    lastActiveTranslation = activeTranslation
                }
            }

            onActiveChanged: {
                if (active) {
                    if (!wheelToVLCConverter) {
                        wheelToVLCConverter = wheelToVLCConverterComponent.createObject(touchDragHandler)
                        wheelToVLCConverter.vlcWheelKey.connect(MainCtx, MainCtx.sendVLCHotkey)
                    }
                } else {
                    lastActiveTranslation = Qt.vector2d(0, 0)
                }
            }
        }

        Component {
            id: videoComponent

            FocusScope {
                // Video

                focus: true

                VideoSurface {
                    id: videoSurface

                    anchors.fill: parent

                    // With regard to `ViewBlockingRectangle`, we
                    // do not need to prevent painting anything
                    // behind because there is already nothing
                    // behind (unlike pip player):
                    renderingEnabled: false

                    videoSurfaceProvider: MainCtx.videoSurfaceProvider

                    visible: MainCtx.hasEmbededVideo

                    focus: true

                    cursorShape: playerSpecializationLoader.cursorShape

                    function onMouseEvent() {
                        //short interval for mouse events
                        if (Player.isInteractive)
                            interactiveAutoHideTimer.restart()
                        else
                            playerToolbarVisibilityFSM.mouseMove();
                    }

                    // redesign: moves go through the player's cursor tracking, which tells mouse
                    // moves from window moves and also gives the cursor height for the
                    // fullscreen bar zones; the surface reports device pixels
                    function onMouseMove(x, y) {
                        const dpr = MainCtx.effectiveDevicePixelRatio(Window.window) || 1.0
                        const p = videoSurface.mapToItem(null, x / dpr, y / dpr)
                        cursorTracker.track(p.x, p.y)
                    }

                    Component.onCompleted: {
                        mouseMoved.connect(videoSurface.onMouseMove)
                        mousePressed.connect(videoSurface.onMouseEvent)
                        mouseReleased.connect(videoSurface.onMouseEvent)
                        mouseDblClicked.connect(videoSurface.onMouseEvent)
                    }

                    Component.onDestruction: rootPlayer._videoHovered = false

                    // redesign: tells the player when the cursor is over the video (see _cursorY)
                    HoverHandler {
                        onHoveredChanged: {
                            rootPlayer._videoHovered = hovered
                            if (!hovered)
                                rootPlayer._cursorMaybeLeft()
                        }
                    }

                    Binding on cursorShape {
                        when: playerToolbarVisibilityFSM.started
                            && !playerToolbarVisibilityFSM.isVisible
                            && !interactiveAutoHideTimer.running
                            && !rootPlayer._mouseNearTop && !rootPlayer._mouseNearBottom
                        value: Qt.BlankCursor
                    }

                    TouchDragHandler {

                    }
                }

                component FadeRectangle : Rectangle {
                    implicitHeight: rootPlayer.implicitFadeRectangleHeight

                    SGManipulator {
                        // The rectangle is the bottom-most item in the interface,
                        // it does not need blending even though it is not opaque.
                        // Since `Rectangle` does not provide explicit control over
                        // blending, we are using `SGManipulator`:
                        blending: false
                    }
                }

                FadeRectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right

                    opacity: topBar.opacity
                    visible: rootPlayer.displayFadeRectangles

                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(0, 0, 0, .8) }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }

                FadeRectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right

                    opacity: controlBar.opacity

                    gradient: Gradient {
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: .64; color: Qt.rgba(0, 0, 0, .8) }
                        GradientStop { position: 1; color: "black" }
                    }

                    visible: rootPlayer.displayFadeRectangles && !(controlBar.background && controlBar.background.visible)
                }
            }
        }

        Component {
            id: audioComponent

            FocusScope {
                id: audioFocusScope
                // Audio

                focus: true

                property real topPadding: playerSpecializationLoader.topPadding
                property real bottomPadding: playerSpecializationLoader.bottomPadding

                // Whether the full lyrics view is active
                readonly property bool lyricsMode: MainCtx.lyricsMode
                readonly property bool lyricsLayoutActive: lyricsMode
                                                        && Player.hasLyrics
                                                        && centerContent.width > VLCStyle.colWidth(6)

                // Reset sync when entering lyrics mode
                onLyricsModeChanged: {
                    if (lyricsMode && lyricsLoader.item)
                        lyricsLoader.item.lyricsSyncToPlayback = true
                }

                // background image
                Widgets.DualKawaseBlur {
                    id: blurredBackground

                    // Six pass is free here since we release the intermediate layers
                    // through unsetting `live` (see `liveTimer`):
                    mode: Widgets.DualKawaseBlur.Mode.SixPass
                    radius: 2

                    // We disable live when everything settles through `liveTimer`,
                    // which is important to release intermediate layers with static
                    // source:
                    live: true

                    //destination aspect ratio
                    readonly property real dar: parent.width / parent.height

                    anchors.centerIn: parent
                    width: (cover.sar < dar) ? parent.width :  parent.height * cover.sar
                    height: (cover.sar < dar) ? parent.width / cover.sar :  parent.height

                    source: textureProviderIndirection

                    postprocess: true
                    tint: bgtheme.palette.isDark ? "black" : "white"
                    // redesign: Figma "Player - Music" blurs the artwork without a tint
                    tintStrength: 0
                    backgroundColor: bgtheme.bg.primary

                    readonly property ColorContext colorContext: ColorContext {
                        id: bgtheme
                        colorSet: ColorContext.View
                    }

                    // The window naturally clips the content, but having this saves some
                    // video memory, depending on the excess content in the last layer:
                    viewportRect: Qt.rect((width - parent.width) / 2, (height - parent.height) / 2, parent.width, parent.height)

                    sourceTextureProviderObserver.onTextureChanged: {
                        liveTimer.transientTurnOnLive()
                    }

                    TextureProviderIndirection {
                        id: textureProviderIndirection

                        // This should not be necessary anymore since `DualKawaseBlur`
                        // does not create layer for the source implicitly as `MultiEffect`
                        // or `FastBlur` does as they deem necessary (in this case, it
                        // is not necessary). But due to a Qt bug when `mipmap: true` is
                        // used where texture sampling becomes broken, we need this as
                        // `QSGTextureView` has a workaround for that bug. This is totally
                        // acceptable as there is virtually no overhead.
                        source: cover
                    }

                    Component.onCompleted: {
                        // Blur layers are effect-size dependent, so once the user starts resizing the window (hence the effect),
                        // we should either momentarily turn on live, or repeatedly call `scheduleUpdate()`. Due to the optimization,
                        // calling `scheduleUpdate()` would continuously create and release intermediate layers, which would be a
                        // really bad idea. So instead, we turn on live and after some time passes turn it off again.
                        widthChanged.connect(liveTimer, liveTimer.transientTurnOnLive)
                        heightChanged.connect(liveTimer, liveTimer.transientTurnOnLive)

                        // In case texture provider observer never signals texture change:
                        liveTimer.transientTurnOnLive()
                    }

                    Timer {
                        id: liveTimer

                        repeat: false
                        interval: VLCStyle.duration_humanMoment

                        function transientTurnOnLive() {
                            if (!blurredBackground.sourceTextureIsValid)
                                return
                            blurredBackground.live = true
                            liveTimer.restart()
                        }

                        onTriggered: {
                            blurredBackground.live = false
                        }
                    }
                }

                MouseArea {
                    id: centerContent

                    readonly property ColorContext colorContext: ColorContext {
                        id: centerTheme
                        colorSet: ColorContext.View
                    }

                    anchors.fill: parent
                    anchors.topMargin: VLCStyle.margin_xsmall + audioFocusScope.topPadding
                    anchors.bottomMargin: VLCStyle.margin_xsmall + audioFocusScope.bottomPadding

                    onWheel: (wheel) => {
                        wheel.accepted = true
                        wheelToVlc.qmlWheelEvent(wheel)
                    }

                    TouchDragHandler {
                        wheelToVLCConverter: wheelToVlc
                    }

                    WheelToVLCConverter {
                        id: wheelToVlc

                        onVlcWheelKey: (key) => MainCtx.sendVLCHotkey(key)
                    }

                    // ── Two-panel lyrics layout ────────────────────────
                    Item {
                        id: leftSideParent

                        visible: (opacity > 0.0) || (width > 0.0)

                        opacity: (lyricsLoader.item ? 1.0 : 0.0)

                        Behavior on opacity {
                            id: opacityBehavior

                            enabled: false

                            NumberAnimation {
                                duration: VLCStyle.duration_long

                                easing.type: Easing.InOutSine
                            }

                            Component.onCompleted: {
                                // The animation should not be used at initialization:
                                Qt.callLater(() => { opacityBehavior.enabled = true })
                            }
                        }

                        anchors.top: parent.top
                        anchors.topMargin: VLCStyle.margin_large
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left

                        width: lyricsLoader.item ? (parent.width * 0.6) : 0.0

                        Behavior on width {
                            id: widthBehavior

                            enabled: false

                            NumberAnimation {
                                duration: VLCStyle.duration_long

                                easing.type: Easing.InOutSine
                            }

                            Component.onCompleted: {
                                // The animation should not be used at initialization:
                                Qt.callLater(() => { widthBehavior.enabled = true })
                            }
                        }

                        Loader {
                            id: lyricsLoader

                            active: audioFocusScope.lyricsLayoutActive
                            sourceComponent: T.Pane {
                                // Swallow wheel events so scrolling the lyrics
                                // does not bubble up to the player and change
                                // the volume.
                                wheelEnabled: true

                                // Expose the inner Flickable's sync flag so the
                                // Loader's `item.lyricsSyncToPlayback` reaches
                                // through to LyricsFlickable in both directions.
                                property alias lyricsSyncToPlayback: lyricsFlickable.lyricsSyncToPlayback

                                implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                                                        implicitContentWidth + leftPadding + rightPadding)
                                implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                                                         implicitContentHeight + topPadding + bottomPadding)

                                contentItem: LyricsFlickable {
                                    id: lyricsFlickable

                                    onPlayerPositionChangeRequested: (time) => {
                                        Player.setTime(time)
                                        lyricsFlickable.lyricsSyncToPlayback = true
                                    }
                                }
                            }
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter

                            height: Math.min(implicitHeight, parent.height)
                        }
                    }

                    Item {
                        id: rightSideParent

                        visible: leftSideParent.visible

                        anchors.top: parent.top
                        anchors.topMargin: VLCStyle.margin_large
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.left: leftSideParent.right
                    }

                    ColumnLayout {
                        parent: leftSideParent.visible ? rightSideParent : centerContent

                        anchors.centerIn: parent
                        spacing: 0

                        Item {
                            id: coverItem
                            // no wider than the pane it sits in (a narrow window, lyrics)
                            Layout.preferredHeight: Math.min(rootPlayer.height / sizeConstant,
                                                             parent.parent.width - 2 * VLCStyle.margin_large)
                            Layout.preferredWidth: cover.paintedWidth
                            Layout.maximumHeight: centerContent.height
                            Layout.alignment: Qt.AlignHCenter

                            // redesign: Figma "Player - Music": the cover is 737 high in a 1080 high window
                            readonly property real sizeConstant: 1080 / 737

                            // the texture of the cover and of the blurred background, and the cover
                            // size; shown through roundedCover below (falls back to itself where
                            // rounding is not available)
                            Image {
                                id: cover

                                visible: roundedCover.effectiveRadius <= 0

                                //source aspect ratio
                                readonly property real sar: paintedWidth / paintedHeight
                                readonly property int maximumWidth: Helpers.alignUp((Screen.desktopAvailableWidth * eDPR / coverItem.sizeConstant), 32)
                                readonly property int maximumHeight: Helpers.alignUp((Screen.desktopAvailableHeight * eDPR / coverItem.sizeConstant), 32)

                                readonly property int maximumSize: Math.min(maximumWidth, maximumHeight)

                                readonly property real eDPR: MainCtx.effectiveDevicePixelRatio(Window.window)

                                readonly property url targetSource: VLCAccessImage.uri(rootPlayer.coverSource)

                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: targetSource
                                fillMode: Image.PreserveAspectFit
                                mipmap: true
                                cache: false
                                asynchronous: true

                                onTargetSourceChanged: {
                                    cover.source = targetSource
                                }

                                onSourceChanged: {
                                    liveTimer.transientTurnOnLive()
                                }

                                onStatusChanged: {
                                    if (status === Image.Error) {
                                        cover.source = VLCStyle.noArtAlbumCover
                                    }
                                }

                                sourceSize: Qt.size(maximumSize, maximumSize)

                                Accessible.role: Accessible.Graphic
                                Accessible.name: qsTr("Cover")

                                Component.onCompleted: {
                                    // After the update on source change, there can be another update when the mipmaps are generated.
                                    // We intentionally do not wait for this, initially using non-mipmapped source should be okay. As
                                    // the user should not be greeted with a black background until the mipmaps are ready, let alone
                                    // the possibility of knowing if the mipmaps are actually going to be ready as expected.
                                    // If the texture is not valid yet (which is signalled the latest), blur effect is going to queue
                                    // an update itself similar to the case when the source itself changes, so we do not check validity
                                    // of the texture here.
                                    blurredBackground.sourceTextureProviderObserver.hasMipmapsChanged.connect(blurredBackground,
                                                                                                              (hasMipmaps /*: bool */) => {
                                                                                                                  if (hasMipmaps) {
                                                                                                                      blurredBackground.scheduleUpdate()
                                                                                                                  }
                                                                                                              })
                                }
                            }

                            // redesign: the cover with rounded corners (Figma "Player - Music":
                            // radius 20, P6-04), drawn from the cover's own texture
                            Widgets.ImageExt {
                                id: roundedCover

                                anchors.fill: cover
                                textureProviderItem: cover
                                fillMode: Image.PreserveAspectFit
                                radius: VLCStyle.rd_radius_cover

                                // Figma: one faint glow, #FFFFFF 3 %, no offset, blur 90.5
                                Widgets.RoundedRectangleShadow {
                                    color: VLCStyle.palette.rdCoverGlow
                                    blurRadius: VLCStyle.dp(90.5, VLCStyle.scale)
                                }
                            }
                        }

                        // redesign: "title - artist" under the cover (Figma "Player - Music":
                        // Inter 500 24, FG/A1; P6-04, IB-23)
                        Text {
                            id: captionLabel

                            Layout.alignment: Qt.AlignHCenter
                            // Figma: the space between the bars is split in three equal gaps:
                            // above the cover, between cover and caption, below the caption
                            Layout.topMargin: Math.max(VLCStyle.margin_small,
                                                       (centerContent.height + 2 * VLCStyle.margin_xsmall
                                                        - coverItem.Layout.preferredHeight - implicitHeight) / 3)
                            // the column's pane: the whole view, or the right pane with lyrics
                            Layout.maximumWidth: parent.parent.width - 2 * VLCStyle.margin_large

                            Binding on visible {
                                delayed: true
                                when: captionLabel.componentCompleted
                                value: captionLabel.text !== "" && centerContent.height > (captionLabel.y + captionLabel.height)
                            }

                            property bool componentCompleted: false

                            Component.onCompleted: {
                                componentCompleted = true
                            }

                            readonly property string _title: Player.title !== "" ? Player.title : Player.name

                            text: Player.artist !== "" ? qsTr("%1 - %2").arg(_title).arg(Player.artist) : _title
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            font.family: VLCStyle.rd_fontFamily
                            font.pixelSize: VLCStyle.rd_fontSize_title
                            font.weight: Font.Medium
                            color: VLCStyle.palette.rdFgA1

                            Accessible.role: Accessible.StaticText
                            Accessible.name: text
                        }

                        Widgets.SubtitleLabel {
                            id: lyricsLabel

                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: VLCStyle.margin_large
                            // Pin width and height so the surrounding centered
                            // column does not shift when the current lyric
                            // changes between empty / 1 line / 2 lines. Text
                            // exceeding two lines wraps then elides on line 2.
                            Layout.preferredWidth: parent.parent.width - VLCStyle.margin_xlarge * 2
                            Layout.preferredHeight: (lyricsLabelTextMetrics.height * 2) + VLCStyle.margin_xxxsmall

                            visible: false

                            Binding on visible {
                                delayed: true
                                when: lyricsLabel.componentCompleted

                                // Stay visible (reserving the 2-line slot) for the
                                // entire track when it has any lyrics, so the
                                // layout does not collapse between lyric lines.
                                value: Player.hasLyrics && !audioFocusScope.lyricsLayoutActive &&
                                       (centerContent.height > (lyricsLabel.y + lyricsLabel.height))
                            }

                            property bool componentCompleted: false

                            Component.onCompleted: {
                                componentCompleted = true
                            }

                            elide: Text.ElideRight

                            text: Player.currentLyric.text
                            font.pixelSize: VLCStyle.fontSize_xlarge
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.WordWrap
                            color: centerTheme.fg.primary

                            // TODO: Do not use `Binding` when minimum Qt is 6.12:
                            Binding {
                                target: lyricsLabel
                                property: "mutabilityGroup"
                                when: (lyricsLabel.mutabilityGroup !== undefined)
                                value: (Player.playingState === Player.PLAYING_STATE_PLAYING) ? Item.ModerateMutabilityGroup
                                                                                              : Item.StaticMutabilityGroup
                            }

                            TextMetrics {
                                id: lyricsLabelTextMetrics
                                font: lyricsLabel.font
                                text: "TEXT"
                            }

                            Accessible.role: Accessible.StaticText
                            Accessible.name: qsTr("Lyrics")
                            Accessible.description: text
                        }

                        Widgets.NavigableRow {
                            id: audioControls

                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: VLCStyle.margin_large

                            Binding on visible {
                                delayed: true
                                when: audioControls.componentCompleted
                                value: Player.videoTracks.count === 0 && centerContent.height > (audioControls.y + audioControls.height)
                            }

                            focus: true
                            spacing: VLCStyle.margin_xxsmall
                            Navigation.parentItem: rootPlayer
                            Navigation.upItem: topBar
                            Navigation.downItem: syncToPlaybackCheckBox

                            property bool componentCompleted: false

                            Component.onCompleted: {
                                componentCompleted = true
                            }

                            Widgets.IconToolButton {
                                text: VLCIcons.skip_back
                                font.pixelSize: VLCStyle.icon_audioPlayerButton
                                onClicked: Player.jumpBwd()
                                description: qsTr("Step back")

                                AccessibleCompat.id: "audioStepBackButton"
                            }

                            Widgets.IconToolButton {
                                text: VLCIcons.visualization
                                font.pixelSize: VLCStyle.icon_audioPlayerButton
                                onClicked: Player.toggleVisualization()
                                description: qsTr("Visualization")

                                AccessibleCompat.id: "audioVisualizationButton"
                            }

                            Widgets.IconToolButton {
                                text: VLCIcons.topbar_music
                                font.pixelSize: VLCStyle.icon_audioPlayerButton
                                checked: MainCtx.lyricsMode
                                onClicked: MainCtx.lyricsMode = !MainCtx.lyricsMode
                                description: qsTr("Lyrics")

                                Accessible.role: Accessible.Button
                                Accessible.name: qsTr("Toggle lyrics view")
                                AccessibleCompat.id: "audioLyricsButton"
                            }

                            Widgets.IconToolButton{
                                text: VLCIcons.skip_for
                                font.pixelSize: VLCStyle.icon_audioPlayerButton
                                onClicked: Player.jumpFwd()
                                description: qsTr("Step forward")

                                AccessibleCompat.id: "audioStepForwardButton"
                            }
                        }

                        // "Sync to Playback" checkbox pinned to bottom of right panel
                        Widgets.CheckBoxExt {
                            id: syncToPlaybackCheckBox

                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: VLCStyle.margin_small

                            visible: false

                            Binding on visible {
                                delayed: true
                                when: syncToPlaybackCheckBox.componentCompleted
                                value: audioFocusScope.lyricsLayoutActive &&
                                       centerContent.height > (syncToPlaybackCheckBox.y + syncToPlaybackCheckBox.height)
                            }

                            property bool componentCompleted: false

                            Component.onCompleted: {
                                componentCompleted = true
                            }

                            text: qsTr("Sync lyrics to playback")
                            // Use a Binding element rather than an inline binding
                            // so manual clicks (which write `checked` directly)
                            // don't permanently break the source-of-truth link.
                            Binding on checked {
                                when: lyricsLoader.item
                                value: lyricsLoader.item ? lyricsLoader.item.lyricsSyncToPlayback : true
                                restoreMode: Binding.RestoreBindingOrValue
                            }
                            onClicked: {
                                if (lyricsLoader.item)
                                    lyricsLoader.item.lyricsSyncToPlayback = checked
                            }

                            Accessible.role: Accessible.CheckBox
                            Accessible.name: qsTr("Sync lyrics to playback position")
                            AccessibleCompat.id: "syncToPlaybackCheckBox"

                            Navigation.parentItem: rootPlayer
                            Navigation.upItem: audioControls
                            Navigation.downItem: Player.isInteractive ? toggleControlBarButton : controlBar
                        }
                    }

                    Widgets.SubtitleLabel {
                        id: labelVolume

                        anchors.right: parent.right
                        anchors.top: parent.top

                        anchors.rightMargin: VLCStyle.margin_normal
                        anchors.topMargin: VLCStyle.margin_xxsmall

                        visible: false

                        text: qsTr("Volume %1%").arg(Math.round(Player.volume * 100))

                        color: centerTheme.fg.primary

                        font.weight: Font.Normal

                        Connections {
                            target: Player

                            function onVolumeChanged() {
                                animationVolume.restart()
                            }
                        }

                        SequentialAnimation {
                            id: animationVolume

                            PropertyAction { target: labelVolume; property: "visible"; value: true }

                            PauseAnimation { duration: VLCStyle.duration_humanMoment }

                            PropertyAction { target: labelVolume; property: "visible"; value: false }
                        }
                    }

                }
            }
        }
    }

    // redesign: the video sits in an inset area with rounded corners, framed by the window color
    // (video 9:29 / 11:41 zoomed: ~6 px frame on the sides and bottom, ~8 px inner radius; with the
    // bars hidden a thin frame stays all around, video 3:50 and 5:28). Drawn above the video, below
    // the bars (W3.7).
    // Qt is built without Canvas and Shapes, so the frame is the thick border of a rounded
    // rectangle: its inner edge is the rounded video opening, its outer edge lies outside the
    // player. The opening follows the bars' fade, so the frame is split into a top and a bottom
    // half, each a fixed-size rectangle that only moves with its edge (no geometry is rebuilt
    // during a fade) and is clipped to its half.
    Item {
        id: videoFrame

        anchors.fill: parent
        // next to the compact library the opening starts at the library's edge (Figma
        // Player.png: no frame between the library and the video)
        anchors.leftMargin: rootPlayer._videoInset > 0 ? rootPlayer._videoInset - inset : 0
        visible: MainCtx.hasEmbededVideo && (MainCtx.intfMainWindow.visibility !== Window.FullScreen)
        enabled: false

        // Figma "Frame 312": 10 px of BG/A3 frame, visible corner about 9 px (visual audit A7, A8)
        readonly property real inset: VLCStyle.dp(10, VLCStyle.scale)
        readonly property real innerRadius: VLCStyle.dp(9, VLCStyle.scale)
        // the opening follows the bars' fade, so it grows and shrinks with them instead of
        // jumping once a bar has faded out (bars auto-hide over the video, Decision 30)
        readonly property real topEdge: inset + (topBar.height - inset) * (topBar.visible ? topBar.opacity : 0)
        readonly property real bottomEdge: height - inset
                                           - (controlBar.height - inset) * (controlBar.visible ? controlBar.opacity : 0)
        // fixed while the bars fade (whole pixels: a rectangle's border width is pixel aligned)
        readonly property real frameWidth: Math.ceil(2 * Math.max(topBar.height, controlBar.height)
                                                     + 2 * innerRadius + VLCStyle.dp(10, VLCStyle.scale))
        readonly property real openingWidth: Math.max(0, width - 2 * inset)
        // smaller corners when the opening is too small for them
        readonly property real cornerRadius: Math.min(innerRadius, openingWidth / 2,
                                                      Math.max(0, bottomEdge - topEdge) / 2)
        // the halves meet in the middle; in a tiny window, inside the opening (or where it closed)
        readonly property real split: Math.min(Math.max(height / 2, topEdge), bottomEdge)

        Repeater {
            model: 2 // top half, bottom half

            delegate: Item {
                id: frameHalf

                required property int index
                readonly property bool atTop: index === 0

                y: atTop ? 0 : videoFrame.split
                width: videoFrame.width
                height: atTop ? videoFrame.split : videoFrame.height - videoFrame.split
                clip: true

                // its opening is as tall as the player, so only the edge of this half shows
                Rectangle {
                    x: videoFrame.inset - videoFrame.frameWidth
                    y: (frameHalf.atTop ? videoFrame.topEdge
                                        : videoFrame.bottomEdge - videoFrame.height - frameHalf.y)
                       - videoFrame.frameWidth
                    width: videoFrame.openingWidth + 2 * videoFrame.frameWidth
                    height: videoFrame.height + 2 * videoFrame.frameWidth

                    color: "transparent"
                    border.width: videoFrame.frameWidth
                    border.color: VLCStyle.palette.rdBgA3
                    radius: videoFrame.frameWidth + videoFrame.cornerRadius
                    antialiasing: true
                }
            }
        }
    }

    // redesign: the compact library (RdLibrarySidebar, 427 px: rail 50 + panel 377) between the
    // top bar and the control bar; it slides in from the left edge over the video (opaque: the
    // video is a native surface under the scene)
    Item {
        id: libraryHost

        anchors.left: parent.left
        anchors.top: topBar.bottom
        anchors.bottom: controlBar.top
        width: rootPlayer._libraryWidth
        visible: width > 0
        clip: rootPlayer._libraryProgress < 1
        z: 1

        Loader {
            id: librarySidebar

            x: libraryHost.width - width
            width: rootPlayer._libraryFullWidth
            height: libraryHost.height

            enabled: rootPlayer._libraryShown
            active: rootPlayer._libraryActivated
            asynchronous: rootPlayer._libraryAsync
            source: "qrc:///qt/qml/VLC/MediaLibrary/RdLibrarySidebar.qml"
        }
    }

    // redesign: a click outside the open player panel closes it (INTERACTIONS.md section 2).
    // Over the video (or the audio view) the click only closes the panel: it does not reach the
    // video, which would pause on the click (mouse-pause-policy) and switch to fullscreen on a
    // double click; the second click of a quick double click is held back too. A right click
    // closes the panel and opens the right-click menu. Clicks on the bars are handled below.
    MouseArea {
        id: panelDismissArea

        anchors.fill: parent

        enabled: RdPanels.current !== "" || dismissClickGuard.running || pressed
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onPressed: {
            if (RdPanels.current === "")
                return
            RdPanels.close()
            dismissClickGuard.restart()
        }

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton)
                playerMenu.popupAtCursor()
        }

        Timer {
            id: dismissClickGuard

            interval: Qt.styleHints.mouseDoubleClickInterval
        }
    }

    // a press on the bars (or anywhere else in the player outside the panel) closes the panel
    // once the click is done, unless the click itself changed the panel: the button of the open
    // panel toggles it, another panel button switches to its panel without the panel flashing
    // closed in between. The handler only observes: the click still reaches the control (play,
    // seek, volume ... work in the same click). It sits on an empty item above everything in the
    // player, because Qt delivers a press that a control accepted to the handlers of the items
    // above that control, not to its parents.
    Item {
        anchors.fill: parent
        z: 100

        PointHandler {
            id: panelOutsidePress

            enabled: RdPanels.current !== ""
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

            property string _panel: ""

            function _inside(item, scenePoint) {
                if (!item || !item.visible)
                    return false
                const p = item.mapFromItem(null, scenePoint.x, scenePoint.y)
                return p.x >= 0 && p.y >= 0 && p.x < item.width && p.y < item.height
            }

            onActiveChanged: {
                if (active) {
                    const p = point.scenePressPosition
                    const panel = RdPanels.tracksOpen ? tracksPopupLoader
                                : RdPanels.settingsOpen ? settingsPanelLoader
                                : RdPanels.queueOpen ? queuePanelLoader : null
                    _panel = _inside(panel, p) ? "" : RdPanels.current
                } else if (_panel !== "") {
                    const panel = _panel
                    _panel = ""
                    Qt.callLater(() => {
                        if (RdPanels.current === panel)
                            RdPanels.close()
                    })
                }
            }
        }
    }

    TopBar {
        id: topBar

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        z: 1

        topMargin: VLCStyle.applicationVerticalMargin
        sideMargin: VLCStyle.applicationHorizontalMargin

        textWidth: playlistVisibility.isPlaylistVisible
                 ? rootPlayer.width - playlistpopup.width
                 : rootPlayer.width

        focus: true
        // the media's title, or VLC's display name (the file name) when it has no title tag
        title: Player.title !== "" ? Player.title : Player.name

        pinControls: MainCtx.pinVideoControls
        libraryOpen: rootPlayer._libraryShown

        showCSD: MainCtx.clientSideDecoration && (MainCtx.intfMainWindow.visibility !== Window.FullScreen)
        showToolbar: MainCtx.hasToolbarMenu && (MainCtx.intfMainWindow.visibility !== Window.FullScreen)
        playlistVisible: playlistVisibility.isPlaylistVisible

        plListView: {
            if (playlistpopup.active)
                return playlistpopup.item
            else if (playlistWindowLoader?.status === Loader.Ready)
                return playlistWindowLoader.item.playlistView
            else
                return null
        }

        Navigation.parentItem: rootPlayer
        Navigation.downItem: {
            if (playlistVisibility.isPlaylistVisible)
                return playlistpopup
            if (MainCtx.hasEmbededVideo)
                return playerSpecializationLoader
            if (Player.isInteractive)
                return toggleControlBarButton
            return controlBar
        }

        //initial state value is "", using a binding avoid animation on startup
        Binding on state {
            when: playerToolbarVisibilityFSM.started
            value: rootPlayer._topBarVisible ? "visible" : "hidden"
        }

        onTogglePlaylistVisibility: playlistVisibility.togglePlaylistVisibility()

        onRequestLockUnlockAutoHide: (lock) => {
            rootPlayer.lockUnlockAutoHide(lock)
        }

        onBackRequested: {
            if (MainCtx.hasEmbededVideo && !MainCtx.canShowVideoPIP) {
               MainPlaylistController.stop()
            }
            MainCtx.playerView = false
        }

        onLibraryToggleRequested: rootPlayer.toggleLibrary(false)
        onFolderRequested: rootPlayer.toggleLibrary(true)

        // redesign: no acrylic background behind the top bar, it paints its own background
        // (BG/A3 in Dark, BG/A3 Transparent in Light, see TopBar.qml)

        FadeControllerStateGroup {
            target: topBar
        }
    }

    Loader {
        id: playlistpopup

        anchors {
            // NOTE: When the controls are pinned we display the playqueue under the topBar.
            top: (rootPlayer._controlsUnderVideo) ? topBar.bottom
                                                  : parent.top

            right: parent.right
            bottom: parent.bottom

            bottomMargin: parent.height - rootPlayer.positionSliderY
        }

        focus: false

        // redesign: the list button opens the queue sidebar instead of this pane, so the pane (and
        // its own play queue model) is only created the first time it is shown (VLC's play queue
        // hotkey, a docked queue left open in the library), then kept for its retract animation
        property bool _requested: false

        active: MainCtx.playqueuePanel.docked && _requested

        Binding on _requested {
            when: playlistVisibility.isPlaylistVisible
            value: true
            restoreMode: Binding.RestoreNone
        }

        //initial state value is "", using a binding avoid animation on startup
        Binding on state {
            when: playlistVisibility.started
            value: (status === Loader.Ready && playlistVisibility.isPlaylistVisible) ? "expanded" : "retracted"
        }

        Component.onCompleted: {
            Qt.callLater(() => { playlistTransition.enabled = true; })
        }

        states: [
            State {
                name: "expanded"
                PropertyChanges {
                    target: playlistpopup
                    width: playlistpopup.implicitWidth
                    visible: true
                }
           }, State {
                name: "retracted"
                PropertyChanges {
                    target: playlistpopup
                    width: 0
                    visible: false
                }
           }
        ]

        transitions: Transition {
            id: playlistTransition
            enabled: false

            from: "retracted"; to: "expanded";
            reversible: true

            SequentialAnimation {
                PropertyAction { property: "visible" }

                NumberAnimation {
                    property: "width"
                    duration: VLCStyle.duration_short
                    easing.type: Easing.InOutSine
                }
            }
        }

        sourceComponent: PlaylistPane {
            id: playlistView

            property real maximumWidth: (rootPlayer.width + playlistView.rightPadding) / 2

            implicitWidth: Helpers.clamp(MainCtx.playqueuePanel.width
                                 , playlistView.minimumWidth
                                 , playlistView.maximumWidth)
            height: playlistpopup.height

            useAcrylic: false
            focus: true

            wheelEnabled: true

            rightPadding: VLCStyle.applicationHorizontalMargin
            topPadding:  {
                if (rootPlayer._controlsUnderVideo)
                    return VLCStyle.margin_normal
                else
                    // NOTE: We increase the padding accordingly to avoid overlapping the TopBar.
                    return topBar.reservedHeight
            }
            bottomPadding: 0

            background: Rectangle {
                color: windowTheme.bg.primary.alpha(0.8)
            }

            view.fadingEdge.pixelAlignedForDPR: !controlBar.visible

            Navigation.parentItem: rootPlayer
            Navigation.upItem: topBar
            Navigation.downItem: Player.isInteractive ? toggleControlBarButton : controlBar
            Navigation.leftAction: closePlaylist
            Navigation.cancelAction: closePlaylist

            function closePlaylist() {
                playlistVisibility.togglePlaylistVisibility()
                if (audioControls.visible)
                    audioControls.forceActiveFocus()
                else
                    controlBar.forceActiveFocus()
            }


            Widgets.HorizontalResizeHandle {
                id: resizeHandle

                property bool _inhibitMainCtxUpdate: false

                parent: playlistView

                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    left: parent.left
                }

                atRight: false
                currentWidth: playlistpopup.width

                maximumWidth: playlistView.maximumWidth
                minimumWidth: playlistView.minimumWidth

                onRequestedWidthChanged: {
                    if (!_inhibitMainCtxUpdate)
                        MainCtx.playqueuePanel.width = requestedWidth
                }

                Component.onCompleted:  _updateFromMainCtx()

                function _updateFromMainCtx() {
                    if (requestedWidth === MainCtx.playqueuePanel.width)
                        return

                    _inhibitMainCtxUpdate = true
                    requestedWidth = MainCtx.playqueuePanel.width
                    _inhibitMainCtxUpdate = false
                }

                Connections {
                    target: MainCtx.playqueuePanel

                    function onWidthChanged() {
                        resizeHandle._updateFromMainCtx()
                    }
                }
            }
        }
    }

    Dialogs {
        z: 10
        bgContent: rootPlayer

        anchors {
            bottom: controlBar.visible ? controlBar.top : rootPlayer.bottom
            left: parent.left
            right: parent.right

            bottomMargin: (rootPlayer._controlsUnderVideo || !controlBar.visible)
                          ? 0 : - VLCStyle.margin_large
        }
    }

    Timer {
        // NavigationBox's visibility depends on this timer
        id: interactiveAutoHideTimer
        running: false
        repeat: false
        interval: 3000
    }

    NavigationBox {
        id: navBox
        visible: Player.isInteractive && navBox.show
                    && (interactiveAutoHideTimer.running
                    || navBox.hovered || !MainCtx.hasEmbededVideo)

        // drawn on the picture itself (translucent black box): keeps the night colors in every theme
        colorContext.palette: VLCStyle.darkPalette

        x: rootPlayer.x + VLCStyle.margin_normal + VLCStyle.applicationHorizontalMargin
        y: controlBar.y - navBox.height - VLCStyle.margin_normal

        dragXMin: 0
        dragXMax: rootPlayer.width - navBox.width
        dragYMin: 0
        dragYMax: rootPlayer.height - navBox.height

        Drag.onDragStarted: (controlId) => {
            navBox.x = drag.x
            navBox.y = drag.y
        }
    }

    Connections {
        target: MainCtx
        function onNavBoxToggled() { interactiveAutoHideTimer.restart() }
    }

    Connections {
        target: rootPlayer
        function onWidthChanged() {
            if (navBox.x > navBox.dragXMax)
                navBox.x = navBox.dragXMax
        }
        function onHeightChanged() {
            if (navBox.y > navBox.dragYMax)
                navBox.y = navBox.dragYMax
        }
    }

    Widgets.ButtonExt {
        id: toggleControlBarButton
        visible: Player.isInteractive
                 && MainCtx.hasEmbededVideo
                 && !(MainCtx.pinVideoControls && !Player.fullscreen)
                 && (interactiveAutoHideTimer.running === true
                     || controlBar.state !== "hidden" || toggleControlBarButton.hovered)
        focus: true
        anchors {
            bottom: controlBar.state === "hidden" ? parent.bottom : controlBar.top
            horizontalCenter: parent.horizontalCenter
        }
        iconSize: VLCStyle.icon_large
        iconTxt: controlBar.state === "hidden" ? VLCIcons.expand_inverted : VLCIcons.expand

        // drawn on the picture itself (no bar behind it): keeps the night colors in every theme
        colorContext.palette: VLCStyle.darkPalette

        Navigation.parentItem: rootPlayer
        Navigation.upItem: playlistVisibility.isPlaylistVisible ? playlistpopup : (MainCtx.hasEmbededVideo ? playerSpecializationLoader : topBar)
        Navigation.downItem: controlBar

        onClicked:{
            playerToolbarVisibilityFSM.askShow();
        }
    }

    Widgets.FloatingNotification {
        id: notif

        anchors {
            bottom: controlBar.top
            left: parent.left
            right: parent.right
            margins: VLCStyle.margin_large
        }
    }

    ControlBar {
        id: controlBar

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }

        hoverEnabled: true

        focus: true

        // redesign: one 54 px row (Figma "Controls": padding 11 top/bottom, 20 left/right inside the layout)
        rightPadding: VLCStyle.applicationHorizontalMargin
        leftPadding: VLCStyle.applicationHorizontalMargin
        topPadding: VLCStyle.rd_controlBarPaddingV
        bottomPadding: VLCStyle.applicationVerticalMargin + VLCStyle.rd_controlBarPaddingV

        textPosition: ControlBar.TimeTextPosition.Inline

        // hide right text so that it won't overlap with play queue
        showRemainingTime: (textPosition !== ControlBar.TimeTextPosition.AboveSlider)
                           || !playlistVisibility.isPlaylistVisible

        onStateChanged: {
            if (state === "visible")
                showChapterMarks()
        }

        Navigation.parentItem: rootPlayer
        Navigation.upItem: {
            if (playlistVisibility.isPlaylistVisible)
                return playlistpopup
            if (Player.isInteractive)
                return toggleControlBarButton
            if (!MainCtx.hasEmbededVideo)
                return playerSpecializationLoader
            return topBar
        }

        //initial state value is "", using a binding avoid animation on startup
        Binding on state {
            when: playerToolbarVisibilityFSM.started
            value: rootPlayer._controlBarVisible ? "visible" : "hidden"
        }

        onRequestLockUnlockAutoHide: (lock) => rootPlayer.lockUnlockAutoHide(lock)

        identifier: (Player.hasVideoOutput) ? PlayerControlbarModel.Videoplayer
                                            : PlayerControlbarModel.Audioplayer

        onHoveredChanged: rootPlayer.lockUnlockAutoHide(hovered)

        background: Rectangle {
            id: controlBarBackground

            visible: true

            opacity: {
                if (controlBar.textPosition === ControlBar.TimeTextPosition.Inline) {
                    return 1.0
                } else if (MainCtx.hasEmbededVideo && !MainCtx.pinVideoControls && !rootPlayer.displayFadeRectangles) {
                    return 0.6
                } else if ((Window.visibility === Window.FullScreen) && MainCtx.hasEmbededVideo) {
                    return MainCtx.pinOpacity
                } else if (AcrylicController.enabled || !MainCtx.hasEmbededVideo) {
                    return 0.7
                } else {
                    return 1.0
                }
            }

            // redesign: opaque, like the panels and menus, so the fullscreen bar over the native
            // video looks like the windowed one: BG/A3 in Dark (the dark Player frames override
            // the bar fill to BG/A3, visual audit A2, like the top bar), BG/A3 Transparent made
            // opaque in Light (its 95 % assumes a background blur); a 1 px Divider/Dim top line
            // only in the light theme (Figma "Player - Light" has it, the dark frames have none)
            color: (controlBar.textPosition !== ControlBar.TimeTextPosition.Inline) ? windowTheme.bg.primary
                   : VLCStyle.palette.isDark ? VLCStyle.palette.rdBgA3
                                             : Qt.alpha(VLCStyle.palette.rdBgA3Transparent, 1.0)

            Rectangle {
                visible: controlBar.textPosition === ControlBar.TimeTextPosition.Inline && !VLCStyle.palette.isDark
                width: parent.width
                height: VLCStyle.dp(1, VLCStyle.scale)
                color: VLCStyle.palette.rdDividerDim
            }
        }

        FadeControllerStateGroup {
            target: controlBar
        }
    }

    // redesign: player panels. An open panel keeps the bars visible (F-06). Each panel is created
    // the first time it opens and then kept, so it reopens instantly; a moment after the player
    // shows, the panels are also created in the background, so the first click opens them within
    // a frame without slowing down the switch to the player (INTERACTIONS.md section 0).
    property bool _panelsPrewarm: false

    Timer {
        running: true
        interval: VLCStyle.duration_veryLong
        onTriggered: rootPlayer._panelsPrewarm = true
    }

    component PanelLoader: Loader {
        id: panelLoader

        // the panel is open
        property bool open: false
        property bool prewarm: false

        active: false
        // a panel that is needed now is created at once (this also completes a background
        // creation in progress)
        asynchronous: !panelLoader.open

        Binding on active {
            when: panelLoader.open || panelLoader.prewarm
            value: true
            restoreMode: Binding.RestoreNone
        }
    }

    // tracks popup (subtitle and audio buttons), sized by its content
    PanelLoader {
        id: tracksPopupLoader

        anchors.right: parent.right
        anchors.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
        anchors.bottom: controlBar.top
        anchors.bottomMargin: VLCStyle.dp(20, VLCStyle.scale)
        z: 2

        open: RdPanels.tracksOpen
        prewarm: rootPlayer._panelsPrewarm

        sourceComponent: TracksPopup {
            width: VLCStyle.rd_sidePanelWidth
            height: implicitHeight
            maximumHeight: controlBar.y - tracksPopupLoader.anchors.bottomMargin
                           - (topBar.visible ? topBar.y + topBar.height : 0)
        }
    }

    // settings sidebar (gear) and queue sidebar (list button): inside the video area at the right,
    // 20 px from both bars and the right edge (video 7:12, 9:29; Figma "queue" 491:1781 400 wide)
    PanelLoader {
        id: settingsPanelLoader

        anchors.right: parent.right
        anchors.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
        anchors.top: topBar.bottom
        anchors.topMargin: VLCStyle.dp(20, VLCStyle.scale)
        anchors.bottom: controlBar.top
        anchors.bottomMargin: VLCStyle.dp(20, VLCStyle.scale)
        width: VLCStyle.rd_sidePanelWidth
        z: 2

        open: RdPanels.settingsOpen
        prewarm: rootPlayer._panelsPrewarm

        sourceComponent: SettingsSidebar {
            visible: RdPanels.settingsOpen
        }
    }

    PanelLoader {
        id: queuePanelLoader

        anchors.right: parent.right
        anchors.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
        anchors.top: topBar.bottom
        anchors.topMargin: VLCStyle.dp(20, VLCStyle.scale)
        anchors.bottom: controlBar.top
        anchors.bottomMargin: VLCStyle.dp(20, VLCStyle.scale)
        width: VLCStyle.rd_sidePanelWidth
        z: 2

        open: RdPanels.queueOpen
        prewarm: rootPlayer._panelsPrewarm

        sourceComponent: QueueSidebar {
            visible: RdPanels.queueOpen
        }
    }

    // an open panel or the compact library keeps both bars visible (F-06, Decision 30)
    property bool _panelLocked: false

    function _updatePanelLock() {
        const open = RdPanels.current !== "" || rootPlayer._libraryShown
        if (open === rootPlayer._panelLocked)
            return
        rootPlayer._panelLocked = open
        // a hidden toolbar FSM ignores lock(): show it first so lock and unlock stay balanced
        if (open && !playerToolbarVisibilityFSM.isVisible)
            playerToolbarVisibilityFSM.askShow()
        rootPlayer.lockUnlockAutoHide(open)
    }

    Connections {
        target: RdPanels

        function onCurrentChanged() {
            rootPlayer._updatePanelLock()
        }
    }

    // the compact library stays open after a visit to the full library: lock the bars once the
    // toolbar FSM runs
    Connections {
        target: playerToolbarVisibilityFSM

        function onStartedChanged() {
            if (playerToolbarVisibilityFSM.started) {
                // a lock() before the start went nowhere: lock again
                rootPlayer._panelLocked = false
                rootPlayer._updatePanelLock()
            }
        }
    }

    // Escape closes the open player panel first, then shows the UI again after Hide UI (a second
    // Escape then leaves fullscreen as usual). A shortcut runs before the focused control's own
    // cancel action (the control bar would otherwise leave the player).
    Shortcut {
        sequences: [StandardKey.Cancel]
        enabled: RdPanels.current !== "" || RdPanels.uiHidden
        onActivated: {
            if (RdPanels.current !== "")
                RdPanels.close()
            else
                RdPanels.uiHidden = false
        }
    }

    // the tracks popup belongs to the current file: close it when the media changes
    Connections {
        target: Player

        function onInputChanged() {
            if (RdPanels.tracksOpen)
                RdPanels.close()
        }
    }

    // redesign: resume toast centered just above the control bar (video 14:00-14:10, W3.8)
    ResumeDialog {
        id: resumeToast

        anchors.horizontalCenter: parent.horizontalCenter
        // centered over the video area, right of the compact library
        anchors.horizontalCenterOffset: rootPlayer._videoInset / 2
        anchors.bottom: controlBar.top
        // Figma "continue": 24 px above the control bar (visual audit A21)
        anchors.bottomMargin: VLCStyle.dp(24, VLCStyle.scale)
        z: 2

        maxWidth: Math.min(VLCStyle.dp(552, VLCStyle.scale),
                           rootPlayer.width - rootPlayer._videoInset - 2 * VLCStyle.margin_normal)

        Navigation.parentItem: rootPlayer

        onVisibleChanged: rootPlayer.lockUnlockAutoHide(visible)
    }

    // redesign: right-click menu and Hide UI (W4.10); the video's right click arrives through
    // DialogsProvider, the audio view's here
    RdPlayerMenu {
        id: playerMenu

        onShownChanged: rootPlayer.lockUnlockAutoHide(shown)
    }

    // redesign: a right click on the control bar (its buttons included) opens the right-click
    // menu too, like a right click on the video; the top bar keeps the window menu of its
    // client-side decorations
    TapHandler {
        parent: controlBar
        acceptedButtons: Qt.RightButton

        onTapped: playerMenu.popupAtCursor()
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        enabled: !MainCtx.hasEmbededVideo

        onTapped: (eventPoint, button) => {
            if (button & Qt.RightButton) {
                playerMenu.popupAtCursor()
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton | Qt.ForwardButton
        propagateComposedEvents: true
        cursorShape: undefined
        // with the compact library open the mouse buttons go back and forward in the library
        onClicked: (mouse) => {
            if (rootPlayer._libraryShown && librarySidebar.item) {
                if (mouse.button === Qt.BackButton)
                    librarySidebar.item.goBack()
                else
                    librarySidebar.item.goForward()
            } else if (mouse.button === Qt.BackButton) {
                MainCtx.playerView = false
            }
        }
    }

    //filter key events to keep toolbar
    //visible when user navigates within the control bar
    KeyEventFilter {
    id: filter
    target: MainCtx.intfMainWindow

        Keys.onPressed: (event) => {
            if (Player.isInteractive)
                interactiveAutoHideTimer.restart()
            else
                playerToolbarVisibilityFSM.keyboardMove()
        }
    }
}
