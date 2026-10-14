# STATUS

- Updated: 2026-10-14 19:05 Central Europe Daylight Time
- Current work package: Sunday plan steps 4-6 in parallel (library integration, Step 1 W8.1a / W8.3 / W8.4), build 38600975461 running

## Last 10 commits
```
24d799428f Merge the perf harness fix: valid motion measurement
c71b82efb4 redesign: Decision 33: light FG/1 #111111, FG/2 #222222
6025232911 redesign: PERF.md: round 1 motion invalid, new motion method
9fa5d68152 redesign: perf harness: valid motion measurement
37d1627e9b redesign: current phase: queue drag ghost per IB-15
2a6d81b939 qt: effects: the equalizer preset follows the equalizer toggle at once
0da8e15633 redesign: current phase after round 1 and the two performance merges
94a35ce7b0 Merge lazy panels and the redesign queue list
3041cac057 redesign: performance round 1 in PERF.md, status
cbb2f4c2f5 Merge the event-driven cursor and render-cost branch
```

## Latest report
```
PROGRESS REPORT (2026-10-14)
- Round 1 (PERF.md): open file ~+300 ms vs stock (stop-everything; lazy panels now merged, re-measure). The round 1 motion, panel-open CPU and queue RAM rows were invalid: the harness drove VLC's console window. Harness fixed (24d799428f): main window by class, --rc-quiet, 4 ms input pacing with QPC log, sync square, ms timestamps, no pointer in the capture. Round 2 needs a moment when VLC can take the foreground (the guard refused while Sticky was active).
- Merged and pushed: event-driven cursor (cbb2f4c2f5), lazy panels + RdListView lists (94a35ce7b0, review fixes included). Build 38600975461 running.
- Local, not pushed yet: equalizer preset cache fix (2a6d81b939), Decision 33 (light FG/1 #111111, FG/2 #222222).
- Verified on build 38595146574: Customize Player opens again (stock editor until W8.1a), main menu opaque over video.
- Agents running: library integration (merge current redesign + 20 review findings, 1 high: Add to Playlist submenu empty), W8.1a Customize Player restyle, W8.3 onboarding, W8.4 light theme.
- Waiting for Sticky: redesign-settings push; decisions on Hide UI 300 ms, subtitle size, DM Mono.
```
