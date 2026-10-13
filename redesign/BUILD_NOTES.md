# BUILD_NOTES

Log of every CI problem and fix (newest last). Workflow: `.github/workflows/build-windows.yml`, plan: `redesign/BUILD_PLAN.md` section 3.

## 2026-10-13 W1.1 first workflow
- Run 38314489883 failed after 1 s of building: `extras/tools/bootstrap: cannot create check_tar: Permission denied`. Cause: the VideoLAN image runs as its own non-root user, the checkout belongs to the runner user. Fix: `sudo chmod -R a+rwX .` before `docker run`, `HOME=/tmp` for git config, then `chown` back after the build. Also seen (harmless, tools get rebuilt): meson 1.7.0 / ninja 1.12.1 in the image vs 1.10.0 / 1.13.0 expected by extras/tools.
- Added `build-windows.yml`: VideoLAN image `vlc-debian-win64-posix:20260611225331` via `docker run`, prebuilt contribs for contrib SHA a5538c557d27, `build.sh -r -a x86_64 -p`, `make package-win32-zip`, artifact `vlc-redesign-win64`.

## 2026-10-13 W1.1 first green build
- Run 38315049322 (commit 241edd8f49): green in 27 min total, build step 23 min (prebuilt contribs found for a5538c557d27, tools built from scratch). Artifact vlc-redesign-win64 = vlc-4.0.0-dev folder, 225 MB unpacked.
- Tested on Tony's PC (isolated APPDATA): vlc.exe opens, plays redesign/reference/vlc_redesign.mp4, auto-loads the .srt, closes cleanly. Phase 1 done.
- Windows Defender Firewall asks on first start of a new vlc.exe path (network access). Left for Tony to answer; not needed for local playback.

## 2026-10-13 W1.1 cached tools permission error
- Run 38317777499 failed after 5 min in extras/tools: `install: cannot change permissions of /build/extras/tools/build/share/autoconf-vlc/build-aux: Operation not permitted`. Cause: the restored tools cache belongs to the runner user, the image's own build user cannot chmod it (the chmod a+rwX workaround only gives write access). Fix: run the container with `--user $(id -u):$(id -g)` so everything has one owner; the chmod/chown workaround is removed. (The meson download 404 from downloads.videolan.org is harmless: the script falls back to GitHub.)

## 2026-10-13 INTERACTIONS.md review of the coded Step 1 work (fix batch after verification)
1. palette.rd* are dark-only constants; they must switch to the Figma Light values with the theme (INTERACTIONS 1).
2. TopBar folder chip hover uses a hardcoded white 6%; make it a palette token (rdHoverOverlay) shared with the icon buttons (INTERACTIONS 1).
3. TracksPopup must close on Escape and when the media changes, releasing the bar lock (INTERACTIONS 2).
4. The inline seek row is bound to PlayerControlLayout's middle slot; W8.1 must turn it into a movable control (INTERACTIONS 3). Design it that way when W8.1 starts.

## 2026-10-13 first compile of the redesign code
- Run 38318378755: tools step fixed (runs as runner uid). Compile error: control_list_model.hpp:114 `static_assert(RESERVED_0X2B == 0x2B)` after renaming slot 0x2B to AUDIO_TRACKS_BUTTON. Fix: assert `AUDIO_TRACKS_BUTTON == 0x2B` (keeps the alignment check).
- Found in review before the next push: `disconnect(m_ctx, &MainCtx::accentColorChanged, this, nullptr)` cannot deduce the slot type. Fix: keep the QMetaObject::Connection and disconnect it.
- Seen in every log, harmless: `Project ERROR: Unknown module(s) in QT: qmltest` (test project probe).

## 2026-10-13 fixes prepared during the first verification build
- The play button was never restyled in W3.2 (still VLC's round gradient button with hardcoded colors). Fixed: Figma 54x28 pill, accent / FG/A3 by play state, Figma play / pause icons.
- Hardcoded colors left in redesign code: folder chip hover rgba white 6%, RdShadow black 46%, volume cone empty part #090909. Fixed with palette tokens rdHoverOverlay, rdShadow, rdBgB2; the cone repaints when the palette changes.
- palette.rd* were dark-only. Fixed: applyRdColors() sets the Figma Dark or Light set with the color scheme.
- Open panels did not close on Escape, and the tracks popup stayed open across media changes. Fixed in Player.qml (lock released through RdPanels).

## 2026-10-13 first run of the redesign build on this PC (run 38319216444)
- The player page did not load: `Player.qml:958:5: Canvas is not a type`. VLC's contrib Qt is built with `-DFEATURE_quick_canvas=OFF` and `-DFEATURE_quick_path=OFF` (contrib/src/qtdeclarative/rules.mak), so Canvas, Shapes and Path do not exist. VLC fell back to a bare video window. Fix: the volume cone is a fragment shader (shaders/VolumeCone.frag, built by VLC's qsb pipeline), the video frame is the thick border of a rounded Rectangle. Rule added to INTERACTIONS.md: never use Canvas, Shapes, Path, AnimatedImage, Flipable, Sprite or particles.

