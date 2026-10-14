# STATUS

- Updated: 2026-10-15 00:16 Central Europe Daylight Time
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

## Agents (rule: at most 4 alive in total, sub-agents counted; agents never start sub-agents)
Alive: library integration, settings integration, UX interaction fixes, visual audit (finishing its sub-agents).
Merged since the last status (pushed, build 38646392092): W8.3 onboarding, W8.1a Customize Player (both reviewed by the main session on the shared files; their own in-agent reviews done), playback-stall Qt fixes (subtitle speed on release, delay at most 10/s, pitch/blur/audio delay on release, no chain rebuild when unchanged). Merge fix 9291b80fdd (MainInterface loaders).
Queue, in order:
1. Core build (Decision 27, its own build): cherry-pick 3553e146bc "input: flush only the subtitle slave when its rate changes" from wip/a839e9d9ddb97595a after build 38646392092 is tested.
2. Library merge (after its fixes), then settings merge; UX pass on each.
3. Fixes from the visual audit list (scratchpad visual_audit.md), grouped by area.
4. Step 2: the 12 Settings rows (VIDEO_INDEX 350-361, Decisions 34-38).
Backups: every agent branch is pushed to origin wip/<agent id> (no CI on those branches).

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
