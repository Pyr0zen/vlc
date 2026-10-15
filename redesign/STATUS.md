# STATUS

- Updated: 2026-10-15 00:28 Central Europe Daylight Time
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
Alive: settings integration (on top of the library; also N1 Settings outside click), visual-audit fixes for the sidebar pages and widgets.
Merged and pushed, build 38647749799: library (743ce6f5ed), UX pass (51ebef4ce8: outside-click dismissal, Escape order, opaque tracks popup and bar, right-click on the bar), W8.3 onboarding, W8.1a Customize Player, playback-stall Qt fixes, control bar geometry, W8.4 light theme.
Queue, in order:
1. Hands-on test of build 38647749799 when Sticky is away (UX checklist in the scratchpad ux_interaction_findings.md, library checklist, onboarding with --qt-privacy-ask, Customize Player drags, stall tests, light/dark), then perf round 3 back to back with stock.
2. Core build (Decision 27): cherry-pick 3553e146bc from wip/a839e9d9ddb97595a (subtitle rate change flushes only the subtitle slave).
3. Settings merge, then a UX pass on the Settings dialog pages and on the library.
4. Leftover UX items N2-N5 (time field Escape and hint, Escape on bar control leaves the player (stock, Sticky to decide), resume toast vs tracks popup under 1000 px, arrows into a keyboard-opened sidebar, Delete removes a queue row); RdToggle hover; cursors; tooltip names.
5. Step 2: the 12 Settings rows (VIDEO_INDEX 350-361, Decisions 34-38).
Waiting for Sticky: A2 (resolved per Figma: bar opaque), B15 Advanced Settings button fill, B16 footer on the Playback tab, E2 dialog dim strength, E6 DM Mono, light FG/A4.
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
