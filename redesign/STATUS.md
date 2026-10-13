# STATUS

- Updated: 2026-10-13 19:46 Central Europe Daylight Time
- Current work package: Paused until Sunday: final build pushed, see Current phase in CLAUDE.md

## Last 10 commits
```
a5f3c22804 qt: toolbar editor: resolve the Controls types again (Customize Player)
450f6b27db Merge performance: RdEffects per-key cache, coalesced applies, background save, async resume lookup
ab35ba4497 redesign: Decision 32: instant dialogs, menus keep the measured 120 ms fade
ed081a02f9 qt: dialogs open and close instantly (Decision 32)
4bd46e40c3 redesign: compile shaders locally with Qt 6.8.3 qsb before pushing
f15f455af6 redesign: current phase for the menus and dialogs build
889e920d76 redesign: status and current phase for the menus and dialogs build
f8c464b632 redesign: notes for the menus and dialogs build round
824a6f3456 qt: Keyboard Shortcuts dialog hosted over every view, opens within a frame
84fa462232 redesign: BUILD_NOTES: RdEffects cache and the resume lookup
```

## Latest report
```
PROGRESS REPORT (2026-10-13, paused until Sunday)
- Verified on this PC (run 38435859498, focused test): main menu, right-click menu, Hide UI / Show UI, Settings dialog, Keyboard Shortcuts, Open Network Stream, restyled Open Disc, settings and queue sidebars, play/pause, seek, volume, mute, fullscreen, clean exit. One bug found and fixed: Customize Player (VLC's toolbar editor) did not load (upstream missing Controls import). Not yet done for this round: Figma/video side-by-sides.
- Merged but not tested yet (final build pushed this evening, newest run on redesign): instant dialogs (Decision 32), RdEffects performance branch (per-key cache, one apply per frame, background config save, async resume lookup) with two review fixes, popup key handover fixes, Keyboard Shortcuts hosted over every view and preloaded, toolbar editor fix.
- Unmerged, for Sunday: event-driven cursor branch (review not clean: would break the right-click menu, hover over the video not tracked; known fixes, needs a PC test); lazy panels + lazy queue branch (finished, review stopped at the wrap-up). Phase 5 branch redesign-library (web session, draft PR #1) not merged or built.
- For Tony: launcher "Test VLC Redesign.bat" on the Desktop (downloads and starts the newest successful build in portable mode), guide redesign/TESTING.md, bug report template on GitHub Issues (now enabled). A Windows firewall prompt may appear for the test vlc.exe: Cancel is fine.
- Sunday order: (1) open GitHub issues labeled bug: fix and close; (2) test the final build incl. side-by-sides; (3) first performance round (stock vs redesign) into PERF.md; (4) review, merge, build and test redesign-library (shared-file changes from its LIBRARY_NOTES.md section 5); (5) the two unmerged performance branches; (6) continue Step 1 (W6.2, W8.1a, W8.3, W8.4).
- Decisions waiting for Tony: Hide UI 300 ms (Figma) vs the 150-200 ms cap; Light FG/1 #111111 and FG/2 #222222; pixel subtitle size / live subtitle style need core changes; DM Mono font for the shortcut fields.
- Core changes so far: none. Blocked on: nothing.
```
