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

// redesign: the library Home (video 13:44-13:55, 20:52-20:59; P6-20, P6-21, IB-33, IB-34, P8-38,
// F-15; Figma sidebar "home"): Continue Watching, Listen Again, Frequently Visited Folders,
// Frequently Visited Playlists, Frequently Listened Artists and Latest Streams (Decision 8).
// Next to the video each section lists 3 rows under its title, with a ">" at the panel's edge;
// in the full library each section is a row of cards with the ">" right after the title.
// The ">" opens the whole section. With nothing played yet, Home shows "Watch Next" and an
// empty card (20:52).
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets
import VLC.MediaLibrary

FocusScope {
    id: home

    required property var location
    property bool compact: true

    property string searchText: ""

    readonly property string viewMode: compact ? RdLibraryStore.compactViewMode : RdLibraryStore.viewMode
    readonly property bool listMode: viewMode === "list"

    function setViewMode(mode) {
        if (compact)
            RdLibraryStore.compactViewMode = mode
        else
            RdLibraryStore.viewMode = mode
    }

    readonly property var sortOptions: []
    readonly property string sortKey: ""
    readonly property string defaultSortKey: ""
    function setSortKey(key) { }

    readonly property bool searchable: true

    property int itemCount: 0
    // a section is still loading: the "Watch Next" empty state waits for it
    property bool anyLoading: true

    signal loaded()

    readonly property var sections: [
        { section: "continueWatching", title: qsTr("Continue Watching"), wide: true },
        { section: "listenAgain", title: qsTr("Listen Again"), wide: false },
        { section: "frequentFolders", title: qsTr("Frequently Visited Folders"), wide: false },
        { section: "frequentPlaylists", title: qsTr("Frequently Visited Playlists"), wide: false },
        { section: "frequentArtists", title: qsTr("Frequently Listened Artists"), wide: false },
        { section: "latestStreams", title: qsTr("Latest Streams"), wide: false }
    ]

    // full library: one row of cards per section, as many as fit (Continue Watching cards are
    // wider)
    readonly property real _cardGap: VLCStyle.dp(14)

    function _cardWidth(wide) {
        return wide ? VLCStyle.dp(240) : VLCStyle.dp(150)
    }

    function _limit(wide) {
        if (compact || listMode)
            return 3
        return Math.max(1, Math.floor((flick.width + _cardGap) / (_cardWidth(wide) + _cardGap)))
    }

    function _updateCount() {
        let count = 0
        let loading = false
        for (let i = 0; i < sectionRepeater.count; ++i) {
            const s = sectionRepeater.itemAt(i)
            if (s) {
                count += s.model.count
                loading = loading || s.model.loading
            }
        }
        itemCount = count
        anyLoading = loading
    }

    readonly property string playingMrl: Player.url.toString() !== "" ? decodeURIComponent(Player.url.toString()) : ""

    Flickable {
        id: flick

        anchors.fill: parent
        clip: true
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        T.ScrollBar.vertical: T.ScrollBar {
            id: scrollBar

            policy: flick.contentHeight > flick.height ? T.ScrollBar.AsNeeded : T.ScrollBar.AlwaysOff
            width: VLCStyle.dp(6)
            contentItem: Rectangle {
                implicitWidth: VLCStyle.dp(4)
                radius: width / 2
                color: VLCStyle.palette.rdDividerBright
                opacity: scrollBar.active ? 1 : 0
            }
        }

        Column {
            id: column

            width: flick.width
            spacing: VLCStyle.dp(30)

            Repeater {
                id: sectionRepeater

                model: home.sections

                delegate: Column {
                    id: sectionItem

                    required property var modelData

                    readonly property alias model: sectionModel

                    width: column.width
                    spacing: VLCStyle.dp(15)
                    visible: sectionModel.count > 0

                    RdCollectionModel {
                        id: sectionModel

                        ml: MediaLib
                        section: sectionItem.modelData.section
                        limit: home._limit(sectionItem.modelData.wide)
                        searchPattern: home.searchText
                        ids: {
                            if (sectionItem.modelData.section === "frequentFolders")
                                return RdLibraryStore.frequentFolderIds
                            if (sectionItem.modelData.section === "frequentPlaylists")
                                return RdLibraryStore.frequentPlaylistIds
                            return []
                        }
                        onCountChanged: home._updateCount()
                        onLoadingChanged: home._updateCount()
                        onLoaded: home.loaded()
                    }

                    SectionHeader {
                        width: parent.width
                        text: sectionItem.modelData.title
                        chevronAtEdge: home.compact
                        onClicked: RdLibraryNav.openChild({ page: "section", section: sectionItem.modelData.section,
                                                            title: sectionItem.modelData.title })
                    }

                    // next to the video: rows (Figma rows, gap 10)
                    Column {
                        visible: home.compact || home.listMode
                        width: parent.width
                        spacing: VLCStyle.dp(10)

                        Repeater {
                            model: home.compact || home.listMode ? sectionModel : null

                            delegate: RdLibraryRow {
                                required property var model
                                required property int index

                                readonly property var item: home.toItem(model, index)

                                width: parent.width
                                title: home.titleOf(item)
                                iconName: home.iconOf(item)
                                thumbnail: home.thumbnailOf(item)
                                boxed: item.kind === "media" || item.kind === "stream"
                                       || (item.kind === "playlist" && thumbnail.toString() !== "")
                                progress: item.progress
                                // Home rows are secondary (Figma: FG/A3)
                                watched: true
                                playing: home.isPlaying(item.mrl)
                                dragUrls: home.dragUrlsOf(item)
                                onClicked: home.activate(item)
                                onMoreClicked: (button) => itemMenu.openForItem(item, button, home.categoryOf(item))
                            }
                        }
                    }

                    // full library: a row of cards
                    Row {
                        visible: !home.compact && !home.listMode
                        spacing: home._cardGap

                        Repeater {
                            model: !home.compact && !home.listMode ? sectionModel : null

                            delegate: RdLibraryCard {
                                required property var model
                                required property int index

                                readonly property var item: home.toItem(model, index)

                                width: home._cardWidth(sectionItem.modelData.wide)
                                title: item.title
                                subtitle: item.kind === "media" && !item.isVideo ? (item.subtitle ?? "") : ""
                                iconName: home.iconOf(item) || "videos"
                                thumbnail: home.thumbnailOf(item)
                                wide: sectionItem.modelData.wide
                                progress: item.progress
                                watched: item.watched
                                playing: home.isPlaying(item.mrl)
                                dragUrls: home.dragUrlsOf(item)
                                onClicked: home.activate(item)
                                onMoreClicked: (button) => itemMenu.openForItem(item, button, home.categoryOf(item))
                            }
                        }
                    }
                }
            }

            // nothing played yet (20:52-20:59)
            Column {
                visible: home.itemCount === 0 && !home.anyLoading && home.searchText === ""
                width: parent.width
                spacing: VLCStyle.dp(15)

                SectionHeader {
                    width: parent.width
                    text: qsTr("Watch Next")
                    chevronAtEdge: home.compact
                    textColor: VLCStyle.palette.rdFg1
                    onClicked: RdLibraryNav.openRoot("videos")
                }

                Rectangle {
                    width: Math.min(parent.width, VLCStyle.dp(368))
                    height: width * 9 / 16
                    radius: VLCStyle.dp(12)
                    color: VLCStyle.palette.rdBgA2
                }
            }
        }
    }

    function toItem(model, index) {
        return {
            kind: model.kind,
            index: index,
            id: model.id,
            title: model.title,
            subtitle: model.subtitle,
            mrl: model.mrl,
            thumbnail: model.thumbnail,
            progress: model.progress,
            watched: model.watched,
            isVideo: model.isVideo,
            isFavorite: model.isFavorite
        }
    }

    function iconOf(item) {
        switch (item.kind) {
        case "folder": return "folder"
        case "playlist": return "playlist"
        case "artist": return "artist"
        case "stream": return "tv"
        default: return item.isVideo ? "" : "music"
        }
    }

    function titleOf(item) {
        if (item.kind === "media" && !item.isVideo && item.subtitle)
            return item.title + " - " + item.subtitle
        return item.title
    }

    function thumbnailOf(item) {
        if (item.kind === "playlist") {
            const covers = RdLibraryStore.playlistCovers
            return covers ? RdLibraryStore.playlistCover(item.id).toString() : ""
        }
        return item.thumbnail ?? ""
    }

    function isPlaying(mrl) {
        return playingMrl !== "" && !!mrl && decodeURIComponent(mrl) === playingMrl
    }

    function dragUrlsOf(item) {
        return (item.kind === "media" || item.kind === "stream") && item.mrl ? [item.mrl] : []
    }

    // length of the deepest folder of `folders` that holds `mrl` (0: none)
    // the category of a Home row (RdLibraryNav.itemCategory)
    function categoryOf(item) {
        return RdLibraryNav.itemCategory(item)
    }

    // a frequent folder opens with its whole address line
    function activate(item) {
        if (item.kind === "folder") {
            RdLibraryStore.noteVisit("folder", item.id)
            RdLibraryStore.resolveFolder(item.mrl, (result) => RdLibraryNav.openFolderPath(result))
            return
        }
        RdLibraryActions.activate(item, home.categoryOf(item))
    }

    RdLibraryItemMenu {
        id: itemMenu

        location: home.location
    }

    // section title (Figma: Inter 400 16 FG/A1, 32 px row) with its ">" link
    component SectionHeader: T.AbstractButton {
        id: header

        property bool chevronAtEdge: true
        property color textColor: VLCStyle.palette.rdFgA1

        implicitHeight: VLCStyle.dp(32)
        hoverEnabled: true
        focusPolicy: Qt.TabFocus

        Accessible.role: Accessible.Link
        Accessible.name: text

        contentItem: Item {
            Text {
                id: label

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width - chevron.width - VLCStyle.dp(8))
                text: header.text
                elide: Text.ElideRight
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_header
                color: header.hovered || header.visualFocus ? VLCStyle.palette.rdFg2 : header.textColor
            }

            Widgets.RdIcon {
                id: chevron

                anchors.verticalCenter: parent.verticalCenter
                x: header.chevronAtEdge ? parent.width - width : label.width + VLCStyle.dp(4)
                name: "chevron_direction-right"
                size: header.chevronAtEdge ? VLCStyle.rd_iconSize : VLCStyle.dp(16)
                color: header.hovered || header.visualFocus ? VLCStyle.palette.rdFg2 : VLCStyle.palette.rdFgA2
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            cursorShape: Qt.PointingHandCursor
        }
    }
}
