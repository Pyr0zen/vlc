# VLC Redesign Fork

## Project context
- Goal: a downloadable Windows app that is VLC media player with EVERYTHING the designer Juxtopposed shows in her "VLC Redesign" video implemented for real (Figma community file, CC BY 4.0). Same playback engine as VLC, her full redesign on top.
- Scope: match the video. Every screen, control, menu, behavior and feature she shows should exist in the real app and work the way she shows it. Nothing she shows is skipped or simplified without Tony's approval.
- The design is a mockup only. No code for it exists. Everything gets built by us on top of upstream VLC.
- The playback engine, codecs and core stay as they are wherever possible. Most of her ideas are UI work on top of features VLC already has. Where a feature truly needs core changes, explain why and get Tony's approval first.
- Base: VLC master (VLC 4 development branch), which has the QML interface in `modules/gui/qt`. Do NOT use the 3.0.x branch, its UI is QtWidgets and cannot be restyled the same way.
- This repo: Tony's GitHub fork https://github.com/Pyr0zen/vlc of the official mirror https://github.com/videolan/vlc (official upstream: https://code.videolan.org/videolan/vlc).
- Owner: Tony (GitHub: Pyr0zen). Windows 10 PC, PowerShell, user `Prem`.

## How we work
- You run on Tony's PC (native Windows Claude Code) inside this local clone, so you have the designer's full video locally.
- You write the code here, commit, and push to the `redesign` branch on GitHub.
- GitHub Actions compiles the Windows build. Tony has NO local build environment, never try to compile VLC on this PC.
- Use the GitHub CLI (`gh`, already logged in) to watch runs and read failed logs: `gh run watch`, `gh run view --log-failed`.
- Tony downloads the build artifact from the Actions tab and tests it on Windows.

## Design reference (local, in `redesign/reference/`)
- `vlc_redesign.mp4` the designer's full video. LOCAL ONLY, excluded from git, never commit it.
- `vlc_redesign.en.srt` its transcript, with her reasoning for every change.
- `frames/` scene-change frames already extracted.
- `figma/figma_file.json` full Figma file from the API (LOCAL ONLY, git-excluded); `redesign/FIGMA_FLOWS.md` summarizes its prototype interactions and exact specs.
- `redesign/BUILD_PLAN.md` architecture map, work packages (Step 1 UI only, then Step 2 new features), Phase 1 workflow, test loop, risks.
- `redesign/RESIDUAL_AUDIT.md` every element of VLC's current interface marked KEEP / MOVE / NOT IN VIDEO. Remove nothing until Tony decides.
- `redesign/STATUS.md` latest status (see Status file rule).
- `figma/` 105 PNG exports from her Figma file (68 screen frames, 35 component sets, 2 labels). Source of truth for how things LOOK.
- `figma/styles.txt` exact color and effect values. Always use these, never sample colors from PNGs.

The video is the primary source for everything. Tony wants the real app to look and work exactly like what she shows. Watch it carefully, not loosely.

First task in this project, before Phase 1 code: a full careful watch-through.
- Extract frames from the WHOLE video at 1 frame per second into `redesign/reference/frames_work/full/` and go through all of them alongside the full transcript, start to finish.
- Write `redesign/VIDEO_INDEX.md`: every single change, screen, control, menu, behavior and feature she shows or mentions, in video order, each with its timestamp range, the matching figma/ PNG filenames, and a status column (todo / in progress / done / blocked). This is an index for not missing anything, NOT a replacement for the video: whenever you build an item, go back to its timestamps in the video.
- Include small details too: icon styles, hover behavior, what hides when, wording of labels, order of menu items, sidebar tabs and their contents, settings categories, dialogs.

For every element, every time:
1. Before building or changing any element, find every part of the transcript that covers it.
2. Extract frames at those timestamps with ffmpeg (on PATH), as dense as needed to see hovers, menus opening, sidebars sliding and transitions. Save them in `redesign/reference/frames_work/` (also local only, do not commit).
3. Look at those frames AND the matching figma/ PNGs, then build.
4. After building, compare the result against the same frames and PNGs and list any differences for Tony.

