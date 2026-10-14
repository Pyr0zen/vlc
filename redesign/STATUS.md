# STATUS

- Updated: 2026-10-15 00:00 Central Europe Daylight Time
- Current work: UX pass on everything built (Sticky's reports), library + settings integrations, W8.1a, W8.3 done; build 38644265811 (light theme + control bar fix) running

## Last 10 commits
```
5bc55b6e76 redesign: rule: identical to Figma, not similar
64e97a3bca redesign: log Sticky's UX bug reports
66ebbdabce Merge control bar Figma geometry fix, narrow windows, light-only top line, top bar divider
81aa0ea194 redesign: rule: agent pacing, at most 3 running, queue by priority
2665481e5d redesign: Decisions 34-38 (settings rows), permanent UX pass rule
971d30ddb4 redesign: notes: control bar geometry root cause, narrow-window decision
a3d60c6554 redesign: rule: UX logic checklist for every package (Sticky)
3e214bc75b Merge redesign (W8.4 light theme) into the control bar fix
8a9caf449a qt: top bar divider as in Figma: 1.5 x 18 line with round caps
53e9b07753 qt: player: no line on top of the control bar in the dark theme
```

## Agents (pacing rule: start a new one only when fewer than 4 are running)
Running: library integration (review fixes H1-H3/M1-M10, Sticky's rail marker, merge redesign), settings integration (all review findings, section 5), W8.1a Customize Player, UX interaction audit + fixes (dismissal, mouse, hotkeys, tracks popup header, fullscreen bar), playback-stall fixes (subtitle speed/timing freeze, all live controls), visual Figma audit (read-only list).
Queue, in order:
1. Independent review of W8.3 onboarding (worktree-agent-aac3dd02cc9c78a37, done, not merged).
2. After the library merge: UX pass on the library (same checklist).
3. After the settings merge: UX pass on the Settings dialog pages.
4. Fixes from the visual audit list (scratchpad visual_audit.md), grouped by area.
5. Step 2: the 12 Settings rows (VIDEO_INDEX 350-361, Decisions 34-38).

## Latest report
```
PROGRESS REPORT (2026-10-14 evening)
- Merged and pushed: W8.4 light theme (b25f862d56, build 38609407210 green), control bar Figma geometry fix (66ebbdabce: root cause the one-row bar never got the Figma gaps; narrow-window hiding order; top line only in light; top bar divider 1.5 x 18). Build 38644265811 running.
- PERF.md round 2: open-file regression fixed; RAM/decoder numbers drift with machine state, so comparisons run back to back.
- Rules added: UX pass on every package, identical to Figma (not similar), build list checker, agent pacing, test media, batched hands-on tests.
- Decisions (Sticky) 33-38 recorded (light FG, popup duration, process priority words, cast discovery, double click/single click, night mode listening test).
- Waiting for Sticky: light FG/A4 (#3B3B3B in Figma, nearly as dark as text), Hide UI 300 ms vs cap, subtitle size (core), DM Mono font.
- Hands-on tests waiting for "I'm away": build 38644265811 (light/dark switch, control bar vs Figma, narrow window), redesign input perf scenarios + 4K fullscreen back to back with stock, double click / right click / wheel / hotkeys probe.
```
