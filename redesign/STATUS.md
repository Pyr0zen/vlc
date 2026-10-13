# STATUS

- Updated: 2026-10-13 14:28 Central Europe Daylight Time
- Current work package: Sidebar build round: rebuild run 38397378193 building, test next

## Last 10 commits
```
26eb8d70bc qt: windowed bars: second review pass
bf51a3e00d qt: windowed bars: review fixes
aec4d75266 qt: section header root is an Item (Text's implicitHeight is read-only)
77b6271d05 qt: video frame opening follows the bars' fade
e655c1737e qt: windowed bars show on mouse movement and hide after 3 s (Decision 30 update)
b82a0a9df4 redesign: Figma holds the final UIs; slider thumb and sidebar button follow it
5c5bd1203d qt: fix review findings in the sidebars and the effects bridge
2c36288b60 redesign: log the sidebar decisions and the Figma cross-check rule
3915ff52be qt: add the settings sidebar and the queue sidebar to the player
c0eb4b085d qt: extend the redesign component kit for the sidebars
```

## Latest report
```
PROGRESS REPORT (2026-10-13, sidebar round rebuild)
- Phase and status: Step 1. Round 4 passed earlier (run 38329239416). The sidebar round (settings sidebar W4.3a, W4.4, W4.5, W4.6 and queue sidebar W4.8) built as run 38390848560 but failed on this PC: VLC refused Player.qml, so the player page showed only the video. Cause: RdSectionHeader assigned the read-only implicitHeight of a Text root. Fixed. Rebuild run 38397378193 (commit 26eb8d70bc) is building; the sidebar test round with Figma side-by-sides follows.
- New since the last report: redesign/tools/qmlcheck.py compiles every QML file with Qt 6.8.3 (VLC's Qt version) against stubs of VLC's C++ types and flags Qt features VLC lacks; it reproduces the failure exactly and the whole tree passes after the fix. CLAUDE.md requires it before every push.
- Also in the rebuild: Decision 30 update (Tony): in a window both bars appear on mouse movement and fade 3 s after it stops; fullscreen keeps the per-edge bars. Video frame opening follows the bars' fade. Slider thumb and "Open Advanced Settings" follow Figma (Decision 31: Figma holds the final UIs).
- Review findings fixed: 2 review passes on the windowed bars (inactive window kept the cursor hidden, audio-only top bar background, window moves counted as mouse moves, unpin did not restart the hide timeout, F while pinned ended keyboard mode, poll ran while hidden, scaled-coordinate rounding).
- Decisions (Claude) added: the 3 s bar delay replaces VLC's mouse-hide-timeout preference for bars and cursor.
- Next: test run 38397378193 on this PC (portable mode, tester videos, 2400x1350 at 125%): every sidebar tab and state side by side with Figma crops and the video's final frames, windowed bars behavior, QML warnings in the log, regression checklist. Then mark VIDEO_INDEX rows and continue with the next 5 work packages.
- Proposals waiting for Tony: Light FG/1 #111111 and FG/2 #222222; pixel subtitle size and live subtitle style need core changes (Decision 27).
- Core changes so far: none.
- Blocked on: nothing.
```
