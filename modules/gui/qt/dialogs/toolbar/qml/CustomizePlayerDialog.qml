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

// redesign (W8.1a, video 19:12-19:28, Figma "Player - customize" 2107:5604): Customize Player,
// VLC's toolbar editor in the redesign. "One big frame in the center of VLC filled with buttons and
// icons and outlines": a 1048 wide box over the window (BG/B1, radius 14, shadow; header BG/B2 94
// high with the title and the description; the palette of controls; Cancel / Save footer) and,
// at the bottom of the window where the control bar is, the edited bar with dashed outlines.
// Controls are dragged from the box into the bar, around in it, and back into the box to remove
// them. VLC's layout profiles (select, new, duplicate, rename, delete) are in the title row and
// its three player layouts (video, audio, mini player) in the footer, since the design has no
// place for them (profiles move to the main menu with W8.2).
// Opens and closes instantly (Decision 32). Save keeps the changes, Cancel / X / Escape restore
// the saved layouts (VLC's toolbar editor semantics); the live bars follow every change.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.PlayerControls

T.Popup {
    id: root

    // player layout being edited (PlayerControlbarModel.PlayerIdentifier)
    property int identifier: PlayerControlbarModel.Videoplayer

    readonly property var playerModel: {
        const profile = MainCtx.controlbarProfileModel.currentModel
        return profile ? profile.getModel(identifier) : null
    }

    // something to save: a layout changed, or the profiles (added, removed, renamed, selected)
    property bool _profilesChanged: false
    readonly property bool dirty: _profilesChanged
                                  || (!!MainCtx.controlbarProfileModel.currentModel
                                      && MainCtx.controlbarProfileModel.currentModel.dirty)

    property bool _accepted: false

    // the window without the client side decoration's shadow margin
    readonly property real _margin: MainCtx.windowExtendedMargin
    readonly property real _availableWidth: parent ? parent.width - 2 * _margin : VLCStyle.rd_dialogWidth
    readonly property real _availableHeight: parent ? parent.height - 2 * _margin : VLCStyle.rd_dialogHeight

    property Item _restoreFocusItem: null

    function openDialog() {
        if (opened)
            return

        // an item inside another popup (the main menu that opened this dialog) closes with it,
        // so the focus goes back to the window content instead
        const window = MainCtx.intfMainWindow
        let focusItem = (window && window.activeFocusItem) ? window.activeFocusItem : null
        for (let item = focusItem; item; item = item.parent) {
            if (item === root.parent) {
                focusItem = null
                break
            }
        }
        _restoreFocusItem = focusItem

        open()
    }

    function accept() {
        _accepted = true
        close()
    }

    parent: T.Overlay.overlay
    x: _margin
    y: _margin
    width: _availableWidth
    height: _availableHeight

    padding: 0
    modal: true
    // the player stays visible behind the box (Figma: no dimming)
    dim: false
    focus: true
    closePolicy: T.Popup.CloseOnEscape

    // while open, keys go to the dialog instead of VLC's hotkeys (RdPanels.modalCount)
    property bool _holdsModal: false

    Component.onDestruction: {
        if (_holdsModal) {
            RdPanels.releaseModal()
            _holdsModal = false
        }
    }

    onAboutToShow: {
        if (!_holdsModal) {
            RdPanels.acquireModal()
            _holdsModal = true
        }
        _accepted = false
        _profilesChanged = false

        // what Cancel goes back to (VLC's toolbar editor saves first too)
        MainCtx.controlbarProfileModel.save(false)

        // the layout of what is on screen: the player's video or audio bar, else the mini player
        if (MainCtx.effectiveMainInterfaceMode === MainCtx.MAININTERFACE_MODE_PLAYER)
            identifier = Player.hasVideoOutput ? PlayerControlbarModel.Videoplayer
                                               : PlayerControlbarModel.Audioplayer
        else
            identifier = PlayerControlbarModel.Miniplayer

        paletteGrid.refresh()
        body.fitContent()
        paletteGrid.positionViewAtBeginning()
        content.forceActiveFocus(Qt.PopupFocusReason)
    }

    // keys go back to the player as soon as the dialog starts to close
    onAboutToHide: {
        if (_holdsModal) {
            RdPanels.releaseModal()
            _holdsModal = false
        }
        profileMenu.close()
        namePrompt.close()
        if (_restoreFocusItem)
            _restoreFocusItem.forceActiveFocus(Qt.PopupFocusReason)
    }

    onClosed: {
        if (_accepted)
            MainCtx.controlbarProfileModel.save()
        else
            MainCtx.controlbarProfileModel.reload()

        const window = MainCtx.intfMainWindow
        if (_restoreFocusItem && _restoreFocusItem.visible
                && (!window || window.activeFocusItem !== _restoreFocusItem))
            _restoreFocusItem.forceActiveFocus(Qt.PopupFocusReason)
        _restoreFocusItem = null
    }

    background: null

    // opens and closes instantly, like every redesign dialog (Decision 32)

    contentItem: Item {
        id: content

        readonly property ColorContext colorContext: ColorContext {
            palette: VLCStyle.palette
            colorSet: ColorContext.Window
        }

        // ------------------------------------------------------------------ drag state
        // (used by CustomizePalette, CustomizeBar, CustomizeZone, CustomizeZoneItem)

        property bool paletteDragActive: false
        property bool barDragActive: false
        readonly property bool dragActive: paletteDragActive || barDragActive
        property int draggedControlId: -1

        readonly property Item dragGhost: ghost

        function paletteDragStarted(controlId) {
            draggedControlId = controlId
            paletteDragActive = true
        }

        function paletteDragStopped(controlId) {
            paletteDragActive = false
            draggedControlId = -1
        }

        function barDragStarted(controlId) {
            draggedControlId = controlId
            barDragActive = true
        }

        function barDragStopped(controlId) {
            barDragActive = false
            draggedControlId = -1
        }

        // keys nobody in the dialog handled never reach the player behind it; Escape goes on to
        // the popup, which closes
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                profileDropdown.forceActiveFocus(event.key === Qt.Key_Tab ? Qt.TabFocusReason
                                                                           : Qt.BacktabFocusReason)
                event.accepted = true
                return
            }
            event.accepted = (event.key !== Qt.Key_Escape && event.key !== Qt.Key_Back)
        }

        // the window behind is not usable while customizing; keeps the arrow cursor (the video
        // hides its cursor) and gives the keys back to the dialog after a click on empty space
        MouseArea {
            anchors.fill: parent
            cursorShape: content.dragActive ? Qt.DragMoveCursor : Qt.ArrowCursor
            onPressed: (mouse) => {
                content.forceActiveFocus(Qt.MouseFocusReason)
                mouse.accepted = false
            }
        }

        // ---------------------------------------------------------------------- box

        Rectangle {
            id: box

            readonly property real _maxHeight: content.height - bar.height - 2 * VLCStyle.margin_large

            width: Math.min(VLCStyle.rd_dialogWidth, content.width - 2 * VLCStyle.margin_large)
            height: Math.min(_maxHeight, header.height + body.implicitHeight + footer.height)

            x: Math.round((content.width - width) / 2)
            // centered in the space above the bar (Figma: 189.5 above, 181.5 below)
            y: Math.max(0, Math.round((content.height - bar.height - height) / 2))

            radius: VLCStyle.rd_radius_large
            // opaque over the native video (Figma's BG/B1 95 % assumes a background blur)
            color: Qt.alpha(VLCStyle.palette.rdBgB1Transparent, 1.0)

            Widgets.RdShadow { }

            // clicks inside the box never reach the window
            MouseArea {
                anchors.fill: parent
                cursorShape: content.dragActive ? Qt.DragMoveCursor : Qt.ArrowCursor
            }

            // -------------------------------------------------------------- header
            Rectangle {
                id: header

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: VLCStyle.rd_customizeHeaderHeight

                radius: VLCStyle.rd_radius_large
                color: VLCStyle.palette.rdBgB2

                // square bottom corners
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: parent.radius
                    color: parent.color
                }

                // title row (Figma "Frame 207": 9 from the edges, 32 high, text at 10)
                Item {
                    id: titleRow

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: VLCStyle.dp(9)
                    height: VLCStyle.dp(32)

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: VLCStyle.dp(10)
                        anchors.right: profileDropdown.left
                        anchors.rightMargin: VLCStyle.dp(10)
                        anchors.verticalCenter: parent.verticalCenter

                        text: qsTr("Customize Player")
                        elide: Text.ElideRight
                        font.family: VLCStyle.rd_fontFamily
                        font.pixelSize: VLCStyle.rd_fontSize_label
                        color: VLCStyle.palette.rdFgA2

                        Accessible.role: Accessible.TitleBar
                        Accessible.name: text
                    }

                    // VLC's layout profiles (not in the design, Decision 21)
                    Widgets.RdDropdown {
                        id: profileDropdown

                        anchors.right: moreButton.left
                        anchors.rightMargin: VLCStyle.dp(4)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(VLCStyle.dp(240), titleRow.width / 3)
                        height: VLCStyle.dp(32)

                        model: MainCtx.controlbarProfileModel
                        textRole: "name"
                        currentIndex: MainCtx.controlbarProfileModel.selectedProfile
                        displayText: MainCtx.controlbarProfileModel.currentModel
                                     ? MainCtx.controlbarProfileModel.currentModel.name : ""

                        Accessible.name: qsTr("Profile")

                        KeyNavigation.tab: moreButton
                        KeyNavigation.backtab: saveButton.enabled ? saveButton : cancelButton

                        onActivated: (index) => {
                            if (index === MainCtx.controlbarProfileModel.selectedProfile)
                                return
                            MainCtx.controlbarProfileModel.selectedProfile = index
                            root._profilesChanged = true
                        }
                    }

                    HeaderButton {
                        id: moreButton

                        anchors.right: closeButton.left
                        anchors.rightMargin: VLCStyle.dp(4)
                        anchors.verticalCenter: parent.verticalCenter

                        iconName: "more"
                        Accessible.name: qsTr("Profile options")

                        KeyNavigation.tab: closeButton
                        KeyNavigation.backtab: profileDropdown

                        onClicked: profileMenu.opened ? profileMenu.close() : profileMenu.open()
                    }

                    HeaderButton {
                        id: closeButton

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        iconName: "close"
                        Accessible.name: qsTr("Close")

                        KeyNavigation.tab: playerTabs.firstTab
                        KeyNavigation.backtab: moreButton

                        onClicked: root.close()
                    }
                }

                // description row (Figma "Frame 208", FG/A3)
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: VLCStyle.dp(19)
                    anchors.right: parent.right
                    anchors.rightMargin: VLCStyle.dp(19)
                    anchors.top: titleRow.bottom
                    anchors.topMargin: VLCStyle.dp(12)
                    height: VLCStyle.dp(32)

                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    text: qsTr("Drag items around and out of the box below to re-order them. Drag items into the box to remove them from the player.")
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_label
                    color: VLCStyle.palette.rdFgA3
                }
            }

            // ---------------------------------------------------------------- body
            Item {
                id: body

                readonly property int _columns: Math.max(1, Math.floor((width - 2 * VLCStyle.rd_customizeBodyPadding + VLCStyle.rd_customizeColumnGap)
                                                                       / paletteGrid.cellWidth))
                // sized for the items the box has when it opens (Figma's auto layout: full rows
                // 120 apart, the last row as high as its items), then kept while items move (the
                // box does not resize under the cursor); more items scroll
                property int _rows: 1
                property real _lastRowHeight: paletteGrid._itemHeight

                function fitContent() {
                    _rows = Math.max(1, Math.ceil(paletteGrid.count / _columns))
                    _lastRowHeight = paletteGrid.itemsHeightFrom((_rows - 1) * _columns)
                }

                implicitHeight: 2 * VLCStyle.rd_customizeBodyPadding
                                + (_rows - 1) * paletteGrid.cellHeight + _lastRowHeight

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: header.bottom
                anchors.bottom: footer.top

                // a control dragged from the bar over the box: it is removed on drop
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: VLCStyle.dp(14)
                    visible: paletteGrid.removeHintVisible
                    radius: VLCStyle.rd_radius_normal
                    color: VLCStyle.palette.rdHoverOverlay

                    Widgets.RdDashedFrame {
                        anchors.fill: parent
                        color: VLCStyle.palette.rdAccentMain
                    }
                }

                CustomizePalette {
                    id: paletteGrid

                    x: VLCStyle.rd_customizeBodyPadding
                    y: VLCStyle.rd_customizeBodyPadding
                    width: body._columns * cellWidth
                    // the cells include the row gap: the last one reaches into the bottom padding
                    height: Math.max(0, parent.height - 2 * VLCStyle.rd_customizeBodyPadding + VLCStyle.rd_customizeRowGap)

                    editor: content
                    playerModel: root.playerModel
                }
            }

            // -------------------------------------------------------------- footer
            Item {
                id: footer

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: VLCStyle.rd_dialogFooterHeight

                Widgets.RdButton {
                    id: cancelButton

                    anchors.left: parent.left
                    anchors.leftMargin: VLCStyle.dp(20)
                    anchors.verticalCenter: parent.verticalCenter

                    text: qsTr("Cancel")

                    KeyNavigation.tab: saveButton.enabled ? saveButton : profileDropdown
                    KeyNavigation.backtab: playerTabs.lastTab

                    onClicked: root.close()
                }

                // VLC's player layouts (not in the design, Decision 21): the Figma segmented
                // control ("Values"), button height
                PlayerTabs {
                    id: playerTabs

                    identifier: root.identifier
                    editor: content
                    nextItem: cancelButton
                    previousItem: closeButton

                    onSelected: (identifier) => {
                        root.identifier = identifier
                        // a click refits the box; during a drag it keeps its size
                        if (!content.dragActive)
                            body.fitContent()
                    }

                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, saveButton.x - cancelButton.x - cancelButton.width - 2 * VLCStyle.dp(20))
                }

                Widgets.RdButton {
                    id: saveButton

                    anchors.right: parent.right
                    anchors.rightMargin: VLCStyle.dp(20)
                    anchors.verticalCenter: parent.verticalCenter

                    style: Widgets.RdButton.Style.Save
                    text: qsTr("Save")
                    enabled: root.dirty

                    KeyNavigation.tab: profileDropdown
                    KeyNavigation.backtab: cancelButton

                    onClicked: root.accept()
                }
            }
        }

        // ---------------------------------------------------------------------- bar

        CustomizeBar {
            id: bar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            editor: content
            playerModel: root.playerModel
            hasSeekRow: root.identifier !== PlayerControlbarModel.Miniplayer
        }

        // ------------------------------------------------------------- drag ghost

        // a palette item under the cursor while it is dragged (video 19:22)
        CustomizePaletteTile {
            id: ghost

            box: paletteGrid
            // (the palette puts the drag hot spot where the item was grabbed)
            visible: Drag.active
            z: 100
        }

        // -------------------------------------------------------------- popups

        Widgets.RdMenuPanel {
            id: profileMenu

            parent: moreButton
            x: moreButton.width - width
            y: moreButton.height + VLCStyle.dp(4)

            Widgets.RdOptionRow {
                text: qsTr("New Profile")
                rdIcon: "add"
                onClicked: namePrompt.askFor("new", qsTr("New Profile"),
                                             qsTr("Profile %1").arg(MainCtx.controlbarProfileModel.rowCount() + 1))
            }

            Widgets.RdOptionRow {
                text: qsTr("Duplicate")
                reserveIconSpace: true
                enabled: !!MainCtx.controlbarProfileModel.currentModel
                onClicked: namePrompt.askFor("duplicate", qsTr("Duplicate Profile"),
                                             MainCtx.controlbarProfileModel.currentModel.name)
            }

            Widgets.RdOptionRow {
                text: qsTr("Rename")
                rdIcon: "edit"
                enabled: !!MainCtx.controlbarProfileModel.currentModel
                onClicked: namePrompt.askFor("rename", qsTr("Rename Profile"),
                                             MainCtx.controlbarProfileModel.currentModel.name)
            }

            Widgets.RdOptionRow {
                // VLC: deleting every profile brings back the default styles
                text: qsTr("Delete")
                rdIcon: "remove"
                enabled: !!MainCtx.controlbarProfileModel.currentModel
                onClicked: {
                    MainCtx.controlbarProfileModel.deleteSelectedProfile()
                    root._profilesChanged = true
                }
            }
        }

        CustomizeNamePrompt {
            id: namePrompt

            // "new", "duplicate" or "rename"
            property string _mode: ""

            parent: content

            function askFor(mode, title, name) {
                _mode = mode
                ask(title, name)
            }

            onAccepted: (name) => {
                const model = MainCtx.controlbarProfileModel
                const count = model.rowCount()
                switch (_mode) {
                case "new":
                    model.newProfile(name)
                    model.selectedProfile = count
                    break
                case "duplicate":
                    model.cloneSelectedProfile(name)
                    model.selectedProfile = count
                    break
                case "rename":
                    model.setData(model.index(model.selectedProfile, 0), name, Qt.DisplayRole)
                    break
                default:
                    return
                }
                root._profilesChanged = true
            }

            onClosed: profileDropdown.forceActiveFocus(Qt.PopupFocusReason)
        }
    }

    // ------------------------------------------------------------------------------ parts

    // 32x32 icon button of the dialog header (Figma "Icon Wrapper" with the close icon)
    component HeaderButton: T.Button {
        id: headerButton

        property string iconName: ""

        implicitWidth: VLCStyle.dp(32)
        implicitHeight: VLCStyle.dp(32)

        focusPolicy: Qt.StrongFocus

        background: Rectangle {
            radius: VLCStyle.rd_radius_small
            color: headerButton.hovered ? VLCStyle.palette.rdHoverOverlay : "transparent"
            border.width: headerButton.visualFocus ? VLCStyle.dp(1) : 0
            border.color: VLCStyle.palette.rdFgA3
        }

        contentItem: Item {
            Widgets.RdIcon {
                anchors.centerIn: parent
                name: headerButton.iconName
                color: VLCStyle.palette.rdFgA2
            }
        }
    }

    // the player layouts as a segmented control (Figma "Values": BG/B2 frame, BG/A4 segments,
    // the selected one BG/Accent Bright with Accent/Main text); a palette item dragged over a
    // segment selects it (not a control of the bar: its zone would go away under the drag)
    component PlayerTabs: Rectangle {
        id: tabs

        property int identifier: -1
        property Item editor: null
        property Item nextItem: null
        property Item previousItem: null

        signal selected(int identifier)

        readonly property Item firstTab: tabRepeater.count > 0 ? tabRepeater.itemAt(0) : null
        readonly property Item lastTab: tabRepeater.count > 0 ? tabRepeater.itemAt(tabRepeater.count - 1) : null

        readonly property real segmentWidth: Math.min(VLCStyle.dp(120), (width - VLCStyle.dp(2) * (tabRepeater.count + 1)) / Math.max(1, tabRepeater.count))

        implicitWidth: tabRepeater.count * (VLCStyle.dp(120) + VLCStyle.dp(2)) + VLCStyle.dp(2)
        implicitHeight: VLCStyle.dp(32)
        height: implicitHeight

        radius: VLCStyle.rd_radius_normal
        color: VLCStyle.palette.rdBgB2

        Row {
            id: tabRow

            anchors.fill: parent
            anchors.margins: VLCStyle.dp(2)
            spacing: VLCStyle.dp(2)

            Repeater {
                id: tabRepeater

                model: PlayerListModel.model

                delegate: T.Button {
                    id: tab

                    required property int index
                    required property var modelData

                    readonly property bool current: tabs.identifier === modelData.identifier

                    width: tabs.segmentWidth
                    height: tabRow.height

                    focusPolicy: Qt.StrongFocus

                    Accessible.role: Accessible.PageTab
                    Accessible.name: modelData.name
                    Accessible.checked: current

                    KeyNavigation.tab: (index + 1 < tabRepeater.count) ? tabRepeater.itemAt(index + 1) : tabs.nextItem
                    KeyNavigation.backtab: (index > 0) ? tabRepeater.itemAt(index - 1) : tabs.previousItem
                    Keys.onLeftPressed: {
                        if (index > 0)
                            tabRepeater.itemAt(index - 1).forceActiveFocus(Qt.TabFocusReason)
                    }
                    Keys.onRightPressed: {
                        if (index + 1 < tabRepeater.count)
                            tabRepeater.itemAt(index + 1).forceActiveFocus(Qt.TabFocusReason)
                    }

                    onClicked: tabs.selected(modelData.identifier)

                    background: Rectangle {
                        radius: VLCStyle.rd_radius_small
                        // as RdSegmented: the light theme selects with a solid accent fill
                        color: tab.current ? (VLCStyle.palette.isDark ? VLCStyle.palette.rdBgAccentBright
                                                                      : VLCStyle.palette.rdAccentMain)
                                           : (tab.hovered ? VLCStyle.palette.rdBgA2 : VLCStyle.palette.rdBgA4)
                        border.width: tab.visualFocus ? VLCStyle.dp(1) : 0
                        border.color: VLCStyle.palette.rdFgA3
                    }

                    contentItem: Text {
                        id: tabText

                        text: tab.modelData.name
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        font.family: VLCStyle.rd_fontFamily
                        font.pixelSize: VLCStyle.rd_fontSize_label
                        color: tab.current ? (VLCStyle.palette.isDark ? VLCStyle.palette.rdAccentMain
                                                                      : VLCStyle.palette.rdBgA1)
                                           : VLCStyle.palette.rdFgA2
                    }

                    DropArea {
                        anchors.fill: parent
                        onEntered: (drag) => {
                            if (!tabs.editor || !tabs.editor.paletteDragActive) {
                                drag.accepted = false
                                return
                            }
                            tabs.selected(tab.modelData.identifier)
                        }
                    }
                }
            }
        }
    }
}
