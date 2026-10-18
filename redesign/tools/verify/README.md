# Verification harness (redesign/tools/verify)

Drives the test build through a table of scenarios, screenshots only the player window, diffs
each screenshot crop against the matching Figma frame crop at the same scale and writes a report
that lists, per VIDEO_INDEX row, what matched and what differs. It shrinks the "coded but not
verified" pile: rows that match are proposed as **auto-passed**; the main session reviews them
and marks VIDEO_INDEX itself (the harness never edits VIDEO_INDEX).

## Files
| File | What it does |
|---|---|
| `verify.ps1` | runner: plan, dry run, row filter, sessions, cleanup, then `compare.py` |
| `driver.ps1` | Win32 + UI Automation: start / find / size / focus the player, guarded input, window-only capture, graceful quit |
| `steps.ps1` | step executor (the step reference below) |
| `compare.py` | Figma crop + diff + images + `report.json` / `report.md`; also `--validate` and `--nodes` |
| `make_media.py` | generates the harness's own test media (ffmpeg) |
| `spec.py` | loads the machine-readable Figma spec (`spec/`, made by `make_spec.py`, see `redesign/VERIFY_SPEC_NOTES.md`): one screen state's elements, normalised; parts the spec files leave out (the Controls popups and sidebars) are built with make_spec's own Builder |
| `demo_state.json` | the design's demo values per screen (subtitle delay -4 s, toggles, colours) and how the harness sets each: run profile (vlcrc), UI, already the default, or masked |
| `probe.ps1` | authoring helper: starts the player, runs steps, dumps the UIA tree and a screenshot |
| `scenarios/*.json` | the scenario table, one file per area |
| `verify.example.json` | settings with placeholders (committed) |
| `verify.local.json` | the real paths of this PC (gitignored, never committed) |

## Setup (once per PC)
1. Python 3 with Pillow and NumPy (`pip install pillow numpy`), ffmpeg on PATH, Windows PowerShell 5.1.
2. Create `verify.local.json` next to this file (gitignored):
   ```json
   { "testMediaDir": "<TEST_MEDIA_DIR>", "outRoot": "<WORK_DIR>\\verifyruns", "ignorePids": [],
     "builds": { "public": "<path to Cone.exe>", "vlc": "builds\\current\\vlc.exe" },
     "profileSource": "builds\\current-public\\portable" }
   ```
   with the real folders. `outRoot` must be outside the repository (screenshots never go into
   the repo; `verifyruns/` is also gitignored as a safety net). `ignorePids`: player processes
   that are stuck without a window and must not block a run.