## Branches and git
- Work only on the branch `redesign`. Never push to `master`. Never open pull requests to upstream videolan repos.
- Never commit build outputs, the mp4, or frames_work/.
- figma/, frames/, the srt and styles.txt may be committed (small files, useful for contributors).

## Current phase
READY TO BUILD. Next session: read CLAUDE.md, VIDEO_INDEX.md, FIGMA_FLOWS.md and BUILD_PLAN.md, then run the build from Phase 1 through all phases continuously, following the test loop, without stopping unless truly blocked.

- Last completed: W1.1 Windows CI build (Phase 1): run 38315049322 green, stock VLC plays a local video on Tony's PC.
- In progress: VERIFICATION of the already-coded Step 1 work (W2.1, W2.2, W2.5, W3.1-W3.8, W4.1/W4.2 part 1, commits f6664a9196..e6930fc114), pushed as run 38317777499. Next: download, run on this PC, test every state, fix, review (quality rules below). Nothing counts as done until it ran on this PC.
- After verification: W2.3 icons (Figma SVG export is in redesign/reference/frames_work/figma_svg, local only) and Inter font, then the rest of Step 1 (BUILD_PLAN.md), then Step 2.
- Update this section after every item: last completed row/WP with commit hash, next WP, latest green run.

## Working rules for the build
- **Plan:** `redesign/BUILD_PLAN.md` holds the architecture map, the work packages (W1.1 to W9.1) in dependency order with parallel lanes, the Phase 1 workflow, the test loop and the risks. Follow it; record deviations under "Decisions (Claude)" in VIDEO_INDEX.md.
- **Continuity rule:** keep VIDEO_INDEX.md Status (`todo` / `in progress` / `done (<commit>)` / `blocked (<reason>)`) and the "Current phase" section above updated after every item, so any new session can resume from the files alone.
- **Stop rule:** only stop if truly blocked or something only Tony can do is needed (login, payment, an API key like OpenSubtitles). Otherwise keep going to the next work package. Publishing a public GitHub Release (W9.1) needs Tony's go first.
- **Decisions:** Tony's decisions below are final. Anything not covered: her final version in the video wins, the Figma prototype fills what the video does not show. Every extra decision goes under "Decisions (Claude)" in VIDEO_INDEX.md, one line each.
- **Verification:** screenshot every state of every built element and compare with the video frames at the matching timestamps and the Figma PNGs before marking it done (BUILD_PLAN.md section 5). The video is the main guide: look at its frames BEFORE building each element, and always crop and zoom into the detail (icons, edges, spacing, text) instead of judging full frames. Always read the transcript lines at the same timestamps with the frames: many frames show how something USED to look (old VLC, rejected options, intermediate states) before she redesigns it later; only her final version is built. For every element make a side-by-side image (our screenshot crop next to the matching video frame crop, same scale, zoomed in) and only mark it done when they match; list remaining differences.
- **Status file (permanent):** keep `redesign/STATUS.md` updated and push it after every finished work package, every phase, and whenever you stop or get blocked. It holds, at the top, the date and time, the current work package and the last 10 commits (hash + message), then the latest PROGRESS REPORT. Overwrite it each time.

