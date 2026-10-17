# Code audit against Figma (wip/next-batch)

A code-only comparison of every coded but unverified VIDEO_INDEX row (and the rows still marked todo that are built) with the verification spec (`redesign/tools/verify/spec/`) and the Figma file. Base: origin/wip/next-batch at 7de8c76745. **Nothing here is verified and no row status changed**: every row, matching or not, still needs the PC test with real screenshots (Decision 55).

How it was done: 209 rows in four screen groups. For each row the QML / C++ that builds it was read and every value the spec gives for the row's elements was compared with the code: position, size, padding and gaps, radius, colour tokens (dark and light), stroke, font size and weight, icon, wording (the video's wording where Decision 11 applies; differences covered by a Decision are not listed). It also checks that each Figma state (hover, pressed, active, disabled) and the row's behaviour exist. Offline only: values that depend on runtime layout are marked `sure: low` or `medium`.

Each line: row, file and line, what the code has, what Figma has, impact on the look or behaviour, and how sure the finding is. Report only: the PC session has a fix branch open on the control bar, sidebars, dropdowns and tracks popup, so nothing is fixed here.

## Summary

| Screen | Mismatches | high | medium | Rows matching (still need PC test) | Could not check |
|---|---|---|---|---|---|
| Player | 18 | 1 | 4 | 71 | 4 |
| Sidebars and popups | 18 | 0 | 5 | 42 | 2 |
| Library, music, playlists and mini player | 21 | 0 | 7 | 35 | 5 |
| Dialogs | 16 | 0 | 6 | 45 | 2 |
| **Total** | **73** | **1** | **22** | **193** | **13** |

A row can have both a mismatch line and a match line: the parts that agree are listed under Matches.

## Biggest differences (high and medium impact, all screens)

