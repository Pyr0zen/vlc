# LIBRARY_NOTES: Phase 5 (redesigned library), web session

Branch `redesign-library`, branched from `redesign` (merge base 67ec8e0347). Built by the web session; the PC session reviews, merges, builds and tests (CLAUDE.md "Parallel work"). Nothing is marked verified in VIDEO_INDEX.md: every row below is "built, not verified".

## 1. Status

- W5.1 to W5.9 coded, all 68 rows addressed (table in section 3). Four rows need a change in shared player files that only the PC session may make (section 5).
- qmlcheck (PySide6 6.8.3 installed here, works): `errors: 1` (the known HighResolutionTimeWidget stub limit), `crashed: 0`, 308 files.
- C++: syntax and type checked here against VLC's headers with Qt 6.4 dev headers (the only Qt this container has). Not compiled, linked or run: the first real compile is the PC session's CI build after the merge.
- Independent review: two fresh subagents (C++ and QML) reviewed the whole branch diff; findings and fixes in section 8.
- `origin/redesign` checked for new commits before every push: none since the branch point, so no merge was needed.

## 2. What was built

**Data layer (C++, `modules/gui/qt/medialibrary/`, all new files)**
- `RdLibraryStore` (singleton): the library's own settings in VLC's QSettings (`RdLibrary/...`): folders per category (Videos / Music), pins, stream lists, playlist covers, view modes, sort keys per page. Folder pick / add / remove / rescan (`vlc_ml_add_folder`, `vlc_ml_remove_folder`, `vlc_ml_reload_folder`), resolve a file to its folder path (folder chip), create / append / rename / delete / export (M3U8) playlists, playlist cover images (copied to the user data dir), Mark as Watched (`vlc_ml_media_set_played`), Favorite, Show in File Explorer, Clear Recent.
- `RdSubfolderModel` (an `MLBaseModel`, paged): the folder levels of Videos and Music (at the root: the category's library folders plus its folders that sit inside a library folder of the other category; below: `VLC_ML_LIST_SUBFOLDERS`).
- `RdConcatModel`: a folder page's subfolders followed by its media as one list (both paged models stay paged: every row is read from its source when the view asks for it).
- `RdCollectionModel` (Home sections, capped): Continue Watching, Listen Again, Frequent Folders, Frequent Playlists, Frequent Artists, Latest Streams.
- `RdLibraryModel`: the shared base of the capped Home models (ML thread loading, debounced reload on ML events, thumbnails requested on demand).
- Minimal edits to VLC files: `mlvideomodel.cpp` and `mlaudiomodel.cpp` accept the `filename` sort and `MLAudioModel` lists the songs of a folder (`VLC_ML_PARENT_FOLDER`); `mainui.cpp` registers the four new types.

**Library UI (QML, `modules/gui/qt/medialibrary/qml/`, all new files)**
- `RdLibraryNav` (singleton): one navigation state for both library views: pages, crumbs, back / forward history, pins, open a folder path.
- `RdLibraryActions` (singleton): Play, Add to Queue, Shuffle, Stream, Convert, Mark as Watched, Favorite, Add Subtitle / Audio Tracks (`:input-slave`), Go to Source, Show in File Explorer, Add Folder, Add File.
- `RdLibraryRail` (categories with their Figma active / selected icons, pins, "+" pin menu), `RdLibraryHeader` (compact two rows / full one row: back, forward, breadcrumb, count, sort menu, grid / list, search, "..."), `RdBreadcrumb` (folds the middle crumbs when narrow).
- `RdLibraryPage` (every page: Videos and Music folders, Songs, Albums, Artists, Genres, Network, stream lists, Playlists, a playlist, Recent, Latest Streams, pins; grid and list; sort options per page incl. Unwatched First / Watched First), `RdLibraryHome` (sections, compact and full card layouts, empty state), `RdLibraryContent` (180 ms crossfade between pages, hosts the dialogs).
- Rows and cards: `RdLibraryRow`, `RdLibraryCard`, `RdLibraryThumb` (rounded async thumbnail, watched bar, playing overlay), `RdLibraryIconButton`.
- Menus: `RdLibraryMenu`, `RdLibraryItemMenu` (file / folder / playlist / album-artist-genre / stream list menus and the page "..." menus), `RdAddToPlaylistMenu`.
- Dialogs: `RdLibraryDialog` (Figma frame), `RdPlaylistDialog` (New Playlist / Playlist Properties: name, thumbnail picker, dashed drop zone), `RdStreamDialog` (Add Network Stream: a pasted m3u link is saved as a named stream list), `RdFolderInfoPopup`, `RdDashedBorder`.
- `RdLibrarySidebar` (compact library next to the video, 50 + 377 px) and `RdLibraryView` (full-window library). Both show the same places.

**Window, mini player, queue**
- `maininterface/qml/MainDisplay.qml` rewritten: the window top bar (cone, "...", centered title, window buttons / fullscreen), the full library (VLC's own `NoMedialibHome` when the media library is off), the mini player, update pane, dialogs, notifications, mouse back / forward. A video that starts opens the player (VLC's behavior).
- `player/qml/RdMiniPlayer.qml`: 391 x 339 card, video (or cover) with the hover controls (close = stop, open player, previous, play / pause, next), seek bar, file name, folder chip (opens the folder in the library), artist chip, queue button; drag the picture to any corner, it snaps there in 300 ms.
- `player/qml/RdMiniQueue.qml`: the queue attached above it: "Queue" header, count and length, sort / repeat / shuffle / remove / add (Decision 10), rows with the play icon or drag handle, reorder by dragging.
- `playlist/qml/RdQueueDropArea.qml`: drop library rows or files on a queue list; they are inserted where dropped (W5.9). Used by the mini queue; the PC session adds it to the queue sidebar (section 5).

## 3. VIDEO_INDEX rows covered (68)

Status column: **built** = coded on this branch, needs the PC test; **PC** = the library part is built, the rest needs a shared-file change listed in section 5; **not built** = intentionally (reason given).

| WP | Rows | Status | Where |
|---|---|---|---|
| W5.1 shell | P5-06, P5-07, P5-08, IA-44, IA-45, IB-07, IB-13, IB-21 | built | RdLibraryRail, RdLibraryHeader, RdBreadcrumb, RdLibraryNav, RdLibraryContent (crossfade), RdLibraryView |
| W5.1 compact | P5-23, P5-25, F-16 | PC | RdLibrarySidebar built; docking it in Player.qml with the 208 ms animation is section 5 item 1 |
| W5.1 | IB-05 | built | Add Folder: the new folder is revealed in its category (RdLibraryContent pending folder) |
| W5.1 | IB-01 | not built | her transitional "cleaned VLC 3" mock; only her final version is built |
| W5.2 folders | F-14, P5-16, P5-29 | built | RdSubfolderModel, RdLibraryStore folders, RdLibraryPage folder levels |
| W5.3 music | P6-01, P6-02, P6-03, IB-20, IB-22 | built | Music folders, Songs / Albums / Artists / Genres, artist view, covers |
| W5.3 music player | P6-04, P6-05, IB-23, IB-24 | PC | Player.qml and the control bar (section 5 item 4) |
| W5.4 network | P6-07, IB-25, P6-14 | built | Network page (stream lists, Podcasts, Radio), RdStreamDialog |
| W5.5 playlists | P6-15, P6-16, P6-17, IB-30, F-11, P8-34 | built | Playlists page, RdPlaylistDialog, RdAddToPlaylistMenu, playlist menu |
| W5.6 home | P6-18, P6-19, P6-20, P6-21, F-15, IB-32, IB-33, IB-34, IB-47, P8-33, P8-38, P8-53 | built | RdLibraryHome, Recent page, pins in RdLibraryRail |
| W5.7 toolbar | P5-11, P5-12, P5-13, P5-14, P5-15, P5-17, P5-26, F-12, F-13, IB-02, IB-03, IB-04, IB-06, IB-12, IB-14, IB-31 | built | RdLibraryHeader, RdLibraryItemMenu, RdLibraryRow, RdLibraryCard, RdLibraryThumb |
| W5.8 mini player | P5-27, P5-28, F-17, IB-18 | built | RdMiniPlayer, RdMiniQueue, MainDisplay |
| W5.9 drag to queue | P5-24, IB-15 | built (mini queue), PC (queue sidebar) | RdQueueDropArea, row drag ghost; section 5 item 3 |

## 4. Decisions (Claude) to add to VIDEO_INDEX.md

One line each, for the PC session to copy under "Decisions (Claude)" at the merge:
- Videos and Music categories are folder based: each category keeps its own folder list in QSettings on top of VLC's media library entry points; a folder added before the redesign (in no list) shows in both.
- A folder added to a category that is inside a library folder of the other category (a Music folder inside a Videos folder) is listed at the root of its category and opens there; it is not scanned twice. Removing the outer library folder makes it a library folder of its own (rescanned).
- A folder page lists its subfolders first, then its media, in the same view: rows in list view, cards with the folder icon in grid view (the video never shows both on one page).
- Unwatched First / Watched First sort by the media library's play count; inside each group the order is the media library's own.
- Sort options differ per page, from her menu (Title A-Z / Z-A, Unwatched First, Watched First, Newest / Oldest First, URI) plus what VLC's models support on music pages (artist, album, track and disc number); each page remembers its sort.
- Compact library and full library keep separate view modes: compact defaults to list, full to grid (as in the video).
- Page "..." menu Add File: adds the files to the end of the queue without playing; on a playlist page it adds them to that playlist.
- Rail "+" opens a small menu: Pin This Page, Pin a Folder... (the video only shows the result).
- Extra menu items not in the video but needed to manage the data: Delete Playlist, Remove from Library (folders), Unpin and Move Up / Down (pins).
- Mini player X stops playback (VLC has no other "close the mini player" state).
- Network: Podcasts and Radio are VLC's existing "podcast" and "radio" services.
- Window title text "VLC Media Player" stays until the Phase 6 rename.
- Edit / Add Subtitle and Audio Tracks on a file use VLC's existing slave tracks (`:input-slave`); for folders and playlists they wait for the W6.5 dialog.

## 5. What the PC session must change in shared files

1. **Player.qml (compact library, P5-23 / P5-25 / F-16):** add the compact library docked on the left between the top bar and the control bar, 427 px wide, the video area shifting right while it is open:
   `Loader { active: <libraryOpen>; source: "qrc:///qt/qml/VLC/MediaLibrary/RdLibrarySidebar.qml" }` (only when `MainCtx.mediaLibraryAvailable`). Open / close with the Figma "slow" 208 ms animation. The top bar's sidebar toggle opens and closes it; the folder chip opens it and calls `item.revealMrl(Player.url.toString())`. Lock both bars visible while it is open (Decision 30 bar logic). "Open the library in full" sets `MainCtx.playerView = false` (already done inside the sidebar).
2. **Keys and buttons on the player page while the compact library is open:** mouse back / forward call `RdLibraryNav.goBack()` / `goForward()`; Ctrl+F calls the sidebar's `focusSearch()`. In `MainInterface.qml` the swipe-back gesture still calls `History.previous()`, which no longer drives the library: point it to `RdLibraryNav.goBack()` when the library is shown.
3. **QueueSidebar (W5.9 over the video):** inside the queue page add `RdQueueDropArea { anchors.fill: parent; view: <the queue ListView> }` (VLC.Playlist). It needs a ListView (it uses `indexAt` to insert where dropped); without one it appends.
4. **Music player view (P6-04, IB-23) and music control bar (P6-05, IB-24), Player.qml / ControlBar:** VLC already shows the blurred cover behind audio. Changes: cover as `Widgets.ImageExt` with radius 12, caption "title - artist", 15 s back / forward skip buttons around play, waveform seek bar when on, no subtitle button for audio. Figma "Player - Music-1.png".
5. **Style tokens (optional):** the library uses only existing `palette.rd*` / `VLCStyle.rd_*` tokens; durations without a token are named properties (crossfade 180 ms in RdLibraryContent, mini player snap 300 ms in RdMiniPlayer). Add `rd_duration_*` tokens if wanted.
6. **VIDEO_INDEX.md:** set the rows in section 3 to "in progress" (built, unverified) at the merge, and to done after the test round.

## 6. Not done / limits

- Nothing was compiled or run here (no VLC build environment in this container). The C++ was checked against Qt 6.4 headers, VLC uses Qt 6.8: the CI build is the first compile.
- Folder / playlist subtitle and audio tracks need W6.5 (Add Subtitles dialog).
- Home has no sort (the video shows none); the Playlists page sorts by name and date only (what `MLPlaylistListModel` supports).
- The video's IB-01 transitional library mock is intentionally not built.
- Background blur is not used (performance rule); see section 9.
- VLC's media library module ignores offset and limit for subfolders (`VLC_ML_LIST_SUBFOLDERS` in `modules/misc/medialibrary/medialibrary.cpp` returns them all): each page of a folder level is cut from one full query on the media library thread, only the rows of the page become items and delegates. Paging that SQL query too would be a small core change (pass the query parameters to `Folder::subfolders()` and use `items(nb, offset)`), its own build per CLAUDE.md; only worth it if a folder with thousands of subfolders measures slow.

## 7. Files

New C++: `medialibrary/rdlibrarymodel.{hpp,cpp}`, `rdcollectionmodel.{hpp,cpp}`, `rdsubfoldermodel.{hpp,cpp}`, `rdconcatmodel.{hpp,cpp}`, `rdlibrarystore.{hpp,cpp}`.
New QML (VLC.MediaLibrary): `RdAddToPlaylistMenu`, `RdBreadcrumb`, `RdDashedBorder`, `RdFolderInfoPopup`, `RdLibraryActions` (singleton), `RdLibraryCard`, `RdLibraryContent`, `RdLibraryDialog`, `RdLibraryHeader`, `RdLibraryHome`, `RdLibraryIconButton`, `RdLibraryItemMenu`, `RdLibraryMenu`, `RdLibraryNav` (singleton), `RdLibraryPage`, `RdLibraryRail`, `RdLibraryRow`, `RdLibrarySidebar`, `RdLibraryThumb`, `RdLibraryView`, `RdPlaylistDialog`, `RdStreamDialog`. VLC.Player: `RdMiniPlayer`, `RdMiniQueue`. VLC.Playlist: `RdQueueDropArea`.
Changed VLC files: `maininterface/qml/MainDisplay.qml` (Phase 5 file, rewritten), `maininterface/mainui.cpp` (type registration), `medialibrary/mlvideomodel.cpp`, `medialibrary/mlaudiomodel.cpp`, `Makefile.am`, `meson.build` (every new file registered in both).
Not touched: Player.qml, the palette, MainCtx, the sidebar files, VLCStyle.

## 8. Independent review

Two fresh subagents that did not write the code reviewed the whole branch diff (C++ and QML separately). Fixed:

C++ (rdlibrarystore, rdlibrarymodel, rdsubfoldermodel):
- A folder already in one category could not be added to the other: it now shows in both.
- Removing a folder added before the redesign (in no list) removed it from both categories: it now stays in the other one.
- Folder MRLs sent to the media library keep their trailing slash (remove, rescan, favorite).
- Show in File Explorer: "/select," and the path are passed separately (paths with spaces opened the wrong folder).
- Playlist delete, cover copy and export log a warning on failure; the cover file is only deleted once the playlist is.
- The media library event filter is no longer a virtual call from the media library thread.

QML and C++ (MRL encoding):
- MRLs are compared fully decoded everywhere (`RdLibraryItems::mrlKey`): Qt, VLC and the media library percent-encode differently, so the folder chip, Go to Source and Pin a Folder failed for paths with spaces or accents. `resolveFolder` also looks a file up in Qt's and VLC's encoding.

QML:
- Keyboard focus survives library navigation (`RdLibraryContent` is a FocusScope, the new page takes the focus).
- Each grid cell creates only its row or its card (one Loader), and drag ghosts are created only while dragging: no picture is loaded twice.
- The grid scrolls to the row or card that has keyboard focus.
- The mini player no longer covers the library: the content ends above it in a bottom corner, and in a top corner it stays below the library header.
- The mini player creates its video surface only where VLC can show video outside the player (`MainCtx.canShowVideoPIP`, as VLC's PIP player).
- `RdLibraryNav` imports VLC.MediaLibrary explicitly (pins).
- Closing the compact search clears its text; a second click on the sort or view button closes its menu.
- The stream dialog's name autofill survives a stray "%" in a typed URL.
- The dashed drop zone border builds its dashes only while shown.
- Home folders get their real category (their menu added folders to Music before).
- Restored from the old MainDisplay: Ctrl+F focuses the library search, Escape goes back, pinch changes the interface scale.

Follow-up (Tony, 2026-10-13), both built:
- A folder with hundreds of subfolders loads its rows lazily: subfolders and media are one paged list (`RdConcatModel`), the header Repeater is gone.
- A folder added to Music shows on the Music page even when it is inside a Videos folder (and the same the other way round).
- Their independent review found 4 issues, all fixed: a folder level on an unplugged drive counted rows it never loaded (endless reloads); a folder just added now opens in the category it was added to; Home and the library store now agree on a folder's category when it is in both lists (music wins a tie); a Music folder inside a Videos folder that is also in Music shows once, not twice.

Not changed, with reasons:
- Auto-switch to the player when a video starts: VLC's own MainDisplay does exactly this (`onHasVideoOutputChanged`), so it stays.
- `widgets/qml/RdMenuPanel.qml` (PC session file): its `_connected` array keeps a null for each destroyed menu row, a few per menu open. Fix for the PC session: drop nulls at the start of `onChildrenChanged` (`_connected = _connected.filter((c) => !!c)`).

## 9. Performance (Tony, 2026-10-13: the app must feel at least as snappy as stock VLC)

How Phase 5 is built for speed:
- Every unbounded list uses VLC's paged `MLBaseModel` models (rows load on demand on the media library thread, the view only creates visible delegates):
  - folder media: `MLVideoModel` / `MLAudioModel` with the folder as `parentId` (videos only in Videos, songs only in Music);
  - folder levels: `RdSubfolderModel` (new, an `MLBaseModel`); a folder page shows its subfolders and media as one paged list (`RdConcatModel`), never all subfolders at once;
  - albums `MLAlbumModel`, artists `MLArtistModel`, genres `MLGenreModel`, tracks of an album / artist / genre `MLAudioModel`, playlists `MLPlaylistListModel`, playlist content `MLPlaylistModel`, Recent `MLRecentMediaModel`, Latest Streams page `MLUrlModel`, network stream lists and services `NetworkMediaModel` / `NetworkDeviceModel`.
- Sorting is done by the media library (SQL), never in the UI.
- `RdCollectionModel` (Home sections only) loads a few rows on the media library thread, capped at 100 rows (3 per section next to the video, one row of cards in the full library).
- Thumbnails and covers: `Image { asynchronous: true }`, `sourceSize` limited to twice the shown size, thumbnails generated by the media library on demand (VLC's own `MLMediaModel` path).
- No timers or polling in the library. The only timer is the 300 ms single-shot reload debounce of `RdLibraryModel` after media library events.
- No background blur: panels use the solid semi-transparent Figma fills (`rdBgB1Transparent` etc.).

To measure first after merging (most sensitive first):
1. Scrolling a 10,000-item Songs / Albums / Artists list in grid and list view, both compact and full.
2. Opening a folder with 1,000+ videos (thumbnail generation load while scrolling), and a folder with 500+ subfolders (each page of subfolders is cut from one full media library query, see section 6).
3. Home with a large history (6 section queries at once on start; the frequent-artists query ranks the last 200 songs played).
4. Media library scan of a large folder while the library is open: every ML event restarts the 300 ms reload debounce of the visible Home sections.
5. Page crossfade (180 ms) between heavy pages.
6. Background blur: not used anywhere in Phase 5. If the PC session wants the Figma "bg blur" on the library panel, test whether it holds 60 fps over playing video first.
