# STATUS

- Updated: 2026-10-15 night. Build of the merged batch running (see Builds).

## In the build now (redesign, one push)
- W3.3b seek preview thumbnails (review fixes M1/M2 + LOWs)
- Step 2 Settings rows S2-02..S2-10 + own tray popup (HIGH double-click fix); night mode ready for Sticky's listening test (Decision 38)
- UX leftovers: right-click on the seek bar opens the menu, focus returns to panel buttons, queue Delete only with focus
- W5.2 folder-based Videos / Music categories (Add row, picker start folder, insertion order, system folders per category)
- W4.3b Playback tab: Sleep Timer, Show Metadata, Show Statistics; W4.8b Ctrl+B and Bookmarks +/- (works on a first-played file)
- W6.5 Add Subtitles dialog (web session) with hookups: tracks popup +/pencil, library file / playlist / folder menus, Settings > Subtitles OpenSubtitles section
- Seek-to-start fix (already green in 38751114133), landing page README
- First CI compile for all their C++ (never compiled before): watch the run, fix compile errors first.

## Queue after the session limit resets (Sticky, 2026-10-15 evening; no new agents before)
0. Running at the stop: brand-layer agent (wip/brand-layer: vlc / public profiles, approved Cone logo files, Decision (Sticky)). When it reports: build once with profile=public (workflow_dispatch on that branch), real onboarding screenshot vs Sticky's mockup, then switch the workflow default to "public" and record it as a Decision (Sticky). Push wip/next-batch to redesign as soon as the current build (38796545519, link fix) is green.
1. Customize Player extras and profiles (redesign-customize, draft PR #6, CUSTOMIZE_NOTES.md). Privacy already checked 2026-10-15: privacycheck 0 problems, commit metadata clean (only Claude noreply). Apply its hookup patch with git apply -3 only AFTER the brand layer is merged (it edits TopBar.qml, mainui.cpp, MainInterface.qml, Player.qml); the top bar must use the brand logo slot, not the hardcoded cone. Review, add its decisions to VIDEO_INDEX, measure the frame time when switching profiles (PERF.md), merge into the next batch, close PR #6. Sticky accepts its three choices: top bar right zone between maximize and close; Rename and Delete Profile as rows under "+ New"; Figma's title row in Customize Player (record as Decisions (Sticky)).
2. One agent for the HIGH library bugs (Add Folder picker cancel crash, wrong folder contents after a scan, New Playlist dialog see-through and under the control bar), on wip/fix-library from wip/next-batch (merge the old partial WIP on that branch, fast-forward, no force), never touching files the brand layer changed (list: Onboarding*, Settings pages, mainui.cpp, mainctx.cpp, MainDisplay.qml, NoMedialibHome.qml, TopBar.qml, Player.qml, BannerCone.qml, systray.cpp, help.cpp, qt.cpp, build files; if a fix needs one, note it for after the brand merge). Medium / low library bugs only in the same files. No PC tests, nothing marked verified. Independent review by a fresh agent, merge into the next batch only after a green build; list fixed / left here.

## Next, in order
1. When the build is green: hands-on test on the PC (test lists in BUILD_NOTES per package and ADDSUBS_NOTES section 9), left-edge seek drag, screenshots vs Figma; build screenshots for the README gallery and hero.
2. Endless sliders (Decision (Sticky), approved mockup): coded by an agent on wip/endless-sliders; then independent review, merge, next build.
3. Verification round bugs of 38727073546 (BUILD_NOTES "2026-10-15 verification round"): 5 HIGH (Add Folder picker crash, flattened folder listings, stock music player view, New Playlist dialog, bookmarks: fixed by W4.8b), 13 MED, 17 LOW. Partial unreviewed work on wip/fix-library and wip/fix-panels (agents cut off by the session limit); restart the three fix packages (library, music player + mini player, panels / settings / Customize) from the new redesign.
4. Open from reviews: right-click on the play button / volume widget opens no menu; external subtitle tracks listed apart (P3-10, track model); OpenSubtitles needs Sticky's API key for a real test; Add Subtitles target list could open by itself as in the video (question for Sticky).
5. Core build (Decision 27): subtitle rate change flushes only the subtitle slave, own build. Then the rest of Step 2 (BUILD_PLAN section 0): per-show presets, subtitle timeline, waveform seek bar, OSD shortcut, profiles, new Customize controls, release.
6. PERF round 4: redesign motion captures with Sticky away.

## Last 10 commits
```
86d4e4df8f redesign: tests run from one fixed folder (builds/current) so the firewall asks once
9232549dce qt: light FG/A4 #8A8A8A (Decision 44)
20a212905c redesign: log hands-on findings on the light theme build
52f968b189 qt: no dim behind any dialog (Decision 41: as in the video and Figma)
229f40238c Merge visual audit fixes: sidebar pages, row widgets, volume cone, tabs, opaque tooltips (Decisions 39, 40, 43)
04f38a96f5 Merge redesign (settings integration) into the visual audit fixes
a66c6eec71 Merge the Settings dialog category pages (W6.2) with integration and review fixes
499558cbeb redesign: log the W6.2 review fixes
3f399ca9ec qt: settings: note why Maximum volume keeps the Figma range
87dedd7731 qt: MainCtx saves the accent and fullscreen sensitivity soon after a change
```

## Builds
- Latest green: 38727073546 (everything up to the no-dim change: library, settings pages, UX pass, onboarding, Customize Player, stall fixes, control bar, light theme, DM Mono). Hands-on tested 2026-10-15 (see BUILD_NOTES).
- Local and pushed after it: Decision 44 (light FG/A4 #8A8A8A), fixed test folder (launcher), docs. Pushing redesign starts the next build.
- Tests run from <TEST_MEDIA_DIR>/builds/current (firewall allowed once). Session helper vlctest.ps1 in the scratchpad has deploy / start current / dblclick / wheel / drag / graceful stop.

## Hands-on results of 38727073546
- Works: bars and 3 s fade, click outside closes panels (video keeps playing), Escape order, opaque tracks popup header and bar, right-click menu on the video, double-click fullscreen both ways, wheel volume, small window (no overlap), library compact, settings dialog pages, no dim behind dialogs, Customize Player overlay, Keyboard Shortcuts, onboarding (with --qt-privacy-ask), subtitle delay/speed drags do not freeze the video (frame difference measured on <TEST_MOVIE> and the test video), settings sidebar tabs match Figma closely (Q1 no footer on Playback).
- Bugs (sent to the UX agent, partly fixed on wip/a84f3cfa07ac47ba6): None + Track both checked in the subtitle list; tracks popup with 16 tracks grows past the window and clips its footer; "Disable" / "Best available" wording; right-click on the seek bar opens nothing; Ctrl+P with the main menu open leaves the menu open.
- Not bugs: --start-time ignored (stock VLC 4 does the same); the "closed abruptly" prompt after forced closes.

## Performance round 3 (perfruns/r3, back to back)
- Startup stock 927/1062/1112 ms vs redesign 1031/981/921: equal. Open file stock 1256/1130/1339 vs redesign 1671/1258/1230: equal except one slow first open. Playing CPU 0.1 % / RAM 310 vs 309 MB: equal. 4K fullscreen lost frames 23 vs 23: equal. Queue scroll p95 24 vs 20 ms.
- Redesign motion scenarios skipped (VLC lost the foreground); rerun when Sticky is away. Write into PERF.md.

## Open branches (all backed up on origin as wip/<id>, none merged)
1. wip/a84f3cfa07ac47ba6 UX leftovers: done except bug 4 (right-click on the seek bar: SliderBar.qml tap/drag handlers block the bar's right-click handler, Player.qml ~2042). Includes a C++ change (DialogsProvider dialogOpening signal, never compiled). Needs an independent review, then merge.
2. wip/a1e06ae1c89fa4775 W3.3b seek preview thumbnails: done, reviewed. Fix before merging: M1 (cancelled request clears the wanted bucket, rd_seek_thumbnailer.cpp:492-498: clear m_wanted only for non-cancelled results), M2 (length change resets cache and stops preview, :238 and :288-295: keep item/cache on same URI), LOWs L1-L9 in the review (stale threshold 600-1000 ms, re-check on throttle tick, timeouts count double, one image_handler per thread, setSupported(false) when the preparser fails, stop on SliderBar destruction, notes wording).
3. wip/a9364ffaea8630df4 Step 2 Settings rows S2-02..S2-10 and S2-03 (own tray popup): done, NOT reviewed. Needs an independent review (C++ never compiled), then merge and build. Night mode is ready for Sticky's listening test once built (Decision 38).

## Next, in order
1. Finish and merge the UX leftovers branch; fix M1/M2 (+ LOWs) on the seek thumbnail branch and merge; review and merge the Settings rows branch; one build; hands-on test with real screenshots vs Figma; perf motion rerun; PERF.md round 3.
2. Core build (Decision 27): 3553e146bc (subtitle rate change flushes only the subtitle slave) and later S2-01 / S2-11.
3. Remaining Step 2 items (BUILD_PLAN section 0).

## Rules added this session (see CLAUDE.md)
Max 4 agents in total, no sub-agents; UX pass on every package; identical to Figma, verified only by real-build screenshots; decision questions with side-by-side images in <TEST_MEDIA_DIR>/decisions; component motion from Figma/video; build list checker before pushes; fixed test folder; test media rules; never delete outside project paths.