3. `python make_media.py` creates `<TEST_MEDIA_DIR>\builds\test-media\verify\Videos\`:
   - `Verify Clip.mkv`: 25:40 long (Figma's "00:25:40"), a still picture in the Figma video
     colour, title "VLC Media Player" and a "Videos" folder (what Player.png shows in the top
     bar), two subtitle tracks off by default, no audio (an audio track draws the waveform on the
     seek bar when the test profile has it on; Figma's default bar has none).
   - `Verify Tracks.mkv`: the same with two silent audio tracks (English / Japanese, as the
     Figma tracks popup) and `The_Wand_S01_EN.srt` (the external file name Figma shows).
   - `Verify Chapters.mkv`: 2 h with the five chapters of the Figma Chapters tab.

## Running
```
powershell -NoProfile -ExecutionPolicy Bypass -File verify.ps1 -DryRun          # plan + Figma node check, sends nothing
powershell -NoProfile -ExecutionPolicy Bypass -File verify.ps1                  # all scenarios, public build (Cone.exe)
powershell -NoProfile -ExecutionPolicy Bypass -File verify.ps1 -Only P2-03,F-01 # only scenarios covering these rows (or scenario ids)
powershell -NoProfile -ExecutionPolicy Bypass -File verify.ps1 -Area player -Build vlc
python compare.py <run dir>                                                     # re-run the comparison on an existing run
```
- Builds: `public` = `<TEST_MEDIA_DIR>\builds\current-public\Cone.exe`, `vlc` =
  `<TEST_MEDIA_DIR>\builds\current\vlc.exe` (the fixed test folders; portable mode, the
  `portable` folder there is the test profile).
- Output: `<outRoot>\<yyyyMMdd-HHmmss>[-label]\`: `run.log`, `run.json` (steps, checks, shot
  metadata), the screenshots, `compare\*.png` (Figma | build | diff heatmap: red = brightness /
  colour difference, green = solid differing shapes, blue = masked), `report.json`, `report.md`.
- A full Player pass (6 sessions, 24 scenarios) takes about 3.5 minutes plus about 40 s of
  comparing; everything (9 sessions, 41 scenarios: player 24, settings 15, library 2) about 4 minutes
  plus 1.5 minutes.

### Reading the report
Per row: **auto-passed** (every compare within tolerance and every behaviour check passed),
**near-match** (only small differences: stroke weight, 1-2 px edges; a glance at the images
decides), **differs** (the main difference is listed with the Figma nodes under it),
**inconclusive** (the compared area was mostly masked) and **error**. "Human checks" are the
behaviour points the harness cannot judge (motion curves, typing a key the layout cannot send,
real devices). The report is a proposal: the main session looks at the images and marks rows.

Compare metrics (defaults in `compare.py`, per compare item `"tolerance"` overrides):
- a pixel differs when no build pixel within 1 px matches it by more than `channel` (24) in
  brightness, or in colour after a 3x3 blur (Qt draws text with ClearType fringes, Figma in grey);
- `fraction`: share of differing pixels (pass 1 %, near-match 4 %);
- `core`: share of differing pixels whose whole 3x3 neighbourhood differs, i.e. real shapes, not
  edges (pass 0.1 %, near-match 0.3 %);
- `tile`: worst 24 x 24 px tile, so one wrong word or icon in a big crop is not diluted (pass 8 %,
  near-match 20 %);
- `mean`: colour shift of the flat areas (backgrounds, fills; max 4 levels);
- `shift`: the best match may sit 1 physical px off (rounding at 125 %); larger offsets are listed;
- `search` (logical px): menus and popups that open at the pointer are looked for in that radius.

## Safety rules (Sticky's PC)
- Input (keys, mouse, UIA actions) is only sent while a window of a player process **this run
  started** is the foreground window. Otherwise the driver waits and retries for `guardRetrySec`
  (60 s) and then stops the run without sending anything. To take the foreground it injects one
  press of an unassigned virtual key (no Alt tap, which could open another window's menu bar).
- Before a run it waits (up to 30 min) while another test player from `builds\current*` runs (the
  main session's manual tests); `ignorePids` and players stuck without a window are skipped.
- Every session ends with Escape, the volume put back to the profile's value, Ctrl+Q, then a
  close message; a started process that still shows a window after that is hung and is ended
  (only processes the run started). A process without any window that does not exit is stuck in
  termination: it is never touched, only reported (the cleanup line names it). The final cleanup
  line in the report confirms none is left running.
- `--no-qt-updates-notif` is passed to vlc.exe only (Cone builds have no update checker and
  refuse unknown options); `--no-one-instance` keeps the media in the started process.
- Nothing is ever deleted outside the run folder; the harness writes only into `outRoot` and
  `<TEST_MEDIA_DIR>\builds\test-media\verify`.

## Privacy rules
- Screenshots capture **only the player's own windows** (PrintWindow of that window; if that
  comes back black, the screen area of that window while it is in front). Never the desktop.
- Screenshots and reports stay in `outRoot` (outside the repo, gitignored `verifyruns/`). Never
  commit them; they can show the owner's settings.
- Test media: only the generated files above (and other generated media under
  `<TEST_MEDIA_DIR>\builds\test-media`). Never the owner's music or videos.
- Committed files use placeholders (`<TEST_MEDIA_DIR>`, `<WORK_DIR>`); real paths live in
  `verify.local.json`. Run `python redesign/tools/privacycheck.py` before every commit.

## Adding a scenario
1. Find the Figma frame and nodes: `python compare.py --nodes <node id> [depth]` lists children
   with positions relative to that node (top-level frames and their PNGs: FIGMA_FLOWS.md "Frame
   to PNG map"; Controls.png variants hold the bar with its popup / sidebar, see `491:1780`).
2. Find accessible names: `powershell -File probe.ps1 -Steps <steps.json>` writes `uia.txt`
   (UI Automation tree: role, name, rectangle in physical px) and `window.png` into outRoot.
3. Add the scenario to `scenarios/<area>.json` (format below), run `verify.ps1 -DryRun` (it also
   validates every node id), then `verify.ps1 -Only <scenario id>`, and look at `compare\*.png`:
   a mask or a fixture (media title, track language) is better than a looser tolerance.

### Scenario file format
```json
{ "area": "player",
  "sessions": [ {
    "id": "bar", "media": ["Videos\\Verify Clip.mkv"], "args": ["--restore-playback-pos=0", "--start-paused"],
    "size": [1920, 1080],
    "setup": [ <steps run once after the start> ],
    "reset": [ <steps run before every scenario> ],
    "scenarios": [ {
      "id": "bar-default", "title": "...", "rows": ["P2-03"],
      "steps": [ <steps> ],
      "compare": [ {"id": "seek", "shot": "bar", "ref": "491:1779", "anchor": "bl", "node": "1908:7387",
                    "pad": 2, "mask": [{"node": "..."}, {"rect": [x, y, w, h]}], "search": 0,
                    "tolerance": {}, "rows": ["IA-13"], "note": "why a mask"} ],
      "human": ["behaviour points left for a person"] } ] } ] }
