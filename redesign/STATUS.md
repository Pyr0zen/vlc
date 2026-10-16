# STATUS

- Updated: 2026-10-16 (session near its limit: start nothing new until the reset; Sticky, 79 % session / 69 % week)

## Branch state (Decision 55: redesign only receives verified code)
- redesign = last verified state + docs: the unverified batch was reverted (725377056e5, [skip ci]); CLAUDE.md has Decision 55 / 58 and the StickyGonzales public-name rule.
- wip/next-batch = the batch under test: waveform full/sampled rule + Ctrl+B notification + bookmark titles, library fixes (Add Folder crash, folder contents after a scan, New Playlist dialog, narrow header, grid 5/4), Customize Player + profiles (Decisions 51-53), mouse wheel fine-tuning (Decision 54) + wheel never acts over the bars (Decision 54 updated), music player view + mini player. Test build of the first part: 38829058873 (= b525e444d84, before music / wheel-bars).
- wip/fix-panels-2 = panels / Settings fixes; its independent review was running at the stop: merge into wip/next-batch only after the review is clean.
- wip/cone-release (PR #7) = Cone release gaps (core change src/win32/dirs.c): review agent running (privacy, Decisions 56 / 57 / 58, StickyGonzales, portable settings copy into portable\Cone). Then its own manual build; installer side-by-side test BLOCKED: Windows Sandbox is not available (Windows 10 Home): Sticky decides (VM / other PC / Windows Pro), never install on his real Windows.
- wip/ci-release (PR #8, on top of cone-release): privacy check + safe tests after the reset: two manual build-windows runs with brand public (compare build times, cache hit rate), and one release-workflow run that must refuse. Merge order: cone-release, then ci-release, each only after it passes.

## After the reset, in order
1. Verification sweep on build 38829058873 (download it when green, then wait): by screen, highest risk first: Customize + profiles (profile-switch frame time), library fixes, waveform (large files, AVI without index, no-audio file), Ctrl+B message and bookmark titles, mouse wheel, presets switching between shows. Mark rows verified only after Figma + video; log failures; keep a verified / coded-unverified count here.
2. Fixes for failures on wip/next-batch (+ panels after review), manual build of wip/next-batch, retest; when it passes: revert the revert on redesign, merge wip/next-batch, tell Sticky.
3. Cone release: manual build of wip/cone-release, test the portable build; ci-release tests; merges only after they pass; close PR #7 / #8 after merging.
4. README with StickyGonzales on the next verified merge.
5. Proposed core change for Sticky's approval: aout_PrepareStereoMode drops the requested stereo mode on output restart (src/audio_output/output.c).

## Checks only Sticky can do
Night mode listening test; Cone tray icon (Windows hidden icons); installer side-by-side test (needs a VM / other PC / Windows Pro); OpenSubtitles with his API key; Rescan plugins from Program Files (admin prompt, needs the installer); display scaling 100 / 150 %; touchpad feel of the wheel; firewall prompts for new exe paths. Open questions: speaker-button wheel now sets the volume and the speed button no longer reacts to the wheel (Decision 54 follow-ups): keep or revert?

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
