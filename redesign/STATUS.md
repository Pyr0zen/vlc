# STATUS

- Updated: 2026-10-13 03:02 Central Europe Daylight Time
- Current work package: Verification round 4 (build run 38329239416 pending test)

## Last 10 commits
```
b7aaf8443a redesign: record where verification stopped (round 4 build pending)
990258263f qt: fix review findings on the fullscreen bars and resume prompt
0028f1bbbe qt: fix fullscreen bars, seek bar colors, title and resume prompt
e1d9d04c7d redesign: 5 work packages per build, core changes in their own build
55a8c746d3 redesign: build rounds, clean stop rule, round 2 test notes
3f091bf287 qt: volume tooltip matches the Figma "audio value" box
d66fc95454 qt: fix the player differences found on the first on-PC test
ff8922846b redesign: require side-by-side comparisons with the video for every element
f74b83911e qt: draw the volume cone and video frame without Canvas
c64aded988 qt: fix review findings in the redesign icons, Escape and fonts
```

## Latest report
```
PROGRESS REPORT (stop for the day, 2026-10-13)
- Phase and status: Step 1, verification of the already-coded UI work. 3 test rounds ran on Sticky's PC; round 4 build (run 38329239416, commit 990258263f) was building at the stop and is NOT tested yet.
- What was built since the last report: Figma icon set (206 SVGs, accent-colorable) used across the player; Inter font bundled (OFL); play/pause pill; palette tokens switch with light/dark; volume cone and video frame redrawn without Canvas (VLC's Qt has no Canvas); Decision 30 (windowed: both bars always visible; fullscreen: per-edge bars that fade); HH:MM:SS times; resume toast "You already watched till ..." and no prompt in the last 20 s; tracks popup with None row, Figma height, cleaned labels; fullscreen edge detection by cursor polling; RESIDUAL_AUDIT.md (380 elements).
- Latest green build: run 38325488867 (artifact vlc-redesign-win64). Click path: github.com/Pyr0zen/vlc > Actions > build-windows > run 38325488867 > Artifacts > vlc-redesign-win64. Run 38329239416 has the newest fixes.
- VIDEO_INDEX.md: rows not yet marked done; marking waits for round 4 to pass.
- Decisions (Claude) added: light FG/1 and FG/2 proposal (#111111, #222222, needs Sticky's OK); accent shades derived per theme; Inter as 5 static weights; window buttons and muted icon notes; checked buttons use the filled state-active icons; Record label Shift+R and onboarding shortcuts use VLC keys.
- Remaining differences from the video: seek hover thumbnail not built (W3.3b, shows VLC's time tooltip); top bar folder chip icon should switch to "Videos" style when opened from the library (14:05); library sidebar (11:41) not built; title shows the file name with extension where she shows a clean title.
- Core changes so far: none (all changes in modules/gui/qt).
- Warnings: one QML warning found and fixed in round 3; round 4 log still to check.
- Review findings fixed: 2 independent reviews in this stretch (13 and 10 findings), all bugs fixed (HiDPI icon size, icon alpha, Escape vs control bar cancel, stale length in resume prompt, popup overflow, FSM lock in windowed mode, others).
- Edge cases tested: 125% Windows scaling at 2560x1440, file path with spaces, video reaching the end, Escape with popup open, second instance while the first holds the media library.
- Regression checklist result: partly (play/pause, seek, volume, tracks, fullscreen in/out, close cleanly); full checklist in round 4.
- Known bugs remaining: VLC once ignored the first close request (recheck); the earlier test runs wrote into Sticky's real %APPDATA%\vlc (fixed by portable mode, no backup of the old files).
- Blocked on: nothing.
```