```
- `media` paths are relative to `test-media\verify`; `{media}` inside `args` stands for that folder.
- The window's client area is sized to `size` logical px (Figma units; 1920 x 1080 = the player
  frames) at the screen's top-left.
- Compare placement: `ref` is a Figma node with a known place in the window; `anchor` (tl, tr, bl,
  br) puts its corner on the same corner of the client area (a 1920 x 1080 player frame: tl; a
  Controls variant: bl / br, the bar sits at the bottom), or `"at": [x, y]` (+ `"from"`) puts its
  top-left at a client position. `node` or `rect` (relative to ref) is the compared part.
  `backdrop` {"node", "at"} gives components drawn without a background their Figma background.
- `rows` on a compare item says which VIDEO_INDEX rows it covers (default: the scenario's rows).

### Run profile and demo state
- `profileSource` is copied once per run (`<run>\profile-base`); before every session that copy is
  mirrored into the build's `portable` folder, so each session starts from the same profile and
  the source is never edited. The harness refuses to mirror into a `builds\current*` folder.
- A session's `"demo": [screen ids]` writes those screens' `vlcrc` values from `demo_state.json`
  into the run profile; a `{"demo": "<screen>"}` step sets the per-media ones through the UI
  (e.g. the subtitle delay typed into its value box). A compare / measure item with
  `"demo": "<screen>"` compares the values that could not be set by position only. The report
  lists what was set and how ("Demo state").

### Measured checks (spec.py)
A compare item `{"id": "spec", "shot": "bar", "measure": "spec", "png": "Controls.png", "props":
{"Property 1": "default"}, "anchor": "bl"}` (optional `"node"` for a part such as a popup, `"ref"`
for where it is placed, `"alignTo"` for popups found by a region compare) checks every element of
that spec state that is inside the window:
- geometry: the UI Automation rectangle that overlaps it best (IoU >= 0.6, texts by their text)
  against `bounds`, +-1 logical px (texts: the centre +-3 px); the shot needs `"uiaAll": true`;
- colour: the dark token fill on a 5 x 5 grid inside it (children left out), 8 levels (24 for
  `translucent`); texts: the text colour must appear in the text box;
- pixels: leaf elements (icons, texts, small shapes; not thin lines) as a fuzzy crop;
- `mask` elements and unset demo values: geometry only; `brand` elements: skipped on the public
  build; the frame background image (`background_mask: image`) is never compared.
Each element is its own entry under its `rows` (the frame's rows when it has none). The report
lists for every auto-passed row the elements that support it and flags weak rows: only
frame-level fallback rows, or only elements that suggest 4+ rows (generic containers).
`"specMasks": {"png", "props", "node", "texts"}` on a region compare leaves the spec's sample
content, brand elements (public build) and unset demo values out of its pixel diff.

### Step reference
Positions are logical px inside the client area, from the corner `"from"` (tl default, tr, bl, br).
| Step | Meaning |
|---|---|
| `{"wait": ms}` | pause |
| `{"keys": "^a", "after": ms}` | SendKeys syntax (`{ESC}`, `{ENTER}`, `^q`, `" "` = Space) |
| `{"click": [x, y], "button": "left/right/middle", "count": 2}` | mouse click |
| `{"hover": [x, y]}` / `{"wiggle": [x, y]}` | move the pointer / small move (bars appear on movement) |
| `{"wheel": [x, y], "delta": -120}` / `{"drag": [x1, y1, x2, y2]}` | wheel, guarded drag |
| `{"uia": "Name", "role": "Button", "action": "click/rightclick/hover/invoke/setvalue/focus", "match": "exact/contains", "optional": true}` | act on a UI Automation element (click = real mouse click on its centre) |
| `{"volume": 0.5}` | volume (1.0 = 100 %) with the wheel over the volume slider; restored at session end |
| `{"resize": [w, h]}` | client size in logical px |
| `{"shot": "name", "windows": "all", "uiaRects": ["Progress"], "uiaAll": true}` | screenshot (client area; `all` adds the player's other windows; `uiaAll` records every UIA rectangle for the measured checks) |
| `{"demo": "<screen>"}` | sets the screen's per-media demo values through the UI (demo_state.json) |
| `{"expect": {"uia": "Player controls", "visible": false, "present": true, "value": 0.08, "tol": 0.001, "name": "*x*"}, "check": "text"}` | automatic behaviour check (recorded, a failure makes the row "differs") |
| `{"uiaDump": "name"}` / `{"note": "text"}` | write the UIA tree / a note into the run |

## Beta gate (gate/)
The release check for the public build (Cone), one command per part plus one for all of them.
Each run writes `<outRoot>\gate-<yyyyMMdd-HHmmss>[-label]\`: `gate.log`, one folder per part
(`result.json`, screenshots, player logs), `contact-<part>.png` sheets, `review.json` and
`gate-report.md` / `.json`.

| File | What it does |
|---|---|
| `gate/gate.ps1` | the parts below; `-Part all` runs them in order |
| `gate/gatelib.ps1` | lane copies, the gate profile, crash events, process samples, the write guard |
| `gate/make_beta_media.py` | generates the playback matrix into `<TEST_MEDIA_DIR>\builds\test-media\beta` |
| `gate/screens.json` | the main screens: open, one action, close (each close variant) |
| `gate/report.py` | report, contact sheets, review.json (re-run it after viewing the screenshots) |

```
python gate\make_beta_media.py                                        # once (ffmpeg); --force regenerates
powershell -NoProfile -ExecutionPolicy Bypass -File gate\gate.ps1 -Part all -Build <build folder or Cone.exe> [-Zip <artifact zip>]
powershell ... gate\gate.ps1 -Part smoke -Build <build>               # 1 minute, after every fix
powershell ... gate\gate.ps1 -Part screens|playback|quit|perf|soak|footprint|branding -Build <build> [-Run <gate run folder>]
python gate\report.py <gate run folder>                               # after filling in review.json
```
`-Run` adds a part to an existing run (one report for all parts). `-SoakMin` (default 20),
`-Quits` (30), `-Accent` (`#8E42FF`), `-Stock` (default `stockBuild` in verify.local.json: the stock
VLC 4 build of the performance rule, run 38315049322).

