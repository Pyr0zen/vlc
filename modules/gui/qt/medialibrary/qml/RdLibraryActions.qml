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

// redesign: what the library rows and menus do (video 10:52-10:57, 11:44-11:47, 13:30-13:33;
// Figma "file context menu", "folder context menu", "playlist context menu", F-11, F-12).
// An item is a plain object made from a library row ({ kind, id, title, mrl, ... }, see
// RdLibraryHome.toItem and RdLibraryPage) or a network row ({ kind: "stream", title, mrl }).
pragma Singleton

import QtQml

import VLC.MediaLibrary
import VLC.Playlist
import VLC.Dialogs

QtObject {
    id: root

    function isMedia(item) {
        return item.kind === "media" || item.kind === "stream"
    }

    // the library location a container row opens
    function locationOf(item, category) {
        switch (item.kind) {
        case "folder":
            return { page: "folder", category: category, id: item.id, mrl: item.mrl, title: item.title }
        case "playlist":
            return { page: "playlist", id: item.id, title: item.title }
        case "album":
        case "artist":
        case "genre":
            return { page: "collection", kind: item.kind, id: item.id, title: item.title }
        default:
            return null
        }
    }

    // a click on a row: containers open, media play (11:44 only the clicked file joins the queue)
    function activate(item, category) {
        const location = locationOf(item, category)
        if (location) {
            if (item.kind === "folder")
                RdLibraryStore.noteVisit("folder", item.id)
            else if (item.kind === "playlist")
                RdLibraryStore.noteVisit("playlist", item.id)
            RdLibraryNav.openChild(location)
            return
        }
        play(item)
    }

    function play(item) {
        if (item.kind === "stream" || !item.id || !item.id.isValid())
            MediaLib.addAndPlay(item.mrl)
        else
            MediaLib.addAndPlay(item.id)
    }

    function addToQueue(item) {
        if (item.kind === "stream" || !item.id || !item.id.isValid())
            MainPlaylistController.append([item.mrl], false)
        else
            MediaLib.addToPlaylist(item.id)
    }

    function shuffle(item) {
        if (!MainPlaylistController.random)
            MainPlaylistController.toggleRandom()
        MediaLib.addAndPlay(item.id)
    }

    function setWatched(item, watched) {
        RdLibraryStore.setWatched([item.id], watched)
    }

    function toggleFavorite(item) {
        RdLibraryStore.setFavorite(item.id, item.mrl ?? "", !item.isFavorite)
    }

    function stream(item) {
        DialogsProvider.streamingDialog([item.mrl], true)
    }

    function convert(item) {
        DialogsProvider.streamingDialog([item.mrl], false)
    }

    function showInFileExplorer(item) {
        RdLibraryStore.showInFileExplorer(item.mrl)
    }

    // the folder of a file shown from somewhere else (Home, Recent, search)
    function goToSource(item) {
        RdLibraryStore.resolveFolder(item.mrl, (result) => RdLibraryNav.openFolderPath(result))
    }

    // the chosen tracks play with the file (VLC's input-slave option). The Add Subtitles
    // dialog (W6.5) replaces this picker once it exists.
    function addTracks(item, subtitles) {
        const files = RdLibraryStore.pickFiles(subtitles ? qsTr("Add Subtitle Tracks") : qsTr("Add Audio Tracks"), false)
        if (files.length === 0)
            return
        const slaves = files.map((url) => url.toString()).join("#")
        MediaLib.addAndPlay(item.mrl, [":input-slave=" + slaves])
    }

    function properties(item) {
        DialogsProvider.mediaInfoDialog(item.id)
    }

    // the app's one Open Network Stream dialog (W6.4); with a Playlist Name it saves a stream
    // list under Network (RdStreamListSaver)
    function openNetworkStream() {
        DialogsProvider.openNetDialog()
    }

    // a folder of `category` picked by the user; the library opens it once it is scanned
    function addFolder(category) {
        const url = RdLibraryStore.pickFolder(qsTr("Add Folder"))
        if (url.toString() === "")
            return
        RdLibraryStore.addFolder(category, url)
    }

    // files picked by the user join the queue, or the playlist being shown
    function addFiles(playlistId) {
        const files = RdLibraryStore.pickFiles(qsTr("Add File"), false)
        if (files.length === 0)
            return
        if (playlistId && playlistId.isValid())
            RdLibraryStore.appendToPlaylist(playlistId, files)
        else
            MainPlaylistController.append(files, false)
    }
}