## Quality rules (mandatory for every work package; a package is NOT done until all pass)
- **Big picture first:** before starting a work package, read `redesign/INTERACTIONS.md` and plan the package against every feature it will interact with later (live theme and accent, panels and bar locks, Customize Player, presets and profiles, seek bar modes, keyboard, scaling), as the video shows them by its end. Check the package against it again before marking it done; add new interactions to that file when found.
- **Code quality:** follow VLC's existing code style and patterns in `modules/gui/qt`. Reuse existing VLC components and APIs. No hacks, no hardcoded values that belong in the theme (use `palette.rd*` / `VLCStyle.rd_*`), no commented-out code, no TODOs left behind. New code in new files where possible.
- **Zero new warnings:** no new compiler warnings and no new QML warnings (qmllint where available, plus the runtime console output). Fix, never suppress.
- **Independent review:** after each package, a fresh subagent that did not write the code reviews the full diff, hunting for bugs: null/undefined access, missing bindings, broken signal connections, leaks, race conditions, wrong state after open/close cycles, missing qtr/qsTr translations, keyboard focus and tab order. Fix, review again until clean.
- **Behavior tests on the real build:** every state of the package's features plus edge cases: window very small to maximized, fullscreen, Windows scaling 100/125/150 percent, no media, no subtitles, several audio and subtitle tracks, very long file names, audio-only files, keyboard-only use, rapid repeated clicking, opening and closing panels many times.
- **Regression checklist after every package:** open file, play, pause, seek, volume, mute, next/previous, fullscreen in and out, subtitle on/off and track switching, audio track switching, queue add/remove, drag and drop a file, keyboard shortcuts, settings survive a restart, app closes cleanly.
- **Visual check:** crop and zoom against the video frames and the Figma PNGs.
- **Crashes:** any crash or freeze stops everything until fixed.
- **Small commits:** one logical change each. Never more than one work package unverified at a time.
- **Bug log:** log every bug found and fixed in `redesign/BUILD_NOTES.md`.

## Decisions (Tony, 2026-10-12)
General rule for anything not listed: her final version in the video wins, the Figma prototype fills what the video does not show.
1. Fullscreen button in the top bar. Picture-in-Picture skipped for now.
2. Main "..." menu: her last version, matching Figma menu.png.
3. Queue: tabbed sidebar with Queue / Bookmarks / Chapters, everywhere.
4. Bars show on hover near them and hide instantly when the mouse moves away.
5. Gear opens the settings sidebar on the Playback tab. Subtitle and audio buttons open the tracks popup on their tab.
6. Seek thumbnail shows anywhere along the seek bar while hovering.
7. Volume range 0 to 200%.
8. Home page includes "Latest Streams".
9. Onboarding: picking a theme or accent color recolors the app live.
10. Mini player queue header: the video's 5 icons.
11. Wording: the video's wording where it differs from Figma.
12. External Tracks "+": Figma's "To This File / From Computer" flow with the language list.
13. Playback tab: the video's items (including Show Waveform on Seekbar and Show Metadata) plus Figma's Show Statistics.
14. Prototype placeholder links (About VLC, Quit VLC, More Settings, Open Media, right-click Playlist): wire each to its real action.
15. Accent color options: #D37918, #E15032, #C49E23, #19A234, #18AAD3, #185DD3, #8E42FF, #F052B3, #AFAFAF (in figma/styles.txt).
16. Menu icons use Accent/DIm #AB6314.
17. Fix the design typos.
18. Presets: one preset per show covering all tabs (subtitles, audio, video, playback).
19. Gear icon: the Figma version.
20. Dark theme first. Light theme last: propose corrected Light/FG/1 and FG/2 values.
21. Features with no Figma frame: build from the video, styled to match the Figma components.
22. Keep all VLC default shortcuts. F = fullscreen, V = cycle subtitle track. Hide UI = Ctrl+\. Add Ctrl+B = create bookmark. Ignore the prototype's F and V bindings.
23. Sleep Timer: Off / 15 / 30 / 45 / 60 min / End of current file.
24. Show Metadata opens a file info panel. "Render: Local" is VLC's existing renderer/cast picker.
25. Per-preset "..." menu: Rename, Duplicate, Delete. Profile "+ New": enter a name, copy current settings.
26. Info icon: click shows the setting's description in a popover.
27. Core changes approved wherever a feature truly needs them, minimal and isolated. Examples: OSD showing the pressed shortcut, subtitle timeline (external files first, embedded later if feasible).
28. Accepted limit: subtitle outline uses VLC's existing outline sizes.
29. Postponed: reverse playback. Profiles may need a restart for some settings; show a notice when that happens.

