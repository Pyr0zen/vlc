# STATUS

- Updated: 2026-10-13 19:06 Central Europe Daylight Time
- Current work package: Build round menus and dialogs: run 38435859498 building; performance pass in progress

## Last 10 commits
```
f8c464b632 redesign: notes for the menus and dialogs build round
824a6f3456 qt: Keyboard Shortcuts dialog hosted over every view, opens within a frame
4f96770867 qt: menus: second review fixes
9a9f2e1331 qt: Settings dialog: second review fixes
4474d467e5 qt: popups hand keys over when they start to show / hide
4c1d88ec4c Merge W6.3: Keyboard Shortcuts dialog
abb861faf1 Merge W6.1: redesigned Settings dialog shell
4b63fcef2b Merge W6.4: open dialogs split and restyled, Open Network Stream dialog
8678f8f991 qt: Settings dialog review fixes
870bfd93ce qt: raise the main window for the Settings dialog, keep VLC's preferences open
```

## Latest report
```
PROGRESS REPORT (2026-10-13 evening)
- Phase and status: Step 1. Build round "menus and dialogs" pushed: run 38435859498 (commit f8c464b632) with W4.9 main menu, W4.10 right-click menu + Hide UI, W6.1 Settings dialog shell, W6.3 Keyboard Shortcuts dialog, W6.4 open dialogs, plus the sidebar Figma fixes and the icon audit. Next: test it on this PC (portable mode, tester videos) with Figma side-by-sides and the regression checklist.
- How it was built: four worktree agents coded the five packages in parallel; each branch got an independent review, fixes by its author, a merge by the coordinator and a second review after the merge. Shared fixes: one modal counter so popups get Escape/arrows/Space in the player view; popups hand keys over at the start of show/hide; one RdTextField placeholder; Keyboard Shortcuts dialog hosted over every view and preloaded.
- Tony's new rules (2026-10-13), in CLAUDE.md: performance first (at least as snappy as stock VLC, hard targets, PERF.md every round, regressions stop everything) and the motion check (measure animations frame by frame; the video is edited, Figma prototype timings are primary).
- Performance pass: static audit done; three worktree agents: lazy sidebars/pages + lazy queue list (running), event-driven cursor instead of the 100 ms poll (running), RdEffects per-key cache + coalesced applies + background config save + async resume lookup (done, in independent review). These go into the next build. Measurement harness redesign/tools/perf (startup, open, CPU/RAM/GPU, Desktop Duplication motion captures, 4K dropped frames, 520-item queue) ready; the first stock-vs-redesign round waits for a quiet machine (agents load the CPU).
- Parallel session: the web session builds Phase 5 on branch redesign-library; figma_file.json and frames_library/ (490 frames at 2 fps) are pushed for it.
- Decisions waiting for Tony: Open Network Stream opens with a 200 ms fade (Figma: instant; video fade looks like an edit); Hide UI 300 ms (Figma) vs the 150-200 ms cap; Light FG/1 #111111 and FG/2 #222222; pixel subtitle size / live subtitle style need core changes (Decision 27); DM Mono font for the shortcut fields (Consolas used until approved); Figma API rate-limited for about 4 days (starter plan).
- Core changes so far: none.
- Blocked on: nothing.
```
