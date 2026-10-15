# Add Subtitles dialog (W6.5): notes for the PC session

Branch `redesign-addsubs`, from `origin/redesign` a16022b419 (2026-10-15). Web session, no build here: nothing in this file is verified on the PC. Every item below still needs the build, real screenshots side by side with the Figma PNGs, the UX pass and the regression checklist.

## 1. Status

- Built: the dialog (all four Figma frames plus its dropdowns, swap list and empty states), the matching, the OpenSubtitles source behind an API key, From Link, the saved matches and their use on playback, and the Settings rows for the API key.
- Not hooked up: the dialog only opens once the PC session adds the shared-file lines in section 5. Until then the dialog cannot be reached in the app.
- Checks run on the final commit: qmlcheck `errors: 1 files: 365 crashed: 0` (the known HighResolutionTimeWidget stub), buildlists `0 problem(s)`, privacycheck `0 problem(s)` (generic checks only: the web session has no privacy.local.txt; run it again on the PC). C++ syntax check of every new file against Qt 6.4 headers with `-Wall -Wextra -Wconversion`: clean. moc on both QObject headers, its output compiles.
- Not run here: the real compile and link (no build environment), qsb (no shaders were added), runtime QML warnings.
- Commits are local only. The branch is not pushed: Sticky asked to wait for the history rewrite, then rebase onto the new `origin/redesign`, run privacycheck, and push.

## 2. What was built

### The dialog (Figma "Add Subtitles to Playlist/Folder" 1911:7545, 3336:11929, 1919:8707, 1919:9278)
- 1048x800, radius 14, BG/B1. It is opaque, because it opens over the native video and Figma's 95 % assumes a blur. It has the "bg blur + shadow" drop shadow through RdShadow. It opens and closes instantly (Decision 32) and does not dim the window (Decision 41).
- **Header (96 px, BG/B2, padding 9, gap 12)**
  - "Add Subtitles" in Inter 14 FG/A2, and the 32x32 close button.
  - The controls row (34 px, gap 10): target dropdown, source dropdown, then the source's field.
  - The source's field is one of three:
    - From Computer: folder icon and the folder as "Videos / Shows / The Wand / S01" (the path under the home folder, left-elided). A click opens a folder picker.
    - From OpenSubtitles: magnifier and the search text, plus the 200 px language dropdown (Figma "Folder-3").
    - From Link: link icon and a link input. Enter downloads the file.
- **Header dropdowns** (`AddSubtitlesDropdown.qml`, Figma components "target" 1959:5325 and "origin" 1963:5465)
  - Closed: 200x34, BG/A5, radius 6, padding 5,8,5,12, value in FG/A1, chevron in FG/A2.
  - Open: the list opens in place, 209 wide and 4 px out to the left, padding 2, BG/A4, radius 6, shadow 35 % y 4 blur 13.8. Rows are 48 px (padding 2,14). The current row is BG/A3 over the field, with the accent check.
  - Unavailable targets are dimmed (FG/A4) and skipped, for example "To This Playlist" when the queue has one item, or "To This File" when the dialog was opened for a folder.
  - Keyboard: Up/Down pick the previous or next value on the closed control. In the open list, Up/Down move, Enter/Space pick, Escape closes.
- **Body, "To This File"** (Figma "Folder-2" / "Folder-3")
  - "subtitle one" rows (`AddSubtitlesFileRow.qml`): 36 px, gap 4, padding 22,20, subtitle icon FG/A3, name FG/A1.
  - A click checks the row: BG/B2 and the accent check. Several rows can be checked.
  - The current episode's files come first, best first; then every other subtitle file of the folder.
  - The first time a source has files, its best match is checked.
