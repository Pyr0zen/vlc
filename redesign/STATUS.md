# STATUS

- Updated: 2026-10-14 18:05 Central Europe Daylight Time
- Current work package: Sunday plan step 3: performance round

## Last 10 commits
```
a2d7d5ef7c qt: popups opaque over the video; upstream Controls types resolvable again
793f020c00 redesign: the Settings pages go to a web session on redesign-settings
1658f7a60a redesign: settings segments of the video at 2 frames per second
b452aac214 redesign: wrap-up until Sunday: test launcher, TESTING.md, bug report template, status
a5f3c22804 qt: toolbar editor: resolve the Controls types again (Customize Player)
450f6b27db Merge performance: RdEffects per-key cache, coalesced applies, background save, async resume lookup
ab35ba4497 redesign: Decision 32: instant dialogs, menus keep the measured 120 ms fade
ed081a02f9 qt: dialogs open and close instantly (Decision 32)
4bd46e40c3 redesign: compile shaders locally with Qt 6.8.3 qsb before pushing
f15f455af6 redesign: current phase for the menus and dialogs build
```

## Latest report
```
PROGRESS REPORT (2026-10-14, Sunday plan started early)
- Done: settings frames for the web session (redesign/reference/frames_settings, 506 frames, pushed); redesign-settings arrangement in CLAUDE.md.
- Plan step 1 (bug issues): none open.
- Plan step 2 (test final build 38441433330): done. Figma side-by-sides match for menu, Settings, Keyboard Shortcuts, Open Network Stream. Fixed locally (a2d7d5ef7c, not pushed yet): opaque popup bodies; Customize Player and five more upstream files with a missing Controls import; qmlcheck no longer hides that class of error. Flip does not mirror the picture, but stock VLC 4 behaves the same (upstream limitation, logged).
- Next: plan step 3, the performance round (stock 38315049322 vs redesign) into PERF.md; then redesign-library; then the two unmerged performance branches; then Step 1.
- Waiting for Sticky: redesign-settings push (web session).
```
