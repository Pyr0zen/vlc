# STATUS

- Updated: 2026-10-14 18:42 Central Europe Daylight Time
- Current work package: Sunday plan step 3 (performance round 1 done) and step 4 (redesign-library, agents running)

## Last 10 commits
```
cbb2f4c2f5 Merge the event-driven cursor and render-cost branch
86d57b2155 redesign: rule: never delete anything outside project-created paths
eb54ec0427 qt: video frame: the original border, split into two moving halves
1b59a7cb77 qt: player cursor: a hover handler on the video surface
9f50ed4170 Merge redesign into the event-driven cursor branch
2593350797 qt: no top line on the control bar (not in Figma); rule: tests anytime, close everything after
d8c80e720f qt: top bar spacing as in Figma
e0cc6dd1f3 qt: control bar spacing and time labels as in Figma
c674ac4f32 redesign: on-PC tests continue while Tony works; close test windows after each test
10b542199c redesign: ask before using Tony's mouse and keyboard; perf harness input guard
```

## Latest report
```
PROGRESS REPORT (2026-10-14)
- Steps 1-2 done (no bug issues; build 38441433330 tested; fixes in a2d7d5ef7c).
- Step 3, performance round 1: numbers in redesign/PERF.md "Rounds". Open file to first frame is about +300 ms slower than stock (stop-everything; expected fix: lazy panels branch). CPU/RAM/GPU close to stock; 4K fullscreen lost frames and the motion method need a clean re-run (a harness fix is in progress offline).
- Figma detail fixes pushed: control bar gaps and time labels (e0cc6dd1f3), top bar spacing (d8c80e720f), no top line on the control bar (2593350797).
- Merged: event-driven cursor branch (cbb2f4c2f5): no 100 ms cursor poll, video frame as two fixed halves, no hidden acrylic under the top bar.
- Build 38600122429 (cbb2f4c2f5) running; then test: Customize Player, opaque popups, bar spacing vs Figma, cursor/bars behaviour, video frame.
- Running: redesign-library integration and review, lazy panels review, motion harness fix.
- Rule added: never delete anything outside project-created paths.
- Waiting for Tony: redesign-settings push (web session); decisions on Hide UI 300 ms, Light FG colors, subtitle size, DM Mono.
```