`-Part all` order: footprint (before), screens, playback, quit, perf, branding, soak (last: 20
minutes without input, can run unattended), footprint (after). About 45 minutes. Parts that need
input stop at the input guard like the harness (no input while the player is not in front; the
no-input parts still run).

### What each part checks
| Part | How | Pass |
|---|---|---|
| screens | `screens.json`: player with both bars (woken by moving the pointer over the video, like a user), settings sidebar tabs, tracks popup tabs (and a track choice), queue / bookmarks / chapters (one bookmark added), main menu + Profile submenu, right-click menu + Playback submenu, library sidebar (Home, Videos, Music), full library with the mini player, Settings dialog (every page), Keyboard Shortcuts (search), About. Dark theme with a non-default accent (`qt-accent-color`, vlcrc) with every close variant (button / Escape / click outside) checked through UI Automation; then a light pass (`color-scheme-index=1` in the Qt settings file) with the same screenshots only | every check passes **and** every screenshot viewed and matching (review.json) |
| playback | the matrix files (below): plays (shown time advances 3 s), seeks (Ctrl+Right +60 s; the 60 s 4K file Right +10 s; read on the time label), switches the audio track (MKV: English -> Japanese) and the subtitle track (MKV: German; MP4 + external .srt: the external track) in the tracks popup, the chosen one selected afterwards; the AVI without index answers VLC's index dialog with "Play as is"; a player log per file | every file passes; screenshots viewed |
| quit | 30 starts over the matrix files, quit after 4 s of playback, odd tries Ctrl+Q, even tries WM_CLOSE | all exit within 15 s, 0 players left in the lane folder, 0 Application Error / WER / Application Hang events for the exe (Get-WinEvent, read only) |
| perf | stock VLC 4 then the build, back to back, no input (started minimized, shown without focus, 1600x900): launch -> first frame (the window centre turns to the test pattern, read from PrintWindow), CPU and private bytes over 20 s playing the MP4 and the 4K file | build <= stock + noise: startup max(150 ms, 15 %) (launch-to-launch spread in PERF.md rounds 1-3), CPU max(1 point, 2 x the per-second spread), RAM max(30 MB, 10 %) (RAM drift between runs in PERF.md); "invalid" when the PC is busy (> 30 % CPU) |
| soak | a playlist of the matrix files on loop, window off screen, no input; private bytes, working set, handles, threads, CPU every 30 s; every minute the window must respond (Process.Responding, IsHungAppWindow) and the shown time must have moved; a screenshot every 5 minutes | no crash / crash event, no freeze, no stall; private bytes after the 5 minute warm-up grow < 50 MB and trend < 60 MB/h (a leak of 1 KB per frame at 30 fps is ~108 MB/h; allocator and cache settling stays well under 50 MB), handles < +500, threads < +20 |
| footprint | read-only snapshot (path, size, time, SHA-1) of `%APPDATA%` and `%LOCALAPPDATA%` `vlc` and `Cone` (Cone's non-portable folder: src/win32/dirs.c `APP_DIR_NAME` on wip/cone-release), the installed VLC (`Program Files\VideoLAN\VLC`), the lane's build files outside `portable`, and HKCU `Software\VideoLAN`, `Software\Cone`, `Classes\Applications\Cone.exe` / `vlc.exe`, before and after the run | nothing added, changed or removed |
| branding | the exe's version info, every folder / file name of the zip (`-Zip`) or of the extracted build folder, every window title and UI Automation name (texts, tooltips, menu entries) of every screenshot of the run | no "VLC" except "based on VLC media player" / "based on VLC 4.0.0-dev" / "VLC media player by VideoLAN"; libVLC's own DLL and plugin names count as internal; no update-check banner (the public build has no update checker) |
| smoke | the MKV: plays, Space pauses, Ctrl+Right seeks 60 s, Ctrl+Down / Ctrl+Up change the volume (Volume slider), each sidebar tab, Settings open and Escape, Ctrl+Q exits | every step passes; a key that needed a second press is noted |

Playback matrix (`make_beta_media.py`, every video ffmpeg's `testsrc2` filling the frame, sine audio):
MP4 H.264 + AAC (1080p30, 3 min); MKV HEVC + 2 AAC tracks + 2 SubRip tracks (720p, 3 min); AVI
MPEG-4 Part 2 + MP3 and the same AVI without its idx1 index; MP3; FLAC; AAC (.m4a); 4K 60 fps
H.264 about 40 Mbit/s (60 s); MP4 + external `.srt` with the same name (VLC's autodetection).

### Screenshots are the verification
A UI part passes only after its screenshots were looked at: `review.json` lists every
screenshot with what it should show; for each one write what it shows (`seen`), set `viewed`
and `verdict` (`match` / `differs`), then run `report.py` again. Until then the report says
"not verified" even when every measurement passed. Start with the contact sheets, open single
shots where in doubt.

### Gate safety rules (Sticky's PC, on top of the harness rules above)
- Nothing is ever deleted: builds go into a new lane folder per build,
  `<TEST_MEDIA_DIR>\builds\verify-lane-gate-<run number>` (stock: `verify-lane-stock-<run number>`),
  copied with `robocopy /E` (never /MIR or /PURGE; a lane folder that holds another build is
  refused), without the UPnP / mDNS / SAP plugins (listening sockets: Windows Firewall prompts).
  The profile is reset by overwriting the gate's own files (`portable\vlcrc`,
  `portable\<Cone|vlc>\vlc-qt-interface.ini`); the media library and preset files stay.
- The gate writes only into `<outRoot>\gate-*`, `builds\verify-lane*` and
  `builds\test-media\beta` (`Assert-GateTarget` refuses anything else).
- Input only through the harness driver (guarded, started players only); the perf and soak parts
  send no input at all. Every player the gate started is closed after each part; a player stuck
  without a window is reported, never touched.
- Windows Firewall or other security prompts are never answered by the gate: they are reported
  for Sticky.
- The profile never adds library folders (the onboarding is never finished), so no screenshot
  shows the owner's files; the media are the generated ones only.
## Limits
- Text is rendered by Qt (ClearType, hinting) and by Figma differently: glyph weight differences
  show up as near-match, not pass. Different strings (track names, file names) are masked or made
  equal with fixtures.
- Content that depends on the test profile (toggle states, profile name, history) can differ
  from Figma; scenarios mask it or leave a human check.
- Motion (durations, easing) is not measured here; that stays the 60 fps motion check.
- Qt's UI Automation bridge reports slider ranges as 0..0, so sliders are set with the wheel or
  the time field, not with the RangeValue pattern; CSD window buttons have no accessible names
  (positions are used).
- Keys the keyboard layout cannot type (Ctrl + \ on Hungarian) stay human checks.
- The resume toast has no visible Figma frame (hidden in every Player frame): human check only.