## 2026-10-13 second on-PC test (run 38321852725) and test setup fixes
- Test isolation: VLC on Windows ignores %APPDATA% (it asks Windows for the Roaming folder), so the first test runs wrote into the real %APPDATA%lc of Tony's installed VLC (vlcrc, vlc-qt-interface.ini, a new ml folder). The saved "System" color scheme there made the build start in the light theme. Fix: the test helper now creates a `portable` folder next to vlc.exe (VLC's portable mode), so settings and the media library stay inside the build folder.
- This PC runs 2560x1440 at 125% Windows scaling: screenshots are compared at design scale (ours / 1.25). Measured: play pill 67 px = 54 design px, exact.
- The test window was covered by other windows: the helper now brings VLC to the front (attached input thread, topmost) and refuses to click or type unless VLC is the foreground window.
- Found and fixed: time labels "00:05" instead of "00:00:05"; resume toast showed the fallback text (media library duration not known yet); top bar title hidden while the toast shows (it stays visible at 14:05); top bar cone was VLC's banner cone, not the Figma icon; tracks popup had no "None" row, showed "[English]" brackets, too little space above dividers, and was not the Figma height; QML warning "anchors on an item managed by a layout" (ControlBar inline seek row); volume button showed VLC's "Mute" tooltip over the volume tooltip, which was narrower than the Figma 121 px.
- Tony's feedback: bars felt clunky in a window. Decision 30: windowed = both bars always visible, video between them; fullscreen = per-edge show with a smooth fade.
- To recheck on the next build: VLC once ignored the first close request (second one closed it); a second instance started while the first held the media library came up without the library.

## 2026-10-13 third on-PC test (run 38325488867)
- Works on this PC: windowed layout with both bars always visible and the framed video between them; tracks popup with None, Figma height, filled accent tab icons; Escape closes it; resume toast text; editable time; volume tooltip.
- Found: the seek handle was magenta (the seek row had been moved out of the control bar's item tree to silence a layout warning, so its ColorContext had no palette); times still MM:SS (the VLCTick enum is not reachable from QML: VLCTick.SubSecondFormattedAsMS has silently been undefined upstream too); no top bar title for files without a title tag; fullscreen bars did not appear near the edges (Tony saw it too): hover events do not reach Qt Quick while the cursor is over the native video, so the edge zones never triggered; VLC's shadow gradients behind the bars are not in the design.
- Fixed: seek row kept in the bar's item tree (hidden holder); VLCTick::formatHHMMSS(); title falls back to the file name; fullscreen edge zones read the cursor position (MainCtx::cursorPosition, 100 ms) instead of hover; gradients removed; top bar background equals the control bar's.
- Tony: a file watched to its last 20 seconds starts over without the resume prompt.
- Review fixes: resume prompt ignores the previous file's length; tracks popup height capped to the space above the control bar; windowed mode pins the visibility FSM (no lock-count side effects, menus are no longer force-closed); cursor stays visible while a bar is shown by proximity; volume tooltip also on keyboard focus.
- Not reproduced: an "Adjustments and Effects" window that appeared during Tony's own testing.

## 2026-10-13 build round: settings sidebar + queue sidebar (W4.3a, W4.4, W4.5, W4.6, W4.8)
- Before coding: frames and transcript 7:10-9:19 and 15:05-15:20 (Tony's reminder to read the transcript with the frames), Figma "Controls" variants dumped with geometry.
- Independent review found and fixed: QueueSidebar used DialogsProvider without importing VLC.Dialogs; Video filter cards called page functions from an inline component (ReferenceErrors, crop/clone edits ignored); RdValueBox emptied on click (Binding restore mode); gradient "Color" used the obsolete gradient-type option (now gradient-color); video splitters (Wall, Clone) read a vout variable that does not exist and joined modules into one name (now a single module in the configuration); color threshold sliders had no range (now 0-100, and unbounded VLC options are not used as ranges); Flip did not switch live between horizontal and vertical (the transform filter is restarted); crop boxes showed NaN without video; RdSegmented overwrote its caller's binding; the gear and list buttons switched tabs instead of closing; Escape in a value box closed the whole panel; configuration writes were not checked for missing modules; EQ edits with the preset on None had no effect (the equalizer turns on); queue drag could be taken by the page scroll; translatable unit strings; rounded panel corners covered by scrolled content.
- Known, not fixed in this round: the queue list builds every row (slow for very long queues; a ListView later); arrow-key navigation does not enter the sidebars yet (Tab and mouse work).


## 2026-10-13 on-PC test of the sidebar round (run 38390848560)
- Broken at runtime: VLC refused Player.qml ("Type SettingsSidebar unavailable"), so the player page showed only the video, without bars or frame. Cause: RdSectionHeader's root is a Text, whose implicitHeight is read-only. The build compiles because QML types are only checked when loaded. Fixed: the header is an Item of 39 px holding the Text.
- Prevention: redesign/tools/qmlcheck.py compiles every QML file with Qt 6.8.3 (VLC's contrib version, from PySide6) against generated stubs of VLC's C++ types, and flags Qt features VLC's Qt is built without. It reproduces this failure exactly and passes the whole tree after the fix. Rule in CLAUDE.md: run it before every push.
- Also in this rebuild: windowed bars show on mouse movement and fade 3 s after it stops (Tony, Decision 30 update); the video frame's opening follows the bars' fade instead of jumping when a bar has faded out.