## Report format (use for every progress report to Tony; plain text, no em dashes)
PROGRESS REPORT
- Phase and status
- What was built since the last report
- Latest green build: run number, artifact name, exact click path to download it
- VIDEO_INDEX.md: items done / total, by area
- Decisions (Claude) added since the last report
- Remaining differences from the video, with timestamps
- Core changes made so far and which files they touch
- Warnings: new compiler / QML warnings count (must be 0)
- Review findings fixed (independent subagent review)
- Edge cases tested
- Regression checklist result
- Known bugs remaining
- Blocked on: what exactly, or "nothing"

## Public release rules (apply from day one)
- GPL: VLC is GPLv2 or later. Keep `COPYING` and all copyright notices untouched. All our changes stay public under the same license.
- Trademarks: "VideoLAN", "VLC" and "VLC media player" are registered trademarks of the VideoLAN non-profit, and the cone is VLC's official icon. Public builds ship under Tony's own project name and icon, described only as "based on VLC media player". Never imply it is an official VideoLAN product.
- The design is CC BY 4.0: the README must credit Juxtopposed and link the Figma file (https://www.figma.com/community/file/1691465999134370980/vlc-redesign) and her video (https://youtu.be/ERFeOgqk324).
- Where the design shows the VLC cone or the name "VLC", public builds use Tony's name and icon instead. Colors, layout and controls are fine to use.

## Rules
- Core (`src/`, `include/`, non-GUI modules): only where a feature truly needs it, minimal and isolated (approved by Decision 27). List every core change in VIDEO_INDEX.md "Core changes (status)".
- Commands Tony runs himself: PowerShell, ONE copy-paste block chained with `;`, real paths filled in (`$env:USERPROFILE`). Explanation above the block, never after.
- Communication: direct and short, bold step headers, no walls of text, no em dashes. For GitHub web steps give exact click paths.

## Roadmap (high level; the detailed order is BUILD_PLAN.md, run continuously)
- Phase 2, colors: apply the palette via `modules/gui/qt/style` using `figma/styles.txt`. Dark theme is primary. Light theme second (its FG/1 and FG/2 equal the Dark values, likely a design mistake, ask Tony before using them).
- Phase 3, control bar: everything she shows for it (thin bottom bar, thick seek bar, play button with prev/next around it, cone-shaped volume slider, fullscreen and settings on the right, queue button, subtitle and audio track buttons on the bottom right, hover show/hide). One element at a time, video and PNGs checked before and after.
- Phase 4, layouts: top bar that shows title on hover in fullscreen, right sidebar (subtitles, audio, video, playback tabs), compact library sidebar, full library, network streams, playlists, home page, recent files, pins, menus, right-click menu, settings screen with her categories, hotkeys dialog, customization screen, onboarding.
- Phase 5, her new features: everything she shows that VLC does not do today, built to work for real. Examples from the video: subtitle add dialog (file/folder/playlist, from PC or OpenSubtitles, auto-matching per episode), subtitle timeline for syncing, sliders for subtitle timing, precise font sizes, per-show presets, default subtitle and audio track per show, audio and video filter presets with previews, reverse playback, sleep timer, waveform seek bar, seek thumbnails, unwatched/watched sorting, bookmarks sidebar with Ctrl+B, chapters, shortcut shown in on-screen messages, accent color setting, profiles with layouts. Use VIDEO_INDEX.md as the full list. Build one at a time, check each against the video, tell Tony if one is technically impossible and why.
- Phase 6, public release: Tony's project name and icon everywhere user-facing (window title, about dialog, executable name, installer, file associations), README (what it is, screenshots, "based on VLC media player", design credit with CC BY 4.0, GPL notice, how to download), and a workflow that publishes to GitHub Releases on version tags: a Windows installer (.exe, reuse VLC's own packaging in `extras/package/win32/` with our name and icon) plus a portable zip. Label builds as experimental, since they track VLC 4 development code.
- Ongoing: sync with upstream VLC master regularly, resolve conflicts in our UI changes, rebuild.