- [Player] **Row 31** | `modules/gui/qt/player/qml/controlbarcontrols/VolumeWidget.qml:191` | code: the cone slider maps the pointer linearly (T.Slider, from 0 to 2, empty handle, so value = x / 88 * 2), but the fill is drawn with the 63/88 knee (line 164). The fill edge does not sit under the pointer: pointer at 22 px gives 50 % drawn at 31.5 px, pointer at 44 px gives 100 % drawn at 63 px, pointer at 63 px gives 143 % drawn at 74 px | Figma: volume.json variants (50 % = mask 33 px, 100 % = 63 px, 200 % = 88 px), DRAG interaction on 491:1733; a click or drag inside the cone sets the level where the pointer is (row text, video 3:08) | impact: high | sure: high
- [Dialogs] **Row 286** | `modules/gui/qt/dialogs/redesign/settings/pages/SettingsAudioPage.qml:528` | code: Advanced Options has 4 rows (Pass compressed audio, Detect Dolby Surround, Resampling quality, Media role); no "Visualization size" row anywhere in the dialog (grep finds none) | Figma: settings-audio-1.json Advanced Options 5th row "Visualization size (i) [dropdown: Match window]" (y 1563) | impact: medium | sure: high
- [Dialogs] **Row 287** | `modules/gui/qt/dialogs/redesign/settings/SettingsEqualizer.qml:188` | code: band column = slider 320, spacing 12, name item 21 (text bottom-anchored), spacing 12, value box 32: name text top about 16 px under the track, value box 45 px under it; open panel 6+24+24+397+20 = 471 high | Figma: settings-audio-1.json / eq.json "Frame 308" (spacing 33): name "Preamp" 33 px under the 320 track (track 54..374, name y 407), value box "Frame 265" 13 px under the name (y 437); panel 489 high. Names about 17 px and value boxes about 18 px too high, panel 18 px short | impact: medium | sure: high
- [Dialogs] **Row 287** | `modules/gui/qt/dialogs/redesign/settings/SettingsEqualizer.qml:44` | code: the panel is BG/A4 (dark #191919 / light #B3B3B3) in both states | Figma: eq.json variant "Default" (closed, "Open Equalizer") is BG/B2 (#090909 / #DEDEDE), only "Variant2" (open) is BG/A4 | impact: medium | sure: high
- [Dialogs] **Row 77** | `modules/gui/qt/dialogs/redesign/addsubtitles/AddSubtitlesDropdown.qml:52` | code: no HoverHandler / cursorShape on the dropdown trigger or on its list rows (arrow cursor; RdDropdown and RdButton elsewhere use Qt.PointingHandCursor) | Figma/row: IA-26 and P3-06 show a pointer (hand) cursor on hover of the dropdown and its options | impact: medium | sure: high
- [Dialogs] **Row 78** | `modules/gui/qt/dialogs/redesign/addsubtitles/AddSubtitlesDialog.qml:293` | code: the source dropdown ("From Computer") is always visible next to the target dropdown, also while the target list opens by itself on dialog open (Decision 46); no fade-in | Figma/row: P3-07 and IA-26 say the second dropdown fades in to the right only after the target is chosen (Figma frames show only the end state, 1992:5562 "origin") | impact: medium | sure: high
- [Library, music, playlists and mini player] **Row 193** | `modules/gui/qt/player/qml/QueueSidebar.qml:318` | code: every queue row, the playing one included, shows the gray "move" handle (FG/A3); only the title turns accent | Figma/row: row 193 (video 11:44-11:49) shows the playing row with an orange play glyph and orange name, the other rows the "=" handle (the mini queue does this, RdMiniQueue.qml:204) | impact: medium | sure: high
- [Library, music, playlists and mini player] **Row 203** | `modules/gui/qt/medialibrary/qml/RdLibraryPage.qml:799` | code: song rows are media rows, `secondary` false, so an unplayed song title is FG/A1 (#969696) (RdLibraryRow.qml:111-115); only played songs (playcount > 0) get FG/A3 | Figma: sidebar.json variant music3 and player-music-1.json: all three song rows ("untangle / moonlight / black bird - juxtopposed", nodes 4778:25025, 6207:13669, 6207:13686) are FG/A3 #6B6B6B (light #6B6B6B) | impact: medium | sure: high
- [Library, music, playlists and mini player] **Row 204** | `modules/gui/qt/medialibrary/qml/RdLibraryPage.qml:799` | code: same as row 203, song row titles FG/A1 next to their covers | Figma: sidebar.json music3 song rows FG/A3 | impact: medium | sure: high
- [Library, music, playlists and mini player] **Row 208** | `modules/gui/qt/medialibrary/qml/RdLibraryHeader.qml:128` | code: only the page area crossfades (RdLibraryContent.qml:44-65, 180 ms); the address line is bound straight to `RdLibraryNav.location.crumbs` and the count to the new page, so both switch instantly | Figma/row: row 208 (video only) old breadcrumb and rows fade out while the new ones fade in at the same place, both overlapping | impact: medium | sure: high
- [Library, music, playlists and mini player] **Row 226** | `modules/gui/qt/dialogs/redesign/OpenNetworkStreamDialog.qml:433` | code: the Playlist Name field (nameField) is never filled from the pasted link; it stays empty unless typed, and without a name the links just play (line 90-100) instead of becoming the "Index" stream list | Figma/row: row 226 shows "Index" filled in from the m3u file name after pasting `.../index.m3u`, Save then lands in "Network > Index" (Decision (Claude) W6.4 / P6-13 assigned this auto-fill to W5.4b; it was not built) | impact: medium | sure: high
- [Library, music, playlists and mini player] **Row 318** | `modules/gui/qt/player/qml/QueueSidebar.qml:318` | code: same as row 193, the current item gets the move handle, not the orange play icon | Figma/row: row 318 current item "orange play icon and orange name", next item drag handle | impact: medium | sure: high
- [Library, music, playlists and mini player] **Row 337** | `modules/gui/qt/medialibrary/qml/RdLibraryItemMenu.qml:83` | code: Favorite is only added when `item.isFavorite !== undefined`; playlist items never carry it (RdLibraryPage.qml:524-526 builds playlist items without isFavorite, MLPlaylistListModel has no favorite role, openForPage passes `{kind, id, title}` only), so the playlist "..." menu has no Favorite row at all | Figma: playlist-context-menu.json row 2 "Favorite" (node 2459:9392, icon favorite two-tone) between Play and Shuffle | impact: medium | sure: high
- [Player] **Row 66** | `modules/gui/qt/util/qml/FadeControllerStateGroup.qml:63` | code: same 200 ms InSine / OutSine fade when Hide UI is chosen in the right-click menu | Figma / Decision 45: 300 ms ease-in-and-out | impact: medium | sure: high
- [Player] **Row 67** | `modules/gui/qt/util/qml/FadeControllerStateGroup.qml:63` | code: Hide UI (and every bar show / hide) fades over VLCStyle.duration_long = 200 ms with InSine (hide) / OutSine (show) (lines 63, 83; used by Player.qml:1514 and 1884) | Figma / Decision 45: Hide UI keeps the prototype's 300 ms smart animate, ease-in-and-out (player-hide-ui.json frame 3328:11554 transition 0.3 s EASE_IN_AND_OUT) | impact: medium | sure: high
- [Sidebars and popups] **Row 132 (same for rows 133, 134)** | `modules/gui/qt/player/qml/AudioSettingsPage.qml:214` (`leading: curve` -> `modules/gui/qt/widgets/qml/RdEqCurve.qml:25`) | code: each preset row draws RdEqCurve, a 24x12 item of 10 flat accent bars built from the preset's band gains on a 2 px FG/A2 baseline (stepped blocks) | Figma: eq-presets.json "EQ presets" open list (2372:8491), each row has the Icon component `name=EQ, EQ=<preset>` (24x24, e.g. I2372:8494 EQ=classical, 6114:14027 EQ=full bass): smooth filled lobes per preset; these exact glyphs are already bundled as `pixmaps/redesign/eq_eq-*.svg` (assets.qrc:148-) but nothing uses them. BUILD_NOTES lists it as "not changed (no Canvas / Shapes)", which does not apply to the SVGs; no Decision covers it | impact: medium | sure: high | note: wip/sidebar-musthaves (not merged) replaces RdEqCurve with RdEqCurveItem, drawn from the band gains in the Figma geometry; the Figma glyphs also exist as eq_eq-*.svg: which one to use is for StickyGonzales
- [Sidebars and popups] **Row 248 (also row 250)** | `modules/gui/qt/medialibrary/mlbookmarkmodel.cpp:71` (used by `medialibrary/qml/RdBookmarkList.qml:63`) | code: bookmark time is `VLCDuration::formatHMS()` = "00:42" (MM:SS, H:MM:SS over an hour, no milliseconds) | Figma: "bookmarks" panel 6320:13816 text "00:00:42:023" (HH:MM:SS:mmm), same in the video row text | impact: medium | sure: high
- [Sidebars and popups] **Row 250** | `modules/gui/qt/widgets/qml/RdListRow.qml:61-62` | code: chapter title starts right after the 34 px number column with no gap: title x = 4 + 34 = 38 in the row | Figma: "chapters" panel 6321:14169 title x 48 in the row (padding 4, number 34, itemSpacing 10) | impact: medium | sure: high
- [Sidebars and popups] **Row 28 (also row 29)** | `modules/gui/qt/player/qml/QueueSidebar.qml:275` + `widgets/qml/RdListRow.qml:62` | code: queue row leftPadding 32 + title leftMargin 4 = title x 36 | Figma: Controls "queue" 463:850 title x 42 in the row (32 px handle frame + itemSpacing 10) | impact: medium | sure: high
- [Dialogs] **Row 287** | `modules/gui/qt/dialogs/redesign/settings/SettingsEqualizer.qml:271` | code: band value box = RdValueBox default font 14 px (VLCStyle.rd_fontSize_label), padding 6 each side in 60 px: "12.0 dB" at 14 px is about 50 px wide in a 48 px text area (may elide) | Figma: eq.json "12.0 dB" / "0.0 dB" Inter 400 12 / 14.52 FG/A2, centered in the 60x32 box | impact: medium | sure: medium
- [Player] **Row 329** | `modules/gui/qt/player/qml/controlbarcontrols/VolumeWidget.qml:116` | code: the "100 %" tooltip is centered on the 24 px speaker (left edge at speaker.x - 48.5) | Figma: speaker Icon 491:1732 ON_HOVER opens "audio value" (121x37) with overlayRelativePosition (-2, -63) relative to the speaker, so it spans speaker.x - 2 to speaker.x + 119, i.e. centered over the speaker plus cone group (same convention as the "..." menu overlay -17,38 of 247:454). About 46 px further left than Figma. y (-63) matches | impact: medium | sure: medium
- [Player] **Row 329** | `modules/gui/qt/player/qml/controlbarcontrols/VolumeWidget.qml:143` | code: hovering the cone shows VLC's stock PointingToolTip ("50%", no space, stock look) because SliderExt's default `PointingToolTipAttached.visible: hovered || visualFocus || pressed` is only overridden while the right button is held (line 265); with the empty handle it is anchored at the cone's left tip | Figma: the cone has only a DRAG interaction, no tooltip; the only volume tooltip is "audio value" on the speaker hover | impact: medium | sure: medium
- [Sidebars and popups] **Row 151 (also row 152)** | `modules/gui/qt/player/qml/Player.qml:1967` (queuePanelLoader) and `Player.qml:82` (`_videoInset` only counts the library) | code: the queue sidebar floats over the video; the video keeps the whole width and stays centered on the window | Figma/row: VIDEO_INDEX rows 151/152 (video 9:29-9:34) say the video shrinks / stays centered in the space left of the queue panel (no Figma Player frame shows the queue open, so this is the video's behaviour) | impact: medium | sure: medium

## Player: control bar, seek bar, volume, top bar, menus, icons

### Mismatches

- **Row 31** | `modules/gui/qt/player/qml/controlbarcontrols/VolumeWidget.qml:191` | code: the cone slider maps the pointer linearly (T.Slider, from 0 to 2, empty handle, so value = x / 88 * 2), but the fill is drawn with the 63/88 knee (line 164). The fill edge does not sit under the pointer: pointer at 22 px gives 50 % drawn at 31.5 px, pointer at 44 px gives 100 % drawn at 63 px, pointer at 63 px gives 143 % drawn at 74 px | Figma: volume.json variants (50 % = mask 33 px, 100 % = 63 px, 200 % = 88 px), DRAG interaction on 491:1733; a click or drag inside the cone sets the level where the pointer is (row text, video 3:08) | impact: high | sure: high
- **Row 67** | `modules/gui/qt/util/qml/FadeControllerStateGroup.qml:63` | code: Hide UI (and every bar show / hide) fades over VLCStyle.duration_long = 200 ms with InSine (hide) / OutSine (show) (lines 63, 83; used by Player.qml:1514 and 1884) | Figma / Decision 45: Hide UI keeps the prototype's 300 ms smart animate, ease-in-and-out (player-hide-ui.json frame 3328:11554 transition 0.3 s EASE_IN_AND_OUT) | impact: medium | sure: high
- **Row 66** | `modules/gui/qt/util/qml/FadeControllerStateGroup.qml:63` | code: same 200 ms InSine / OutSine fade when Hide UI is chosen in the right-click menu | Figma / Decision 45: 300 ms ease-in-and-out | impact: medium | sure: high
- **Row 329** | `modules/gui/qt/player/qml/controlbarcontrols/VolumeWidget.qml:116` | code: the "100 %" tooltip is centered on the 24 px speaker (left edge at speaker.x - 48.5) | Figma: speaker Icon 491:1732 ON_HOVER opens "audio value" (121x37) with overlayRelativePosition (-2, -63) relative to the speaker, so it spans speaker.x - 2 to speaker.x + 119, i.e. centered over the speaker plus cone group (same convention as the "..." menu overlay -17,38 of 247:454). About 46 px further left than Figma. y (-63) matches | impact: medium | sure: medium
- **Row 329** | `modules/gui/qt/player/qml/controlbarcontrols/VolumeWidget.qml:143` | code: hovering the cone shows VLC's stock PointingToolTip ("50%", no space, stock look) because SliderExt's default `PointingToolTipAttached.visible: hovered || visualFocus || pressed` is only overridden while the right button is held (line 265); with the empty handle it is anchored at the cone's left tip | Figma: the cone has only a DRAG interaction, no tooltip; the only volume tooltip is "audio value" on the speaker hover | impact: medium | sure: medium
- **Row 220** | `modules/gui/qt/widgets/qml/RdOptionRow.qml:125` | code: submenu chevron ">" drawn in FG/A3 (#6B6B6B dark / #6B6B6B light) | Figma: menu.json 6062:13519 and right-click-menu.json 6077:14313 chevron stroke style 217:218 = FG/A2 (#8F8F8F dark / #2E2E2E light) | impact: low | sure: high
- **Row 64** | `modules/gui/qt/widgets/qml/RdOptionRow.qml:125` | code: right-click menu chevrons (Playback, Video, Audio, Subtitle, More Settings, Playlist, Open Media) in FG/A3 | Figma: right-click-menu.json chevron icons FG/A2 | impact: low | sure: high
- **Row 328** | `modules/gui/qt/player/qml/ControlBar.qml:266` | code: clicking the current time selects the whole text (selectAll, Accent/DIm selection) | Figma: current-time.json variant state=click (1904:7241): text unselected FG/A2 on BG/B2 with a 1 px Accent/Main caret right after the text (Vector 76 at x 69.5) | impact: low | sure: high
- **Row 44** | `modules/gui/qt/widgets/qml/CSDWindowButtonSet.qml:33` | code: minimize / maximize / close icons use the Window color set's fg.primary, which falls back to View fg.primary = FG/A1 (#969696 dark, #3C3C3C light); the fullscreen button between them (IconToolButton) is FG/A2, so the four glyphs differ slightly | Figma: player.json 247:387 / 187:345 / 187:347 strokes style 217:218 = FG/A2 (#8F8F8F dark, #2E2E2E light) | impact: low | sure: high
- **Row 60** | `modules/gui/qt/widgets/qml/IconToolButton.qml:42` | code: the "..." button is `checked` while the main menu is open (MainMenuButton.qml:39, TopBar.qml:178), so its icon turns Accent/Main | Figma: icon.json has only "more" state=default (247:418); the menu opens as an overlay over a frame whose "..." stays FG/A2 | impact: low | sure: high
- **Row 212** | `modules/gui/qt/player/qml/Player.qml:1877` | code: the 1 px Divider/Dim line on the control bar is drawn only in the light theme | Figma: player-music.json Controls instance 4767:23748 (dark "Player - Music") has stroke Divider/Dim 1 px inside, like "Player - Light"; the dark video frames (player.json) have none | impact: low | sure: high
- **Row 330** | `modules/gui/qt/player/qml/controlbarcontrols/VolumeWidget.qml:164` | code: 0-100 % fill is linear over 0-63 px (10 % = 6.3, 30 % = 18.9, 50 % = 31.5, 60 % = 37.8, 70 % = 44.1, 80 % = 50.4, 90 % = 56.7) | Figma: volume.json mask widths 10 % = 7, 30 % = 20, 50 % = 33, 60 % = 41, 70 % = 48, 80 % = 53, 90 % = 58 (150 % = 75 and 200 % = 88 match); up to 3.9 px narrower | impact: low | sure: high
- **Row 327** | `modules/gui/qt/player/qml/ControlBar.qml:353` | code: the duration label gets a BG/B2 hover fill | Figma: duration.json has only state=Default and state=click (no fill in either; its ON_HOVER interaction has no destination) | impact: low | sure: high
- **Row 331** | `modules/gui/qt/widgets/qml/AnimatedBackground.qml:60` | code: the icon button hover fill (#FFFFFF 6 %, radius 4) fades in and out over 200 ms (DelayedBehavior ColorAnimation) | Figma: icon-wrapper.json Default to hover (177:97 to 177:99) is an instant change (ON_HOVER, transition null) | impact: low | sure: high
- **Row 56** | `modules/gui/qt/player/qml/ControlRepeater.qml:76` | code: no move / add transition in ControlRepeater, ControlLayout or PlayerControlLayout (controls jump when one is added or hidden) and the active to inactive icon swap is instant | row text: neighbouring icons slide when an icon is inserted, the subtitle icon cross-fades from active to inactive (likely video editing of a design change; Figma Icon Wrapper click change is instant) | impact: low | sure: high
- **Row 183** | `modules/gui/qt/player/qml/controlbarcontrols/FolderChipWidget.qml:71` | code: folder icon at chip.x + 4 and chip width text + 40 (86 px for "Videos") | Figma: player.json "Frame 12" 187:338: icon cell 28 with padding 2 (glyph at chip.x + 2), padding right 4, 82 px for "Videos"; the text position (chip.x + 32) matches, so the glyph is 2 px right and the hover area 4 px wider | impact: low | sure: high
- **Row 241** | `modules/gui/qt/player/qml/ResumeDialog.qml:123` | code: the resume toast appears and disappears instantly (visible true / false, no transition) | row text: appears with a fade / slide up | impact: low | sure: medium
- **Row 60** | `modules/gui/qt/menus/qml/RdMainMenu.qml:43` | code: main menu opens at button.x + 2 - 17 and button.y + 4 + 38 (button 28x32 centered in the 40 px bar): menu at x 36, y 46 for the default bar | Figma: 247:454 overlay (-17, 38) relative to the 28x28 "more" instance at (51, 6): menu at x 34, y 44 | impact: low | sure: medium

### Code matches Figma, still needs PC test

- Row 5: top bar cone uses Brand.logoIcon with Accent/Logo, follows live accent (brand item, Decision 48)
- Row 6: rd* palette dark and light values equal styles.txt tokens (light FG/1, FG/2, FG/A4 per Decisions 33, 44)
- Row 7: cone glyph is the Figma export (vlc.svg, accent slot only); brand item
- Row 10: full two-tone set exported (every two-tone variant of icon.json has an SVG with Accent/DIm slot), used in menus
- Row 12: full monochrome set exported (186 of 188 icon.json variants have SVGs; missing only the empty "check" default and "0" placeholders)
- Row 13: monochrome glyphs are separate Figma exports, not recoloured two-tone ones
- Row 14: radii play 6, time labels 6, seek 6 / fill 4, icon wrapper 4, Bar button 4, menus 10, toast 16, thumbnail 14
- Row 15: active variants subtitles / audio / playback-settings / lists _state-active drawn in the accent when checked
- Row 17: play pill 54x28 r6 Accent/Main, glyph FG/B1, play glyph 1 px right (Figma padding 17/15)
- Row 21: default video layout prev, play, next | seek row | volume, audio, subtitles, gear, queue; stop removed
- Row 22: previous / next filled glyphs, 30x28 cells, 8 px gaps (Frame 25)
- Row 23: fullscreen in the top bar right zone between maximize and close (Decision 1, 51)
- Row 25: queue button uses "lists", playlist glyph separate export
- Row 26: queue button last on the right, 20 px after the gear; repeat / shuffle not in the bar
- Row 27: gear button uses "playback-settings" / "playback-settings_state-active"
- Row 30: cone keeps the green to red gradient (#95D318, #B2A918, #D37918, #FF3737 at 0 / 0.58 / 0.79 / 1) and boost past 100 % (qt-max-volume default 200)
- Row 32: speaker icon volume_value-high, cone with no handle and no label, empty part BG/B2 (light BG/A5), tint #000 20 % (light #FFF 20 %)
- Row 33: seek row in the single bar between current time and duration, 8 px gaps
- Row 34: bar 54 px, padding 20 / 11, group gap 20, background BG/A3 (dark Player frame override) or opaque BG/A3 Transparent with Divider/Dim top line in light
- Row 35: track 28 px BG/B2 r6, fill BG/Accent Bright inset 2 r4, handle 8x24 Accent/Main r4, times Inter 400 15 FG/A2 in 76x28 boxes
- Row 36: preview card shows the hovered or dragged position's frame and time; the current time label shows the scrub time while dragging
- Row 37: card 272x189 r14, padding 10, picture 252x142 r4, gap 10, time Inter 400 15 FG/A2 centered, centered on the pointer 18 px above the track (prototype -132,-209 of the playhead)
- Row 39: top bar 40 px BG/A3 (light BG/A3 Transparent), title Inter 400 14 FG/A2 centered, window buttons 36 wide icons 24
- Row 41: windowed both bars on mouse move with 3 s hide, fullscreen per-edge zones (Decision 30)
- Row 42: bars fade instead of instant switch, covered by Decision 30
- Row 43: top bar right zone minimize, maximize, fullscreen, close; PiP skipped (Decision 1)
- Row 45: fullscreen kept in the top bar, not in the control bar
- Row 47: playing shows pause glyph on FG/A3 pill, paused shows play on Accent/Main, instant switch
- Row 48: play / pause fills Accent/Main and FG/A3, same 54x28 pill
- Row 54: audio and video glyphs are Figma exports; Show Preferences uses the Bar style BG/B2 r4 FG/A3
- Row 55: audio button left of subtitles, opens the tracks popup on Audio, accent while open
- Row 57: no video track button in the default bar
- Row 59: title typography Inter 400 14 FG/A2; inset video frame (see row 179)
- Row 60: menu bar replaced by the "..." button at x 51 (cone cell 38 at 6, gap 7)
- Row 61: main menu order, wording and shortcuts are Figma menu.png (covered by Decision 2 and the W4.9 Decision (Claude))
- Row 62: each main menu row uses the matching two-tone icon (file, folder, streaming, disc, capture-device, swap, recent, profile, hotkeys, paint, settings, info)
- Row 65: right-click icons per Figma (two-tone playback / stop / previous / next / record, "ui" with Accent/DIm slash, video top strip Accent/Main as in Figma)
- Row 82: an open panel or menu locks the bars, closed they auto-hide after 3 s while playing
- Row 84: right group order speaker, cone, audio, subtitles, gear, queue
- Row 104: gear active variant is the filled accent cog with play cut-out (playback-settings_state-active)
- Row 163: Inter is the application font (rdfonts.cpp), icons 1.5 px exports in FG/A2, main menu shadow #000 46 % y8 blur 15, right-click menu without shadow as in Figma
- Row 179: video frame inset 10 px BG/A3, inner radius 9, opening from y 40 to the control bar top (Frame 312: r19, 20 px centered stroke)
- Row 182: folder chip click opens the compact library on the folder (RdPanels.libraryRequested(true))
- Row 185: default top bar left zone "...", sidebar toggle, divider, folder chip at x 51 / 89 / 117 / 141 with 10 px gap and no gap at the divider
- Row 186: sidebar toggle sidebar_direction-left closed, sidebar_state-active (gray filled column) open
- Row 191: library open keeps both bars shown; top bar layout unchanged
- Row 192: control bar glyphs are the Figma exports, all FG/A2
- Row 212: music layout prev, -15, play, +15, next with 8 px gaps, backward-15-sec / forward-15-sec icons, 15 s jumps
- Row 213: waveform bars 2 px, gap 3, heights 2 to 14 in steps of 2, padding 6, played Accent/DIm, unplayed FG/A4, playhead 4x24 Accent/Main with 3 px gaps, option qt-seek-waveform
- Row 219: two-tone icons draw the accent part in Accent/DIm (color2), outline FG/A2
- Row 221: final Figma order with divider after Open Recent (Decision 2)
- Row 223: final order only, no reorder transition (row says the transition is video FX)
- Row 240: resume toast 24 px above the control bar, Continue Watching restores the position, 10 s timeout
- Row 243: played fill BG/Accent Bright, playhead Accent/Main
- Row 255: Settings row Ctrl + P opens the redesigned Settings dialog (DialogsProvider::prefsDialog to settingsDialog)
- Row 260: Keyboard Shortcuts row without shortcut text, opens the keyboard shortcuts dialog
- Row 261: hotkeys_two-tone-yes has the key dots and space bar in the Accent/DIm slot
- Row 309: Profile submenu 265 wide, 11 px right of the menu, first row level with the hovered row, accent check on the current profile, divider then New (add icon); hovered parent row stays BG/A2
- Row 321: shapes match the earlier rows (pause pill, seek fill and playhead)
- Row 327: duration click toggles remaining time "-HH:MM:SS", 76x28, Inter 400 15 FG/A2
- Row 332: subtitles / audio toggle the tracks popup on their tab, gear opens Playback, list opens Queue; same button closes, another switches; only the matching button is accent
- Row 347: menu two-tone accents use Accent/DIm (RdOptionRow color2), Figma video icon's accent strip is Accent/Main and drawn so
- Row 220: rows 48 px, padding 14 / 2, gap 10, label FG/A2, shortcut FG/A3 right-aligned, hover BG/A2 r6, panel 375 wide r10 padding 4, 1 px Divider/Dim, height 585 for 12 rows (chevron colour listed above)
- Row 64: right-click order, wording and dividers as Figma, 292 wide (Record shortcut shows VLC's Shift + R, Decision 22)
- Row 66: Hide UI row with "ui" icon and "Ctrl + \", reads "Show UI" while hidden (duration listed above)
- Row 67: Hide UI hides both bars and panels, bars stay hidden, 10 px frame around the video (duration listed above)
- Row 328: hover BG/B2 r6, 1 px Accent/Main caret, Enter commits, Escape cancels (selection listed above)
- Row 329: tooltip 121x37 min, padding 10, r6, BG/B1 (opaque), drop shadow, Inter 400 14 FG/A1, "N %" (position listed above)
- Row 330: range 0 to 200 %
- Row 331: hover #FFFFFF 6 % r4 on 30x32 bar buttons
- Row 183: folder name Inter 400 14 FG/A2 at chip.x + 32, divider 1.5 x 19.5 Divider/Bright; the folder glyph in a category root is Figma's folder icon (Player.png "Videos")

### Could not check

- Row 52: the cited "subtitle one" spec is the Add Subtitles dialog file row (dialogs group, AddSubtitlesFileRow.qml); the bar button part (position, accent while open) matches. The tracks popup layout belongs to the sidebars group.
- Row 10 / 12 / 13 / 22 / 25 / 27 / 54 / 192 / 261: icon glyph geometry: the Figma JSON has no vector paths, so the SVGs could only be confirmed as Figma exports (git history), not compared shape by shape
- Row 36: whether frames arrive fast enough and match the hovered position depends on RdSeekThumbnailer at runtime
- Row 41: the fullscreen hover zone uses MainCtx.fsSensitivity (40 by default); its real feel needs the PC test

## Sidebars and popups: settings sidebar, tracks popup, queue sidebar

### Mismatches

- **Row 132 (same for rows 133, 134)** | `modules/gui/qt/player/qml/AudioSettingsPage.qml:214` (`leading: curve` -> `modules/gui/qt/widgets/qml/RdEqCurve.qml:25`) | code: each preset row draws RdEqCurve, a 24x12 item of 10 flat accent bars built from the preset's band gains on a 2 px FG/A2 baseline (stepped blocks) | Figma: eq-presets.json "EQ presets" open list (2372:8491), each row has the Icon component `name=EQ, EQ=<preset>` (24x24, e.g. I2372:8494 EQ=classical, 6114:14027 EQ=full bass): smooth filled lobes per preset; these exact glyphs are already bundled as `pixmaps/redesign/eq_eq-*.svg` (assets.qrc:148-) but nothing uses them. BUILD_NOTES lists it as "not changed (no Canvas / Shapes)", which does not apply to the SVGs; no Decision covers it | impact: medium | sure: high | note: wip/sidebar-musthaves (not merged) replaces RdEqCurve with RdEqCurveItem, drawn from the band gains in the Figma geometry; the Figma glyphs also exist as eq_eq-*.svg: which one to use is for StickyGonzales
- **Row 248 (also row 250)** | `modules/gui/qt/medialibrary/mlbookmarkmodel.cpp:71` (used by `medialibrary/qml/RdBookmarkList.qml:63`) | code: bookmark time is `VLCDuration::formatHMS()` = "00:42" (MM:SS, H:MM:SS over an hour, no milliseconds) | Figma: "bookmarks" panel 6320:13816 text "00:00:42:023" (HH:MM:SS:mmm), same in the video row text | impact: medium | sure: high
- **Row 250** | `modules/gui/qt/widgets/qml/RdListRow.qml:61-62` | code: chapter title starts right after the 34 px number column with no gap: title x = 4 + 34 = 38 in the row | Figma: "chapters" panel 6321:14169 title x 48 in the row (padding 4, number 34, itemSpacing 10) | impact: medium | sure: high
- **Row 28 (also row 29)** | `modules/gui/qt/player/qml/QueueSidebar.qml:275` + `widgets/qml/RdListRow.qml:62` | code: queue row leftPadding 32 + title leftMargin 4 = title x 36 | Figma: Controls "queue" 463:850 title x 42 in the row (32 px handle frame + itemSpacing 10) | impact: medium | sure: high
- **Row 151 (also row 152)** | `modules/gui/qt/player/qml/Player.qml:1967` (queuePanelLoader) and `Player.qml:82` (`_videoInset` only counts the library) | code: the queue sidebar floats over the video; the video keeps the whole width and stays centered on the window | Figma/row: VIDEO_INDEX rows 151/152 (video 9:29-9:34) say the video shrinks / stays centered in the space left of the queue panel (no Figma Player frame shows the queue open, so this is the video's behaviour) | impact: medium | sure: medium
- **Row 96 (also row 95)** | `modules/gui/qt/player/qml/SubtitleSettingsPage.qml:283-287` | code: Font Size slider 25..300 % step 25 -> 11 intervals = 10 tick marks; "Auto" (100 %) sits at 27 % of the track | Figma: settings-subtitles sidebar 804:1287 "degrees": 4 inner marks (5 intervals) and the "Auto" thumb at 232 of 22..378 (about 60 %, on the 3rd mark). Listed in BUILD_NOTES as "not changed", no Decision | impact: low | sure: high
- **Row 29** | `modules/gui/qt/player/qml/QueueSidebar.qml:493` (HeaderButton) | code: header icons sort / repeat / shuffle / remove / add FG/A2 (#8F8F8F), FG/A1 on hover | Figma: Controls "queue" 463:843, 1701:3775, 1701:3777, 463:844, 463:845 strokes FG/A3 (#6B6B6B); same for the bookmarks "-" / "+" (6320:13809, 6320:13810) | impact: low | sure: high
- **Row 29** | `modules/gui/qt/player/qml/QueueSidebar.qml:302` | code: drag handle icon "move" FG/A3 | Figma: 463:849 move strokes FG/A2 (#8F8F8F) | impact: low | sure: high
- **Row 344** | `modules/gui/qt/player/qml/VideoSettingsPage.qml:476-486` | code: the crop link IconToolButton has no `rdIconChecked`; when linked it draws the plain "link" glyph (1.5 px, no middle bar) tinted accent | Figma: Icon "link" state=active = `pixmaps/redesign/link_state-active.svg` (2 px strokes plus the middle bar, accent); Video - Crop 774:1081 shows the default state | impact: low | sure: high | note: wip/sidebar-musthaves (not merged) adds rdIconChecked "link_state-active"
- **Row 335 (also row 74)** | `modules/gui/qt/player/qml/TracksPopup.qml:343-353` (IconToolButton, ToolButton colour set `style/systempalette.cpp:714`) | code: External Tracks pencil / + and Output Device refresh icons FG/A2 | Figma: Controls "subtitles" 6059:13203 (edit) and 6059:13204 (add) strokes FG/A3 (#6B6B6B) | impact: low | sure: high
- **Row 116 (also row 122)** | `modules/gui/qt/player/qml/SubtitleSettingsPage.qml:96`, `AudioSettingsPage.qml:84` (`note:` rendered by `widgets/qml/RdSettingsSection.qml:49-60`) | code: an extra 12 px FG/A3 line "Applies from the next file" / "Track and language apply from the next file" under the Defaults header (4 px top padding + about 15 px text), which pushes every row below about 19 px down | Figma: settings sidebar "Frame 101" Defaults header directly followed by "Frame 92" rows (first row at y 100); Decision (Claude) W4.6 covers only the Appearance note | impact: low | sure: high
- **Row 248** | `modules/gui/qt/player/qml/QueueSidebar.qml:460` (Header used by the Bookmarks page, line 351) | code: bookmarks header 68 px, rows start at 51 + 68 = 119 | Figma: "bookmarks" 6320:13801 "Frame 60" is 64 px (24 px icons, no 28 px frames), first row at 116 | impact: low | sure: high
- **Row 124** | `modules/gui/qt/widgets/qml/RdSlider.qml:130` | code: Audio Track Delay track 16 px (same as Subtitles) | Figma: audio settings 1905:7353 "range" 360x21 (wrapper 54 high); BUILD_NOTES says "not changed", no Decision | impact: low | sure: high
- **Row 248** | `modules/gui/qt/widgets/qml/RdListRow.qml:62` (via `RdBookmarkList.qml:56`) | code: bookmark name at x 4 in the row | Figma: 6320:13815 "DON'T BLINK 1" at x 0 of the row (row padding right 4 only) | impact: low | sure: high
- **Row 96** | `modules/gui/qt/player/qml/SubtitleSettingsPage.qml:204` (RdSettingRow 48 px, control centered) | code: Embedded Sub Format toggle at row y + 8, label centered (y + 15.5) | Figma: 2255:9846 "Frame 69" padding 10 top / 6 bottom: toggle at y + 10, label at y + 17.5 (2 px lower) | impact: low | sure: high
- **Row 74** | `modules/gui/qt/player/qml/TracksPopup.qml:223-228` (ColumnLayout spacing 0) | code: no 1 px gaps between the body frames: list frame at y 111, External Tracks label at 249.5 | Figma: frame "Subtitles" 491:2243 itemSpacing 1: Frame 53 at 112, Frame 66 at 251.5 | impact: low | sure: high
- **Row 28** | `modules/gui/qt/player/qml/QueueSidebar.qml:203` | code: queue list anchored right under the 68 px header (y 119) | Figma: 463:831 itemSpacing 1, list "Frame 53" at y 120 | impact: low | sure: high
- **Row 28** | `modules/gui/qt/player/qml/RdSidePanel.qml:106-112` | code: tab header bottom corners square | Figma: queue / bookmarks / chapters "Frame 59" (463:832) cornerRadius 2 (bottom corners 2 px round; the settings sidebar header has none) | impact: low | sure: medium

### Code matches Figma, still needs PC test

- Row 28: queue panel 400 wide, 20 px from the right edge, top bar and control bar, radius 10 opaque BG/B1; header 68 px, count Inter 14 FG/A3 at x 28, icons sort / repeat / shuffle / remove / add 24-30-30-24-24 wide 12 apart ending 20 from the right; rows 32 high 12 apart, 20 px side margins, duration FG/A3 right inset 4; drag by handle and file / library drops into the queue
- Row 29: tabs 128.67 wide, underline 112.67 Accent/Main 2 px, labels Inter 12 FG/A2 active / FG/A3, icons 20 px two-tone (FG/A3 + Accent/DIm) active / FG/A4 inactive; count wording "%1 items - %2"; title FG/A1, duration FG/A3
- Row 72: Settings > Subtitles "File name matching" choices Off / Any title / Contains title / Title with extra characters / Exact title match in Figma order (SettingsSubtitlesPage.qml:89-99)
- Row 74: tracks popup 400x524, tabs Video / Audio / Subtitles, Embedded Tracks / External Tracks (pencil, +) sections 60 px pad 28, list frames 138.5, rows check at x 4 / text x 42, footer 72 with Show Preferences bar BG/B2 r4 FG/A3
- Row 80: Add Subtitles match row (AddSubtitlesMatchRow.qml): 36 px r6, subtitle icon x 8, name x 46 FG/A1, hover BG/B2 with FG/A2 swap icon 8 from the right, click opens the per-episode list
- Row 81: Save adds the file through AddSubtitles; listing all tracks under Embedded Tracks is covered by Decision (Claude) W4.2
- Row 90: sidebar 20 px inside the video area under the top bar and above the control bar; gear button checked while the sidebar is open; page cross-fade on tab change, header switch instant
- Row 93: section headers Inter 500 16 FG/A1, padding 20/24, 39 px; labels Inter 14 FG/A3 at x 4; value boxes 140x36 r6 BG/B2 with 2 px BG/A4 inside stroke, text FG/A2 at 14; colour swatch 22x22 r2, 1.5 px #FFFFFF 21 %, 7 px from the edge
- Row 95: slider track 16 r6 BG/B2, fill 12 r4 BG/Accent Bright, thumb 8x24 r4 Accent/DIm, delay labels -10 s / 0 s / +10 s Inter 12 FG/A3, 10 px under the track
- Row 97: toggle 68x32 r6 BG/B2, highlight 33x26 r3 (BG/A4 off at x 32, BG/Accent Bright on at x 3), knob 26x26 r3 FG/A4 / Accent/DIm, ON / OFF Inter 12 FG/A3 / Accent/Main at the Figma x
- Row 101: segmented control BG/B2 r6, 2 px padding and gap, segments r4, selected BG/Accent Bright + Accent/Main, others BG/A4 + FG/A3, Inter 14; Flip 3-segment 360x44
- Row 103: Subtitles tab row order (Defaults, Synchronization, Appearance rows) as the video, apart from Size Values (see Could not check)
- Row 115: 1 px Divider/Dim between sections (none above Defaults), taking no height, no section cards
- Row 116: Defaults rows "Subtitle Track" / "Subtitle Language" with 140x36 boxes, 48 px rows, 5 px apart, 10 px bottom padding
- Row 118: delay slider bipolar (fill from 0 to the thumb), speed and duration sliders fill from the left with the thumb at the left end at their minimum
- Row 121: Test button 68x32 r4, padding 16, BG/Accent Dark + Accent/DIm text, hover BG/Accent Bright + Accent/Main
- Row 122: Audio Defaults Audio Track / Audio Language boxes, Stereo Mode 52 px label row with Test, full-width 360x48 dropdown 10 px under it
- Row 123: Audio tab icon two-tone (FG/A3 with Accent/DIm bars), Video / Audio tab underline 70
- Row 124: Audio Track Delay value box "0.000 s", bipolar slider -10 / 0 / +10 s (Figma's "-10 s" typo fixed, Decision 17)
- Row 125: Filters order Equalizer label, preset dropdown (None), Expand Settings, 2 Pass toggle, then Compressor / Spatializer / Stereo Widener blocks with dividers, Adjust Pitch "4.0 semitones" style value
- Row 126: Expand Settings bar 360x48 r6 BG/B2, text x 16 FG/A3, chevron 10 from the right; expanded BG/A3 card with "Collapse Settings" and chevron down, instant; filter blocks padding 10/20, 37 px toggle rows, 10 px gaps
- Row 127: footer pinned under the scrolling page (1 px Divider/Dim, padding 20, preset 42 + 10 + button 32), absent on Playback (Decision 39)
- Row 128: dropdown 48 px BG/B2 frame with 2 px inset BG/A4 r4 row, text x 16 FG/A2, chevron 16 from the right, hand cursor; list opens in place with BG/A4 r6 and the 35 % / y 4 / 13.8 shadow
- Row 129: Compressor card rows (37 px name row, 5, 24 px slider, 10 apart, 20 px under the last), labels RMS / Peak (typo fixed), Attack, Release, Threshold, Ratio "x : 1", Knee Radius, Makeup Gain with Figma value formats
- Row 130: filter parameter value as plain FG/A3 text right-aligned 16 px inside the card; EQ value in a 140x36 box with 12 px text
- Row 131: EQ card Preamp + 10 bands (VLC frequency names 60 Hz ... 16 KHz), 56 px rows, slider right under, 90 px per band, -20..20 dB
- Row 135: Video Defaults geometry: Flip label at 116 / segments at 153, Rotate row at 218, Zoom / HDR / Resolution / Aspect Ratio / Crop / Render dropdowns 220x48 right-aligned, 68 px apart from 286; "Best Available", "Off" display names
- Row 136: Video tab icon (accent band, FG/A3 body), Flip segmented style, 220 px dropdowns, Rotate box "0 deg"
- Row 137: Playback tab icon is the "state=selected" two-tone glyph in both states, FG/A2 + Accent/DIm active, FG/A4 inactive (Decision 39)
- Row 140: Speed row 44 px with frameless 140x32 box "1x" FG/A3, slider 0.25..2 with fill from the left
- Row 141: speed ticks 6 inner marks (7 steps), screen-blended tick colours
- Row 142: speed labels 0.25 ... 2 Inter 12 FG/A3, 14 px under the track, track 18 px under the name row
- Row 144: Sleep Timer 220x48 dropdown, 10 px above / 20 px below, choices Off / 15 / 30 / 45 / 60 min / End of current file (Decision 23)
- Row 146: Show Waveform on Seekbar toggle row 52 px (first row until the subtitle timeline toggle, Decision (Claude) W7.2)
- Row 147: Show Metadata, Show Statistics toggles, Audio Visualizer dropdown "Disabled"; missing Subtitle Timeline and Reverse rows covered by Decisions 29 and (Claude) W4.3b
- Row 248: Bookmarks tab header "%1 Bookmarks" FG/A3 with "-" / "+", "+" adds at the current time (Decision 22 / W4.8b)
- Row 249: tab glyphs queue / bookmarks / chapters with their two-tone active variants (Accent/DIm inner part), FG/A4 inactive, 2 px accent underline
- Row 250: chapter number Inter 500 14 Accent/Main, title FG/A1, time HH:MM:SS FG/A3, list 20 px under the header
- Row 333: Show Preferences opens the settings sidebar on the matching tab (Video / Audio / Subtitles), hover BG/A4 + FG/A2
- Row 334: Open Advanced Settings (plain link with 20 px gear, Decision 40) opens the Settings dialog on video / audio / subtitles
- Row 335: pencil and + both open the Add Subtitles dialog for the playing file
- Row 349: Show Statistics toggle in the Playback tab (Decision 13)

### Could not check

- Row 100: the "Size Values" Relative / Pixels row is not built in the sidebar (Figma 804:1229 Values 180x38 at y 890); deferred by Decision (Claude) W4.6, pixel size is listed under "Decisions waiting for Sticky"
- Row 111: keeping the chosen subtitle track / language for every episode depends on the preset store (W4.7) and Add Subtitles matches at runtime; the UI parts (Defaults rows, tracks popup) exist, the behaviour needs a PC test

## Library, music, playlists and mini player

### Mismatches

- **Row 226** | `modules/gui/qt/dialogs/redesign/OpenNetworkStreamDialog.qml:433` | code: the Playlist Name field (nameField) is never filled from the pasted link; it stays empty unless typed, and without a name the links just play (line 90-100) instead of becoming the "Index" stream list | Figma/row: row 226 shows "Index" filled in from the m3u file name after pasting `.../index.m3u`, Save then lands in "Network > Index" (Decision (Claude) W6.4 / P6-13 assigned this auto-fill to W5.4b; it was not built) | impact: medium | sure: high
- **Row 337** | `modules/gui/qt/medialibrary/qml/RdLibraryItemMenu.qml:83` | code: Favorite is only added when `item.isFavorite !== undefined`; playlist items never carry it (RdLibraryPage.qml:524-526 builds playlist items without isFavorite, MLPlaylistListModel has no favorite role, openForPage passes `{kind, id, title}` only), so the playlist "..." menu has no Favorite row at all | Figma: playlist-context-menu.json row 2 "Favorite" (node 2459:9392, icon favorite two-tone) between Play and Shuffle | impact: medium | sure: high
- **Row 193** | `modules/gui/qt/player/qml/QueueSidebar.qml:318` | code: every queue row, the playing one included, shows the gray "move" handle (FG/A3); only the title turns accent | Figma/row: row 193 (video 11:44-11:49) shows the playing row with an orange play glyph and orange name, the other rows the "=" handle (the mini queue does this, RdMiniQueue.qml:204) | impact: medium | sure: high
- **Row 318** | `modules/gui/qt/player/qml/QueueSidebar.qml:318` | code: same as row 193, the current item gets the move handle, not the orange play icon | Figma/row: row 318 current item "orange play icon and orange name", next item drag handle | impact: medium | sure: high
- **Row 208** | `modules/gui/qt/medialibrary/qml/RdLibraryHeader.qml:128` | code: only the page area crossfades (RdLibraryContent.qml:44-65, 180 ms); the address line is bound straight to `RdLibraryNav.location.crumbs` and the count to the new page, so both switch instantly | Figma/row: row 208 (video only) old breadcrumb and rows fade out while the new ones fade in at the same place, both overlapping | impact: medium | sure: high
- **Row 203** | `modules/gui/qt/medialibrary/qml/RdLibraryPage.qml:799` | code: song rows are media rows, `secondary` false, so an unplayed song title is FG/A1 (#969696) (RdLibraryRow.qml:111-115); only played songs (playcount > 0) get FG/A3 | Figma: sidebar.json variant music3 and player-music-1.json: all three song rows ("untangle / moonlight / black bird - juxtopposed", nodes 4778:25025, 6207:13669, 6207:13686) are FG/A3 #6B6B6B (light #6B6B6B) | impact: medium | sure: high
- **Row 204** | `modules/gui/qt/medialibrary/qml/RdLibraryPage.qml:799` | code: same as row 203, song row titles FG/A1 next to their covers | Figma: sidebar.json music3 song rows FG/A3 | impact: medium | sure: high
- **Row 207** | `modules/gui/qt/medialibrary/qml/RdLibraryHeader.qml:128` | code: breadcrumb "... > juxtopposed" replaces the old one at once (no crossfade) | Figma/row: row 207 "Breadcrumb text crossfades during navigation" | impact: low | sure: high
- **Row 233** | `modules/gui/qt/medialibrary/qml/RdLibraryRail.qml:109` | code: the pins Repeater and the "+" sit in a plain Column with no add / move transition; a new pin appears and the "+" jumps down in one frame | Figma/row: row 233 "Items animate in by sliding the "+" down" | impact: low | sure: high
- **Row 231** | `modules/gui/qt/medialibrary/qml/RdLibraryItemMenu.qml:71` | code: "Add Audio Tracks" uses `waveform_two-tone-yes` (6 bars, 2..22) | Figma: file-context-menu.json row "Add Audio Tracks" icon `audio` two-tone (I2404:13431;2107:6069, 5 bars, `audio_two-tone-yes.svg` exists unused); the folder menu "Edit Audio Tracks" (line 133) has the same swap against folder-context-menu.json `audio` two-tone | impact: low | sure: high
- **Row 338** | `modules/gui/qt/medialibrary/qml/RdLibraryItemMenu.qml:71` | code: same waveform icon on "Add Audio Tracks" in the full file menu | Figma: file-context-menu.json `audio` two-tone | impact: low | sure: high
- **Row 337** | `modules/gui/qt/medialibrary/qml/RdLibraryItemMenu.qml:94` | code: playlist menu "Add Audio Tracks" icon `waveform_two-tone-yes` | Figma: playlist-context-menu.json I2459:9400;2107:6069 icon `audio` two-tone | impact: low | sure: high
- **Row 200** | `modules/gui/qt/player/qml/RdMiniQueue.qml:204` | code: playing row icon `play` (filled rounded triangle, play.svg has fill + stroke) in accent | Figma/row: row 200 "orange OUTLINE play triangle"; the Figma playing-row glyph elsewhere (player-1.json 6841:16007) is the outline `playback` icon | impact: low | sure: high
- **Row 196** | `modules/gui/qt/medialibrary/qml/RdLibraryThumb.qml:108` | code: the playing row/card overlay glyph is `playback_two-tone-yes` (rounded-corner triangle), coloured all accent | Figma: player-1.json 6841:16007 icon `playback` (sharp 8x12 outline triangle, stroke #D37918 1.5) over the #000000 70 % + #958069 20 % thumbnail | impact: low | sure: high
- **Row 200** | `modules/gui/qt/player/qml/RdMiniQueue.qml:37` | code: `_durationText` rounds down to minutes, so a queue shorter than a minute or with zero-length items reads "1 item - 0m" (the player queue, QueueSidebar.qml:46-57, shows "45s" or the count alone) | Figma: miniplayer.json 970:3189 "4 items - 2h 3m" format; row 200 "2 items - 47m" | impact: low | sure: high
- **Row 211** | `modules/gui/qt/player/qml/Player.qml:960` | code: cover glow is RoundedRectangleShadow #FFFFFF 3 %, blur 90.5, with no spread (the component has no spread property) | Figma: player-music.json 4777:24028 drop shadow #FFFFFF 3 %, radius 90.5, offset 0, spread 64 | impact: low | sure: high
- **Row 197** | `modules/gui/qt/player/qml/RdMiniPlayer.qml:282` | code: previous and next overlay buttons have no shadow | Figma: miniplayer.json Variant3 "Frame 8" / "Frame 10" (975:4337, 975:4339) wrap previous / next with a drop shadow #000000 70 %, blur 9.52, y 4.76 (play has none) | impact: low | sure: high
- **Row 158** | `modules/gui/qt/medialibrary/qml/RdLibraryRail.qml:88` | code: the rail buttons are created all at once with no entrance animation | Figma/row: row 158 items appear one at a time, each with a short fade-in (10:16-10:22; may be the video's wand edit, no Decision covers it) | impact: low | sure: medium
- **Row 324** | `modules/gui/qt/medialibrary/qml/RdLibraryHeader.qml:204` | code: on the empty Home the full header still shows "0 items", the view button and the 325 px search field next to "..." | Figma/row: row 324 header is back, forward (dim), "Home" and "..." only (Figma Player-5 shows count, sort, view and search for a populated Home) | impact: low | sure: medium
- **Row 165** | `modules/gui/qt/medialibrary/qml/RdLibraryPage.qml:104` | code: the song sort list has Newest/Oldest, Title, Artist, Album, Track Number, URI but no Disc Number | Figma: sorting-options.json also lists "Disc Number Ascending" / "Disc Number Descending" (4693:23558, 4693:23568) | impact: low | sure: medium
- **Row 226** | `modules/gui/qt/medialibrary/qml/RdLibraryPage.qml:579` | code: stream rows (TV channels of a saved list) use the `window` icon (rectangle with a title bar) | Figma/row: row 226 describes a TV / screen icon; Figma's icon set has `tv` (screen with antenna and play); no Figma frame shows these rows | impact: low | sure: low

### Code matches Figma, still needs PC test

- Row 156: full library shell: rail 217 wide on BG/B1 with BG/A4 card (margin 8, radius 6, padding 12/16), content BG/B1, header 20 px padding, divider 17 below (Player-5)
- Row 158: compact rail 50 wide BG/A4, 30x32 wrappers at x 10, pitch 46 (padding 8, gap 14), 24 px icons, #FFFFFF 6 % hover; full-library labels Inter 14 at x 62, FG/2 at the category root, FG/A2 inside
- Row 160: back / forward 24 px FG/A2 at x 70 / 106 (12 apart), forward FG/A2 at 30 % when disabled, hand cursor; crumbs 10 after, gap 6, "▶" 8 px FG/A4, Inter 16 FG/A2, last crumb 600 FG/A1 only in the full library, "..." folding
- Row 165: compact tools: count Inter 14 FG/A3 at y 64, sort / view / search 24 px FG/A3 at x 311 / 347 / 383, "..." and open at 347 / 383; full row: count, sort, view, search 325x34 BG/A5 r6 (icon +8, text +42, "Search" FG/A4), "..." all 20 apart; sort dot 4 px accent at (22,-1); sort / view menus at offset -11, 30, 265 wide, 48 px rows, BG/A2 selected row with accent check
- Row 173: an added folder opens once the media library lists it (RdLibraryContent._tryReveal), breadcrumb with full path
- Row 174: page content crossfades (180 ms, capped by the performance rule)
- Row 175: full library grid 316 wide 16:9 cards, 20 apart, 5 columns at 1920, hand cursor, title 20 below Inter 16; Unwatched First / Watched First sorts by play count
- Row 176: card radius 12 (Figma Player-3 wins over the video's 4), base #171717, #000000 20 % layer, 4 px accent bar along the bottom only when watched or in progress, watched title FG/A3, picture not dimmed; row thumbnails 32x32 radius 2 #303030 with a 3 px bar 28 wide
- Row 177: rail icon states: category root = accent `*_state-active`, inside it = FG/A2 filled `*_state-selected`, others outline; hover per Decision (Claude) 2026-10-15
- Row 193: library rows and cards drag a semi-transparent ghost (thumbnail + name, 0.75) that both queues accept (rdDragUrls)
- Row 195: the compact header's open icon switches to the full library at the same place
- Row 196: full list view rows 406 wide, 10 apart, 4 columns at 1920, first row 30 below the divider; playing row accent title with dark shade; watched rows FG/A3 with bar; full top bar without sidebar toggle or folder chip
- Row 197: card 391x339 BG/A3 r14, shadow #000000 38 % blur 11.8; picture 375x211 r6 2 px BG/B2 border; seek 375x16 BG/B2 r6 with 12 px BG/Accent Bright fill and 8x12 accent playhead on hover; title Inter 16 FG/A1 at (16, 262); folder / artist chips at y 295; queue button 30x32 at x 345, `lists_state-active` accent while open; hover dim #000000 60 % with close, open, prev / play / next at the Figma positions
- Row 199: queue attached above the card in bottom corners (below in top ones), header 58 BG/A5 radii 14,14,2,2 with "Queue" Inter 16 FG/A2 centered; snaps to the nearest corner
- Row 200: tool icons sort, repeat, shuffle, remove, add, FG/A3, 44 px pitch ending at x 363; count Inter 14 FG/A3 at x 36 with " - " separator; rows at x 28, 32 high, 12 apart, title at x 70, duration right at 359 FG/A3
- Row 202: Videos root: accent rail icon, address "Videos", "+ Add" row (FG/A3, plus FG/A3), folder rows FG/A3 with FG/A2 folder icons, count excluding the Add row, folders in insertion order
- Row 203: compact Music > Songs > My Songs layout: folded "... ▶ Songs ▶ My Songs", "3 items", Add row, 32 px square covers, "title - artist" titles
- Row 204: song covers fill a 32x32 radius 2 box
- Row 207: artist page lists Add row and the artist's songs with the count
- Row 209: music view cover 737/1080 of the window height, radius 20 (Decision), "title - artist" Inter 500 24 FG/A1, equal gaps above the cover, between cover and caption and below the caption; compact library floats over it
- Row 211: background is the cover blurred on a square 32 px wider than the window, no tint (Decision (Claude) 2026-10-16)
- Row 227: Playlists page: "Create playlist" Add row FG/A3, playlist rows FG/A1 with `playlist` icon FG/A2 (thumbnail when set), count excludes the Add row
- Row 230: row hover turns the title FG/2 and shows "..." (FG/A2, x 313) at the row end, menu at offset -16, 34; watched rows sorted by the sort menu
- Row 231: file menu icons Play, Mark as Watched, Favorite, Stream, Convert, Add to Queue, Add to Playlist, Show in File Explorer, Go to Source, Add Subtitle Tracks, Properties are the Figma two-tone icons; rows 48 high, icon at x 18, text at x 52 Inter 14 FG/A2
- Row 233: pinned playlist = its picture 24x24 radius 4 in the wrapper, pinned folder = `folder` outline, Recent = `recent`, "+" = `add`, no circle
- Row 316: closing montage library state reproduced by the full library (rail labels incl. Recent and "Add item", header row, 5-column grid, watched last with Unwatched First)
- Row 318: playlists list rows and queue header icons / count format as in rows 200 and 227
- Row 324: empty Home shows "Watch Next" (FG/1) with a ">" link and an empty 316x177.75 radius 12 #171717 card; Home rail icon accent filled, forward arrow dimmed
- Row 325: active Home `home_state-active` accent filled, other rail icons FG/A2 outline, forward arrow FG/A2 30 % without forward history
- Row 337: playlist menu order Play, (Favorite), Shuffle, Export Playlist, Add to Queue, Add Subtitle Tracks, Add Audio Tracks, Properties & Metadata, 265 wide, 48 px rows (plus Delete Playlist per Decision (Claude))
- Row 338: file menu order and wording match file-context-menu.json, Go to Source hidden on folder pages, local-only and library-only rows hidden where they cannot work
- Row 340: drill-down Videos > Shows > The Wand > S01 / Music > Songs > My Songs; an earlier crumb or "..." goes up
- Row 341: Home sections Continue Watching, Listen Again, Frequently Visited Folders, Frequently Visited Playlists, Frequently Listened Artists, Latest Streams (Decision 8); compact: 32 px title rows Inter 16 FG/A1 with FG/A2 chevron at the edge, rows 15 below, sections 30 apart; full: Inter 20 titles with chevron 5 after, cards 20 below, 77 to the next title
- Row 342: compact library slides 208 ms (Figma "slow", ease-out per Decision (Claude) F-16), video area resized once
- Row 343: card 391x339, 391x690 with the queue (339 + 351), 6 px from the window edges, snap 300 ms ease-out, hover overlay, queue expands upward

### Could not check

- Row 158: whether the video's staggered rail fade at 10:16-10:22 is UI motion or the wand edit needs the 60 fps frames (video not available to this audit)
- Row 174: the video's roughly 1 s dim with the ghosted menu may be an editing dissolve; needs the video frames to decide
- Row 204: whether each song shows its file's own art depends on the media library's thumbnail extraction at runtime (code falls back to the #303030 box with the `music` icon)
- Row 209: window title and top bar folder chip text ("untangle", "My Songs") come from RdNowPlaying / the top bar at runtime; not traced in detail
- Row 211: the blur strength match (Dual Kawase 4 x 3 vs Figma layer blur 20) can only be judged on screenshots

## Dialogs: Settings, Keyboard Shortcuts, Open Network Stream, Add Subtitles, Customize Player, onboarding, light theme

### Mismatches

- **Row 78** | `modules/gui/qt/dialogs/redesign/addsubtitles/AddSubtitlesDialog.qml:293` | code: the source dropdown ("From Computer") is always visible next to the target dropdown, also while the target list opens by itself on dialog open (Decision 46); no fade-in | Figma/row: P3-07 and IA-26 say the second dropdown fades in to the right only after the target is chosen (Figma frames show only the end state, 1992:5562 "origin") | impact: medium | sure: high
- **Row 77** | `modules/gui/qt/dialogs/redesign/addsubtitles/AddSubtitlesDropdown.qml:52` | code: no HoverHandler / cursorShape on the dropdown trigger or on its list rows (arrow cursor; RdDropdown and RdButton elsewhere use Qt.PointingHandCursor) | Figma/row: IA-26 and P3-06 show a pointer (hand) cursor on hover of the dropdown and its options | impact: medium | sure: high
- **Row 287** | `modules/gui/qt/dialogs/redesign/settings/SettingsEqualizer.qml:188` | code: band column = slider 320, spacing 12, name item 21 (text bottom-anchored), spacing 12, value box 32: name text top about 16 px under the track, value box 45 px under it; open panel 6+24+24+397+20 = 471 high | Figma: settings-audio-1.json / eq.json "Frame 308" (spacing 33): name "Preamp" 33 px under the 320 track (track 54..374, name y 407), value box "Frame 265" 13 px under the name (y 437); panel 489 high. Names about 17 px and value boxes about 18 px too high, panel 18 px short | impact: medium | sure: high
- **Row 287** | `modules/gui/qt/dialogs/redesign/settings/SettingsEqualizer.qml:44` | code: the panel is BG/A4 (dark #191919 / light #B3B3B3) in both states | Figma: eq.json variant "Default" (closed, "Open Equalizer") is BG/B2 (#090909 / #DEDEDE), only "Variant2" (open) is BG/A4 | impact: medium | sure: high
- **Row 286** | `modules/gui/qt/dialogs/redesign/settings/pages/SettingsAudioPage.qml:528` | code: Advanced Options has 4 rows (Pass compressed audio, Detect Dolby Surround, Resampling quality, Media role); no "Visualization size" row anywhere in the dialog (grep finds none) | Figma: settings-audio-1.json Advanced Options 5th row "Visualization size (i) [dropdown: Match window]" (y 1563) | impact: medium | sure: high
- **Row 287** | `modules/gui/qt/dialogs/redesign/settings/SettingsEqualizer.qml:271` | code: band value box = RdValueBox default font 14 px (VLCStyle.rd_fontSize_label), padding 6 each side in 60 px: "12.0 dB" at 14 px is about 50 px wide in a 48 px text area (may elide) | Figma: eq.json "12.0 dB" / "0.0 dB" Inter 400 12 / 14.52 FG/A2, centered in the 60x32 box | impact: medium | sure: medium
- **Row 287** | `modules/gui/qt/dialogs/redesign/settings/SettingsEqualizer.qml:106` | code: "Close Equalizer" shows chevron_direction-up when open, down when closed | Figma: both "Open Equalizer" and "Close Equalizer" use the chevron component 71:868 (direction down); row P8-44 describes "Close Equalizer v" | impact: low | sure: high
- **Row 285** | `modules/gui/qt/dialogs/redesign/settings/pages/SettingsVideoPage.qml:274` | code: Video Advanced Options = Custom aspect ratios, Custom crop ratios, Monitor pixel aspect ratio (time-shift size only on the Playback page) | Figma: settings-video-1.json Advanced Options 4th row "Time-shift buffer size (i) [Medium]" (y 1570); probably deliberate de-duplication per P7-15, but no Decision line covers it | impact: low | sure: high
- **Row 262** | `modules/gui/qt/dialogs/redesign/settings/pages/SettingsPrivacyPage.qml:96` | code: extra row "Ask about internet access when VLC starts" (qt-privacy-ask) in Privacy > Network | Figma: settings-privacy.json Network section = Fetch titles and cover art, Submit played tracks to last.fm, Last.fm username, (password), Last.fm submission URL; the 2026-10-15 Decision (Claude) lists only the Last.fm password, web remote password and restart notes as rows kept beyond Figma | impact: low | sure: high
- **Row 262** | `modules/gui/qt/dialogs/redesign/settings/pages/SettingsSubtitlesPage.qml:323` | code: On-Screen Messages has no "Show feedback for" slider; Subtitles Advanced has no "Ignore styling in ASS and SSA subtitles"; General Advanced has no "Additional command line options" | Figma: settings-subtitles.json "Show feedback for" (0.5 s .. 5 s, y 1409-1438), settings-subtitles-1.json Advanced row 2, settings-global-1.json Advanced row 2. Known and tracked (SETTINGS_NOTES section 6, rows S2-01 / S2-11, core changes) | impact: low | sure: high
- **Row 225** | `modules/gui/qt/dialogs/redesign/OpenNetworkStreamDialog.qml:263` | code: close icon turns FG/2 on hover (same in `addsubtitles/AddSubtitlesDialog.qml:253`); Keyboard Shortcuts and Settings keep FG/A2 | Figma: icon-wrapper.json variant "hover" only adds the #FFFFFF 6 % fill, the icon is unchanged | impact: low | sure: high
- **Row 224** | `modules/gui/qt/dialogs/redesign/OpenNetworkStreamDialog.qml:394` | code: 1 px divider rectangle at 364..365, so "Playlist Name (optional)" starts at y 385, its hint at 418 and the name field at 465 | Figma: open-network-stream.json 6251:13901 at y 384, 6251:13902 at 417, field 6251:13904 at 464 (divider is a 0 height centered stroke) | impact: low | sure: high
- **Row 348** | `modules/gui/qt/dialogs/toolbar/qml/CustomizePalette.qml:71` | code: palette `displaced` and zone `move` (CustomizeZone.qml:179) NumberAnimation 50 ms with default Linear easing | Figma: "seekbar" 2115:7285 and the palette items: SMART_ANIMATE 50 ms EASE_IN_AND_OUT | impact: low | sure: high
- **Row 287** | `modules/gui/qt/dialogs/redesign/settings/SettingsEqualizer.qml:271` | code: RdValueBox `framed` defaults to true: 2 px BG/A4 border around each value box | Figma: "Frame 265" (I3180:17553;3178:16868) fill BG/B2, no stroke | impact: low | sure: medium
- **Row 352** | `modules/gui/qt/dialogs/redesign/settings/pages/SettingsInterfacePage.qml:185` | code: "Popup duration" slider from 0 to 10 s in 0.5 s steps, but qt.cpp:431 declares qt-notification-duration 1000..10000 ms: the 0 s and 0.5 s positions are stored as 1 s, so the thumb snaps back | Figma: settings-interface.json (3062:11379) slider labelled 0 s / 5 s / 10s; row S2-03 proposes 1-10 s | impact: low | sure: medium
- **Row 259** | `modules/gui/qt/dialogs/redesign/KeyboardShortcutsDialog.qml:497` | code: "Global Hotkey" centered over its 270 px field (text x about 846.5); "Hotkey" centered over its field (x about 511) | Figma: keyboard-shortcuts.json 6338:13888 "Global Hotkey" at x 840 (auto width 93), 6338:13886 "Hotkey" text starts at x 508 | impact: low | sure: medium

### Code matches Figma, still needs PC test

- Row 75: Add Subtitles frame 1048x800, header 96 BG/B2 radius 14/0, title Inter 14 FG/A2 at 19, close 32 at 9 px, controls row y 53 (200 / 200 / 610, gaps 10; search 400 + language 200 in OpenSubtitles mode), list rows 40 px from y 118, match box at x 539 w 489 r 6, hover BG/B2 + swap icon, dashed 8/8 Divider/Bright leader, footer Cancel / Save, opaque body (no dim, Decision 41)
- Row 76: tracks popup External Tracks "+" calls AddSubtitles.open(); dialog hosted by MainInterface (AddSubtitlesHost), centered, Cancel left / Save right
- Row 77: target list order To This File / To This Folder / To This Playlist, opens on dialog open (Decision 46), list opens in place (current row over the field), 209 wide, 48 px rows, selected BG/A3 with accent check, BG/A4 list with 35 % shadow (Figma "target" dropdown 1/2)
- Row 78: source list order From Computer / From OpenSubtitles / From Link... (Decision 17)
- Row 79: OpenSubtitles mode shows search field (search icon, FG/A1) 400 wide and language dropdown 200 wide at x 839; folder mode shows folder icon + path field 610 wide; auto-matched list per video
- Row 336: "To This File" rows (subtitle one): 36 high, padding 8, icon FG/A3, 14 gap, FG/A1 name, selected BG/B2 + accent check, several selectable, hover BG/B2 without check (Decision Claude W6.5)
- Row 222: Open Network Stream opens its own QML dialog through DialogsProvider::showOpenNetworkStreamDialog; other entries per Decision (Claude) W6.4
- Row 224: frame 1048x631 (471 without media library), header 50, wording of all labels, hints and placeholders, URL box 194 BG/B2 2 px BG/A4 stroke r 6 with text inset 14/10, Save disabled until a link is typed, Ctrl+Enter / Enter save, no dim, instant (Decision 32)
- Row 225: section titles Inter 16 FG/2, hints 14 FG/A3, "(optional)" FG/A3 (Figma character override #6B6B6B), placeholders FG/A4, Cancel 100x32 BG/A3 600 FG/A2, disabled Save per Decision (Claude) W6.4; New Playlist (RdLibraryDialog / RdPlaylistDialog) header, 713 width, section, field and thumbnail picker positions match new-playlist.json
- Row 258: Keyboard Shortcuts 1048x800, header 96 BG/B2, search 820x34 BG/A5 at 9,53 with icon and placeholder "Search Keyboard Shortcuts...", "All Fields" dropdown 200x34 at 839 with chevron 8 from the edge, groups Basic / Playback with the video's labels and order, Cancel / Save (disabled until changes)
- Row 259: column titles y 116 FG/A3 14, divider y 161, group headers 16 FG/A1 at y 181 / 448, rows every 47 from y 229, key fields 270x33 BG/B2 r 6 at x 399 and 758, DM Mono 14 FG/2 centered (bundled, rdfonts.cpp), edit icon 5 from the right
- Row 262: every page = basic sections then the "Advanced Options" bar (784x38, r 2, BG/A3 Transparent, text + chevron centered) then advanced sections on the same scrolling page; no Simple / All toggle; row order and wording checked on Interface, Playback, Video, Audio, Library, Privacy, Controls, Network, Performance, Recording, Subtitles, General, Extensions (Extensions words per Decision Claude)
- Row 263: VLC options all reachable through "All Other Options" per page; Figma's duplicated Remotes wheel rows not repeated; values in words
- Row 276: palette dark and light values equal the token table (light FG/1 #111111, FG/2 #222222, FG/A4 #8A8A8A per Decisions 33 / 44; transparent alphas 0.95 / 0.75 / 0.8); Theme row Dark / Light / System (RdSegmented) switches MainCtx.colorScheme
- Row 277: SystemPalette.switching + DelayedBehavior keep color animations off during a theme or accent switch
- Row 278: light control bar BG/A3 Transparent made opaque with a 1 px Divider/Dim top line (Figma "Player - Light" Controls stroke), top bar BG/A3 Transparent, play pill Accent/Main, volume BG/A5 / #FFFFFF 20 % tint (Decision Claude W8.4)
- Row 284: Playback page rows, order, controls and default labels match settings-playback / -1 (speed slider 0.25..2 with 0.25 labels; Repeat Off / All / One; default tracks as dropdowns per Decision Claude)
- Row 285: Video page Output / Picture (five sliders + Reset, BG/A4 Plain button) / Deinterlacing / Framing / Snapshots rows and order match settings-video
- Row 286: Audio page basic rows and order match settings-audio (Night mode between Target level and Replay gain)
- Row 287: equalizer bands 60 wide, 8 apart, centered (first at x 262), track 16x320 r 6 BG/B2, BG/Accent Bright fill from the bottom, 24x8 r 4 Accent/DIm thumb, names FG/A3 14, header text + chevron centered at y 9.5
- Row 290: Settings header and category column stay fixed; the page Flickable scrolls in the right pane and ends with the Advanced Options bar
- Row 292: Library page rows, order, dropdown words, dependent rows dimmed to 30 % while "Only allow one VLC window" is off
- Row 302: Customize box 1048 wide, header 94 BG/B2 (title 14 FG/A2 at 19,16.5; description 14 FG/A3 at 19,60.5, exact wording), body padding 34, items 86 wide, columns 110 apart, rows 120 apart, labels 16 under the outline, Cancel / Save (disabled until a change); title row per Decision 53, footer switcher per Decision 62
- Row 303: palette order and Figma icon per item (speed, forward/backward-10-sec, forward/backward-15-sec, stop, repeat/shuffle right, record, snapshot, hdr, zoom, sidebar right, quit, settings, home, thumbnail, info x5, replay, chapters, favorite, bookmark, bookmarks, playlist); outline sizes 24x32 / 32x32 / 28x28 / 30x32 as Figma; all SVGs present
- Row 304: bars drawn by the dialog with every control in a 1 px FG/A3 4/4 dashed outline (RdDashedFrame shader), top bar editable (CustomizeTopBar), live bars follow edits
- Row 305: dragged tile keeps dashed square and label under the cursor, palette items shift into the gap, Save turns accent after the first change
- Row 306: a non-empty center zone moves the seek row to its own row with times left and right (ControlBar._seekRowOnOwnRow), as customize-7/-8
- Row 307: left-zone items "...", sidebar toggle, divider, folder chip, title, favorite exist as movable controls with Figma icons (more, sidebar left, divider, folder, favorite)
- Row 311: welcome card 1090x759 BG/B1 r 14 with 38 % y 4 blur 11.8 shadow, logo 141 at y 116, title 300 32 FG/1 at y 286, paragraph 300 16/28 FG/A1 at 248,362 w 595, folder label, field 471x36 and Browse 114x35 (400 16), Next 100x32 at 928,671 (600 16 FG/B1 on Accent/Main)
- Row 312: screens switch instantly, keycaps 42 high r 12 BG/A3 3 px Divider/Bright with #5C5C5C 25 % 6 px shadow, theme tile 4 px accent ring outside, selected swatch 4 px ring at 30 %
- Row 313: title 300 24 FG/A1 at y 173, tiles 116 at y 286 40 apart (#AFAFAF / #222222 / split), labels 300 16 FG/A2, 9 swatches 40 px every 80 from x 53 y 667, unselected at 50 %, Back 820 / Next 928, live preview (OnboardingPreview)
- Row 314: title 400 24 at y 60, two blocks from x 62 / 605, rows every 82, key padding 23 (15 for symbols), 4 px between keys, "/" 10 px each side, footer "Find the full list in the menu." 16 FG/A3, Back / Finish; key set per Decision (Claude) W8.3 P8-31
- Row 322: theme / accent switching and customize drag covered by rows 276, 277, 302-307
- Row 346: VLCStyle.rd_accentOptions = #D37918, #E15032, #C49E23, #19A234, #18AAD3, #185DD3, #8E42FF, #F052B3, #AFAFAF in the Figma dot order
- Row 348: drag shift duration 50 ms (rd_customizeDragDuration); 600 ms Favorite drop not used per Decision (Claude) W8.1a
- Row 351: qt-remember-window (default on) between "Resize window to fit video" and "Keep window above"; off removes the saved geometry on start and on close (interface_window_handler.cpp:74, :184)
- Row 352: qt-notification-duration row under "Show a popup when the track changes", dimmed while it is Never, own tray popup per Decision 34 (systray.cpp)
- Row 353: qt-history-filter text row between "Remember the playback position" and "Clear history now", applied on VLC_ML_EVENT_HISTORY_CHANGED (medialib.cpp:497)
- Row 354: qt-video-double-click dropdown Toggle fullscreen / Play / Pause / Nothing between single click and scroll wheel; single click row disabled when double click plays (Decision 37), MainCtx handles the action
- Row 355: Night mode toggle with the compressor preset, between Target level and Replay gain
- Row 356: Process priority dropdown Lowest / Low / Normal / High / Highest (Decision 35) after "Give VLC high priority"
- Row 357: Rescan plugins full width 320x32 Plain (BG/A4) button "Rescan", restart notice and "Restart now"
- Row 358: Encoder (sout-transcode-venc) first Developer row above Decoder, Automatic first
- Row 359: Discover cast devices toggle above Cast quality, read by MainCtx into RendererManager.setBackgroundDiscovery
- Row 361: Fullscreen controls sensitivity slider Low / Medium / High (16 / 40 / 96 dp) last Interface Advanced row, writes MainCtx.fsSensitivity, read by Player.qml _barHoverZone

### Could not check

- Row 305: drag ghost motion and live re-layout smoothness depend on runtime drag behaviour (PC test)
- Row 312: shortcut keycap labels come from the user's configuration at runtime (helper.keycaps); exact widths only checkable on the build