- **Body, "To This Folder" / "To This Playlist"** (Figma "Folder" / "Folder-1")
  - One row per video (`AddSubtitlesMatchRow.qml`, 40 px a row). On the left: the video icon, the name, and a 1 px dashed leader (Divider/Bright, dashes 8/8, made of Rectangles because VLC's Qt has no Shapes). On the right: the "subtitle multiple" match.
  - Hover shows BG/B2 and the swap icon. A click (or Enter/Space on the row) opens the swap list (`AddSubtitlesChoicePopup.qml`).
  - The swap list is the same in-place list style as the dropdowns. It shows this episode's subtitles first, then the other files (dimmer), then "No subtitles". A video without a match shows "No subtitles found" in the placeholder color.
- **Empty and status text** is centered in the body, Inter 14 FG/A3:
  - no subtitle files in the folder;
  - no videos;
  - searching / reading / downloading;
  - nothing found;
  - errors;
  - OpenSubtitles off. This case adds an "Open Settings" button that opens Settings on Subtitles.
- When the list has rows, a problem (for example a failed download) shows in the footer between Cancel and Save.
- **Footer (72 px, padding 20):** Cancel (RdButton Standard) and Save (RdButton Save, disabled until something is checked or matched).
- **Drag and drop:** subtitle files, folders and links dropped anywhere on the dialog are added. A folder becomes the source folder. Dropped files check themselves.
- **Closing:** a click outside, Escape, X or Cancel close the dialog and stop running requests. While Save is downloading, only Escape closes it. Keys never reach the player behind (RdPanels.acquireModal), and focus goes back to where it was.

### The logic (`add_subtitles.cpp`, QML singleton `AddSubtitles`)
- **`AddSubtitles.open(request)`** opens the dialog. The request can name `mrl` (a file), `target` ("file" / "folder" / "playlist"), `folder` (a folder MRL), `items` (the playlist's media MRLs) and `title`. Without arguments it uses the playing media, and the play queue as its playlist.
  - Decision 12: it opens on "To This File / From Computer", in the video's folder.
- **Matching** (`subtitle_matcher.cpp`) reads names by meaning, not by spelling.
  - It understands the title, the episode (S01E04, 1x04, "S01 E04", "Season 1 Episode 4", E04, a lone number) and the variant after the episode (language name or code, forced, SDH, ...).
  - `The_Wand_S01E04.mp4` matches `thewand_s01e04.srt`, the exact case at video 5:44-5:52.
  - Names without an episode (films) match by title.
  - Among the matches of an episode, the variant picked by hand and the preferred language win. Ties go to the plain file.
  - It also finds subtitles in "Subs" / "Sub" / "Subtitles" folders next to the videos, including one folder per episode ("Subs/S01E04/2_English.srt").
- **From OpenSubtitles** (`opensubtitles.cpp`): the OpenSubtitles.com REST API v1.
  - "To This File" searches the title with season and episode parameters, one page.
  - Folder and playlist targets search the whole season, 3 pages of 50.
  - Results are matched to the videos by the season and episode OpenSubtitles reports.
  - Save downloads the checked or matched files into `<VLC user data>/subtitles/opensubtitles/`.
  - The source stays off until an API key is entered. Its empty state says where to enter the key and how to get one.
  - Optional username and password log in, for the larger download quota. The token is cached for 23 h.
  - Errors come back as sentences: key refused, quota reached, unreachable, wait (429).
- **From Link:** the file is downloaded through VLC's own access modules (`vlc_stream_NewURL`, which follows redirects), at most 10 MB, into `<VLC user data>/subtitles/links/`.
  - A link without a subtitle extension is recognized by its content (WebVTT, ASS, SRT, MicroDVD).
  - A zip link is refused, with a message to extract it first.
  - A local file path is added directly.
- **Web requests:** VLC's Qt is built without Qt Network (contrib `-DFEATURE_network=OFF`). The API calls therefore use a small HTTPS/1.1 client on VLC's TLS sockets (`subtitle_web.cpp`: `vlc_tls_SocketOpenTLS`, Content-Length and chunked bodies, GET redirects).
  - Every request runs on a worker thread and is stopped through its VLC interrupt context: on Cancel or close, after 30 s per request, and when the interface quits.
- **Save:**
  - "To This File" adds the checked files to that video, on top of the ones saved before.
  - Folder and playlist targets replace each video's saved subtitle with its match.
  - A folder also keeps a rule: where its subtitles come from (the computer folder, or the OpenSubtitles search title and language) and the variant picked by hand (the most common one among the swapped rows).
  - If the playing video is one of the targets, its subtitles are added at once and the first is selected.
- **On playback:** when a video starts playing, its saved subtitles are added and the first is selected (P4-08: the external track no longer has to be re-checked every episode).
  - Subtitles VLC already loaded itself (found next to the video, added before) are not added twice: the input item's slaves are compared by path.
  - A video with nothing saved, in a folder with a rule, gets its subtitles matched the same way: the folder is scanned again, or OpenSubtitles is searched and the file downloaded when the key is still there. This covers new episodes added later. The result is saved for that video, so the next time is direct.
- **Storage:** `<VLC user data>/rd-subtitles.json`.
  - It is read on a worker thread at startup and written on its own single worker thread (QSaveFile).
  - Keys are local paths: lower case on Windows, because VLC writes the same file as different MRLs.
- **Performance:**
  - Nothing runs until the dialog opens or a video starts.
  - Folder scans, folder matching (videos × subtitles), downloads and the store are all on worker threads.
  - Lists are ListViews with delegates created on demand.
  - No timers run while idle: the only timer is a request's timeout.

### Settings > Subtitles: OpenSubtitles (`SettingsOpenSubtitlesSection.qml`)
- Section "OpenSubtitles" with three rows, styled like the page's other text rows (Decision 21: Figma has no such rows):
  - API key (password field);
  - Username (optional);
  - Password (optional).
- Each row has an info popover. The username and password rows are disabled until a key is entered.
- The values are kept by AddSubtitles in the interface's QSettings (`RdSubtitles/OpenSubtitles*`). They apply when the field is left.

## 3. VIDEO_INDEX rows covered

Please update their Status after the PC test. Suggested: `in progress (redesign-addsubs <hash>, not verified)`.

| Row | Id | What |
|---|---|---|
| 75 | IA-26 | Modal visual details: header strip, dropdowns opening in place, check, search field, file icons, dashed leader, hover row with swap icon, Cancel/Save colors |
| 76 | P3-05 | "+" on External Tracks opens the modal (needs hookup 5.3) |
| 77 | P3-06 | Target dropdown To This File / To This Folder / To This Playlist |
| 78 | P3-07 | Source dropdown From Computer / From OpenSubtitles / From Link |
| 79 | P3-08 | Folder + OpenSubtitles: search, language, auto-matched list (and the same with From Computer) |
| 80 | P3-09 | Manual re-match per episode, kept for later episodes |
| 81 | P3-10 | Save adds the external track and selects it (needs hookup 5.3; the popup's External Tracks list is the PC session's, see 5.6) |
| 72 | P3-02 | Differently written subtitle names match (the matcher); VLC's own "File name matching" stays as it is |
| 111 | P4-08 | Saved subtitles are added and selected again on every episode |
| 335 | F-09 | Pencil on External Tracks opens the dialog (needs hookup 5.3) |
| 336 | F-10 | "To This File": multi-select subtitle files; OpenSubtitles mode with search and language |
| 160 / 194 (Decisions) | - | The library "Add Subtitle Tracks" / "Edit Subtitle Tracks" entries and the tracks popup can now open the dialog (hookups 5.3, 5.4) |

## 4. Decisions (Claude)

Please add these to VIDEO_INDEX.md "Decisions (Claude)".
- 2026-10-15 W6.5: the source item reads "From Link..." (Decision 17: Figma and the video write "From Link ..." with a space before the ellipsis).
- 2026-10-15 W6.5: subtitles from OpenSubtitles and links are saved in VLC's user data folder (`subtitles/opensubtitles`, `subtitles/links`), never into the user's media folders.
- 2026-10-15 W6.5: "To This File" adds to the subtitles saved before for that file. "To This Folder / Playlist" replaces each episode's saved subtitle with the one shown, since the list shows one per episode.
- 2026-10-15 W6.5: the variant picked by hand, which the next episodes prefer, is learned from the swapped rows of a folder save. A "To This File" save does not change a folder's rule.
- 2026-10-15 W6.5: "To This Playlist" saves per video. Only folders get a rule for media played later: a playlist rule would need the library to tell which playlist a playing item came from.
- 2026-10-15 W6.5: the swap list (no Figma frame, Decision 21) uses the header dropdowns' list style and opens in place over the match. The current episode's files come first, then the others dimmer, then "No subtitles".
- 2026-10-15 W6.5: "To This File" rows hover with the BG/B2 row but no check (the "subtitle multiple" hover look; "subtitle one" has no hover variant).
- 2026-10-15 W6.5: the OpenSubtitles account rows sit in Settings > Subtitles, in a new "OpenSubtitles" section after "Loading Subtitles". The source stays off until a key is entered.
- 2026-10-15 W6.5: the API User-Agent is "VLC Redesign v<version>". Phase 6 should switch it to the public project name, and the API key's consumer on opensubtitles.com should carry the same name.

## 5. What the PC session must change in shared files

Integration (2026-10-15, branch wip/integ-addsubs): items 1-5 are done, item 6 stays open; see BUILD_NOTES.md "W6.5 Add Subtitles merged into the batch".

1. **`modules/gui/qt/maininterface/mainui.cpp`** registers the singleton. It must exist at startup, because it also adds saved subtitles on playback.
   - Include, next to the settings_catalog one (line 42):
     ```cpp
     #include "dialogs/redesign/addsubtitles/add_subtitles.hpp"
     ```
   - Registration, in the VLC.Dialogs block right after the SettingsCatalog registration (line 297):
     ```cpp
     qmlRegisterSingletonInstance<AddSubtitles>( uri, versionMajor, versionMinor, "AddSubtitles",
                                                 new AddSubtitles( m_intf, this ) );
     qmlRegisterUncreatableType<AddSubtitlesModel>( uri, versionMajor, versionMinor, "AddSubtitlesModel", "" );
     ```
2. **`modules/gui/qt/maininterface/qml/MainInterface.qml`**: after `OpenNetworkStreamDialog { ... }` (line 347), host the dialog over every view. It is created on its first open.
   ```qml
   AddSubtitlesHost { }
   ```
3. **`modules/gui/qt/player/qml/TracksPopup.qml`** line 211: External Tracks pencil and "+" (P3-05, F-09). Close the popup first if the dialog should not open over it; the dialog is modal and opens on top either way.
   ```qml
   onActionTriggered: (index) => AddSubtitles.open()
   ```
4. **`modules/gui/qt/medialibrary/qml/RdLibraryItemMenu.qml`**, the library entries (now file pickers):
   - File "Add Subtitle Tracks" (line 69):
     ```qml
     action: () => AddSubtitles.open({ mrl: item.mrl })
     ```
     RdLibraryActions.addTracks(item, false) stays for audio.
   - Playlist "Add Subtitle Tracks" (line 91): `AddSubtitles.open({ target: "playlist", items: <the playlist's media MRLs>, title: item.title })`. The library has to provide the MRLs, for example with a small RdLibraryStore helper that lists a playlist's media.
   - Folder "Edit Subtitle Tracks" (line 127):
     ```qml
     action: () => AddSubtitles.open({ target: "folder", folder: folder.mrl })
     ```
     Its `enabled: Player.isStarted` can go: the dialog no longer needs a playing file.
   - All three files need `import VLC.Dialogs` if they do not have it.
5. **`modules/gui/qt/dialogs/redesign/settings/pages/SettingsSubtitlesPage.qml`**: after the "Loading Subtitles" section (it starts at line 78), add:
   ```qml
   SettingsOpenSubtitlesSection { }
   ```
   It is a SettingsSection, so the page's search finds its rows.
6. **External Tracks list (P3-10).** The tracks popup lists every subtitle under "Embedded Tracks" (W4.2 note: VLC's track model does not mark external files). Saved subtitles are added as associated media, so they show up as tracks, but under Embedded.
   - Showing them under External Tracks with their file name ("The_Wand_S01E04 [English]") needs the track model to tell external tracks apart.
   - That is PC session / track model work. AddSubtitles could expose its saved list for the playing media if that helps.
7. **qmlcheck** needs no change: its stubs come from mainui.cpp, so it picks AddSubtitles up once 5.1 is in. Until then `AddSubtitles` is an unresolved name, which qmlcheck does not flag (runtime lookup).
8. **Build lists** are done on this branch: Makefile.am and meson.build list every new .cpp/.hpp, the two moc files and the eight QML files.

## 6. Not done or limited

- **Subtitle timeline:** not touched (PC session).
- **Zip archives:** zips from links or OpenSubtitles packs are refused with a message. VLC's Qt has no zip reader, and OpenSubtitles' API serves single files anyway.
- **Embedded tracks:** subtitles inside the video file are not listed here (the tracks popup shows them).
- **OpenSubtitles needs real tests with Sticky's key** (stop rule: only Sticky can provide it). Built from the public API description, not run here:
  - the exact language codes ("en", "pt-br", "zh-cn");
  - the feature_details season and episode fields;
  - the download quota without login;
  - redirects of non-alphabetical queries.
  If a field differs, it is a small change in `opensubtitles.cpp`.
- **Password storage:** the OpenSubtitles password is kept in plain text in the interface's QSettings, like VLC's own VLSub extension keeps it in its config. The row's info says so.
- **Playlist rules:** media added to a playlist later get no automatic match (see Decisions).
- **Motion:** none to compare. The dialog and lists open instantly like the other dialogs (Decision 32) and the Figma prototype ("instant" on every Add Subtitles interaction, FIGMA_FLOWS.md). Rows change state instantly as in Figma.
- **Light theme:** every color is a palette token, so it follows the theme and the accent live. Not checked visually.
- **Offline renders vs verification:** offline renders with mock modules matched the Figma frames Folder, Folder-2, Folder-3 and the target/origin lists while coding. They are not verification: the real screenshots on the PC are.

## 7. Files

New, all under `modules/gui/qt/dialogs/redesign/addsubtitles/`:
- `subtitle_matcher.hpp/.cpp`: name parsing and matching
- `subtitle_web.hpp/.cpp`: HTTPS requests on vlc_tls, downloads on vlc_stream
- `opensubtitles.hpp/.cpp`: the OpenSubtitles API
- `subtitle_store.hpp/.cpp`: the saved matches and folder rules
- `add_subtitles_model.hpp/.cpp`: the dialog's two lists
- `add_subtitles.hpp/.cpp`: the AddSubtitles singleton: dialog logic, saving, playback
- `AddSubtitlesDialog.qml`, `AddSubtitlesDropdown.qml`, `AddSubtitlesField.qml`, `AddSubtitlesFileRow.qml`, `AddSubtitlesMatchRow.qml`, `AddSubtitlesChoicePopup.qml`, `AddSubtitlesHost.qml`, `SettingsOpenSubtitlesSection.qml`

Changed:
- `modules/gui/qt/Makefile.am`, `modules/gui/qt/meson.build`: build lists only
- `redesign/ADDSUBS_NOTES.md`: this file

## 8. Self-review (no sub-agents, as asked)

Found and fixed while reviewing:
- The header field's text input had no height, so the search text never showed (found in the offline render).
- One 30 s timeout covered a whole job, so saving a season from OpenSubtitles would have been cut off. Now it is 30 s per request.
- Switching the target while on OpenSubtitles kept the other target's results. A file searches one episode, a folder the whole season, so it now searches again.
- Matching a large folder ran on the UI thread. It now runs on a worker, and swaps made meanwhile win over its result.
- Cancelling the dialog would also have stopped playback lookups. Only the dialog's own jobs stop now.
- Size conversions (qsizetype to int) that MSVC or `-Wconversion` would warn about.
- Dropdown rows the dialog cannot use (no playlist, no file) are dimmed and skipped by the keyboard instead of selectable.

## 9. For the PC test

1. Open the tracks popup "+": the dialog shows the video's folder and its subtitle files, with the best match checked.
2. Save: the subtitle is added and selected.
3. Play the next episode: its saved or matched subtitle is added and selected without opening anything.
4. "To This Folder" with differently written names (thewand_s01e04.srt next to The_Wand_S01E04.mp4).
5. Swap one row to a "_Spanish" file, save, then add a new episode file: it gets the Spanish one.
6. From Link with a raw .srt URL, and with a zip URL (message).
7. OpenSubtitles off (no key): the empty state and its button. With Sticky's key: search, language change, folder season search, save, quota message.
8. Escape, click outside, X, Cancel; Tab through everything; drop files and folders on the dialog.
9. Window very small: the dropdowns shrink and the field keeps room.
10. Performance: open with a 500-file folder; the dialog opens at once and the list fills in.
