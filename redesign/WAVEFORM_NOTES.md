# Waveform seek bar (P6-06): notes for the PC session

Branch `redesign-waveform`, from `origin/redesign` 0a514865de (2026-10-15). Web session, no VLC build here: nothing in this file is verified on the PC. Every item still needs the build, real screenshots side by side with the Figma PNGs, the UX pass, the performance round and the regression checklist.

## 1. Status

- **Built:**
  - the background scanner (C++, `RdWaveformScanner`);
  - the per-file manager and its cache (C++, `RdWaveform`);
  - the bar drawing item (C++, `RdWaveformItem`);
  - the Playback tab toggle "Show Waveform on Seekbar" (QML, committed).
- **Hooked up on the PC (2026-10-15, wip/next-batch):** the patch of section 5 was applied by hand on the current SliderBar (preview card, right click, endless sliders) and deleted; the review fixes are in BUILD_NOTES.md ("W7.2 waveform seek bar merged"). Before that, the seek bar showed the waveform only after the PC session applied `redesign/WAVEFORM_HOOKUP.patch` (section 5). It touches the shared files `qt.cpp`, `mainui.cpp`, `VLCStyle.qml` and `SliderBar.qml`. Until then, the toggle writes an option VLC does not know yet (nothing happens).
- **Checks on the last commit:**
  - qmlcheck: `errors: 1 files: 369 crashed: 0` (the known HighResolutionTimeWidget stub). Same result with the hookup patch applied. A deliberately wrong property on the new item was caught, so the stubs cover it.
  - buildlists: `0 problem(s)`.
  - privacycheck: `0 problem(s)`. Only the generic checks ran: the web session has no privacy.local.txt, so run it again on the PC.
  - C++ syntax check of the six new files, and of `mainui.cpp` with the patch, against Qt 6.4 headers with `-Wall -Wextra -Wconversion`: no warnings in the new code.
  - moc output of both new QObject headers compiles.
- **Ran here (not verification):**
  - **The real scanner,** linked against a minimal VLC 4 core built from this tree (meson, no external codecs: filesystem access, wav and mp4 demuxers, copy packetizer, araw decoder). Results in section 7.
  - **The real drawing item,** rendered offscreen with Qt 6.4 at 100, 125, 150 and 200 %, next to the Figma "Player - Music" PNG. At 2x the bars land on the same device pixels as Figma.
- **Not run here:** the full compile and link of the Qt module, the runtime QML console, anything on Windows.

## 2. What was built

### Scanner (`player/rd_waveform_scanner.hpp/.cpp`)
- **What it measures.** The loudness of the file's first audio track, over 1000 equal slices of its duration.
  - Each slice gets the RMS of its samples, scaled so the loudest slice is 255.
  - Stored as 1000 bytes.
- **How it decodes.** It opens the file a second time with VLC's own modules, the same ones playback uses: access, demuxer, packetizer and audio decoder. There is no audio output and no clock.
  - The es_out reports only the measured track as selected. Demuxers that can (mp4, mkv) then skip reading the video.
  - Passthrough decoders (S/PDIF) are refused through the format callback, the same way the core falls back to a sample decoder.
  - Decoder reloads on a format change follow the core's decoder loop.
  - VLC core itself is unchanged; everything uses exported plugin API.
- **Full or sampled.**
  - Files up to 256 MB are decoded from start to end.
  - Larger files (films, long recordings) are sampled: one seek per slice (by time, else by position), then 0.25 s of audio is decoded there, never more than the slice holds. A 50 GB film costs about 1000 seeks, not a full read.
  - Without a known size the file is decoded fully. A large file whose demuxer cannot seek gets no waveform (PC review: no full read of a large file).
- **Cancel.** `cancel()` works from any thread. The scan stops within one demuxed packet, and its VLC interrupt context also aborts blocking reads.
  - Measured: a 285 MB scan cancelled after 3, 20 and 200 ms returned within 1 ms of the cancel.
- **No audio.** A file that shows no audio track within 2000 packets stops early.

### Manager and cache (`player/rd_waveform.hpp/.cpp`, QML singleton `RdWaveform`)
- **Nothing runs** until a seek bar holds it: `RdWaveformItem.active`, which the patch binds to "thick bar and option on".
- **Lowest priority.** One worker thread (`QThreadPool`, max 1 thread, `QThread::LowestPriority`). Playback and the UI never wait on it.
- **Cancelled** when the media changes, and when the last seek bar lets go (option switched off).
- **Local files only**, and only once the player knows their duration.
  - Streams, discs and network shares opened as URLs keep the plain bar.
  - A local file opened through a `file://` URL on a network drive is scanned too (see section 8).
- **Cache.** `<VLC user data folder>/waveforms/<sha1>.wf`, about 1 KB per file.
  - The key is the file's absolute path, size and modification time, so an edited file is scanned again.
  - A file with no usable audio is cached as "none", so it is not scanned on every visit.
  - A cache hit refreshes the file's time.
  - After each new entry, the least recently used files beyond 2000 are deleted. That caps the cache at about 2 MB of data.
- **Reopening** a cached file shows the waveform as soon as the worker has read 1 KB. There is no scan.

### Bars (`player/rd_waveform_item.hpp/.cpp`, QML type `RdWaveformItem`)
- **Figma Controls "Property 1=waveform" (2139:8124), "Frame 21":**
  - bars 2 px wide every 5 px, the first 6 px from the left end;
  - bar heights 2 to 14 px in 2 px steps (7 sizes), vertically centered in the 28 px trough;
  - round ends (radius 4 on a 2 px bar = a pill);
  - played bars Dark/Accent/DIm, the others Dark/FG/A4;
  - 3 px free on both sides of the 4x24 playhead.
- **Inputs from QML.** The trough and the playhead stay SliderBar's own Rectangles. The item only draws the bars, and reads the playhead's center and width from the handle.
- **Painting.** The bars are painted once into one texture: a played row and an unplayed row, one sprite per bar height.
  - Two image nodes show the rows cut at the playhead.
  - A moving playhead (playback, dragging) only moves the two cuts, and only when it crosses a bar. No painting, no upload, and no scene graph update between crossings.
  - The texture is painted again only when the size, the screen scale, a color (live accent or theme switch) or the levels change.
- **Whole device pixels at every scale.** Even bars and gaps at 125 % and 150 %, and parity-matched heights so bars stay centered on a pixel.
- **Bar heights.** Each bar takes the mean loudness of the slices under it, and the loudest bar reaches 14 px, so every window width uses the full range.

### Playback tab toggle (`player/qml/PlaybackSettingsPage.qml`)
- **"Show Waveform on Seekbar"**, a 52 px toggle row styled like Show Metadata. Figma has no frame for it; the row is the video's (Decision 13).
- **Position.** First row for now. The video puts it second, under "Show Subtitle Timeline on Seekbar", which does not exist yet.
- **Option.** It writes VLC's `qt-seek-waveform` through RdEffects, like the other option rows. A change from anywhere shows at once.
- **Default off** (VIDEO_INDEX row 146: the toggle is OFF).

### Seek bar layer (in the patch, `SliderBar.qml`)
- A `RdWaveformItem` over the trough in SliderBar's background, active while the bar is thick and the option is on.
- **When the scan is ready:**
  - the bars fade in over 100 ms (`VLCStyle.duration_short`);
  - the plain played fill fades out over the same 100 ms;
  - the playhead narrows from 8 to 4 px around the same center (100 ms).
- **Until then,** the plain bar stays as it is.
- **Unchanged.** The layer takes no input:
  - Seeking, dragging, hover, the preview card, the wheel, the keys and the right-click menu are SliderBar's, unchanged.
  - The seek to 00:00:00 (417fc21e96) is unchanged: it lives in the FSM and the player, which the patch does not touch.

## 3. VIDEO_INDEX rows covered

Please update their Status after the PC test. Suggested: `in progress (redesign-waveform <hash>, not verified)`.

| Row | Id | What |
|---|---|---|
| 146 | P4-36 | Playback tab toggle "Show Waveform on Seekbar", OFF by default |
| 213 | P6-06 | Waveform seek bar: played part in the accent, the rest grey, playhead; offered as an option |
| 212 | IB-24 | The waveform part of the row: thin bars in the black rounded trough, played in the accent, playhead taller. The 15 s skip buttons in the same row are not part of this branch |
| 210 | P6-05 | Music control bar: its seek bar shows the waveform when the option is on |

Unsure lines 655 and 671 (a second decode pass, cached; streams cannot have one) are answered by sections 2 and 8.

## 4. Decisions (Claude) to add to VIDEO_INDEX.md

One line each:
- P6-06 played bars: Figma's Dark/Accent/DIm (derived from the live accent), not Accent/Main. The playhead stays Accent/Main as in Figma.
- P6-06 bars: a fixed 5 px grid from 6 px. A live playhead cannot shift the bars the way the static Figma frame does, so the bars it overlaps are hidden whole, and the space beside it is 3 to 7 px instead of exactly 3.
- P6-06 heights: RMS loudness per slice, the loudest bar 14 px, 7 sizes (Figma's 2 to 14 in steps of 2).
- P6-06 scans: local files only; files over 256 MB are sampled (0.25 s per 1/1000 of the duration); cache capped at 2000 files.
- P6-06 switch: the bars fade in over 100 ms when the scan is ready and the playhead narrows 8 to 4 px; on a media change the plain bar shows until the next file's waveform is ready.
- P4-36: the toggle is the Playback tab's first row until the subtitle timeline toggle (P3-16) arrives above it.
- P6-05: the music layout uses the waveform only when the option is on (P6-06 offers it as an option); with it on, the music bar matches Figma "Player - Music".

## 5. PC session hookups

### 5.1 Apply the patch

Run from the repo root:
```
git apply redesign/WAVEFORM_HOOKUP.patch
```
- It applies cleanly on 0a514865de.
- If one of the four files moved on, apply the hunks below by hand.
- Then delete the patch file in the same commit, so it is not applied twice.

### 5.2 `modules/gui/qt/qt.cpp`

Next to the SEEK_THUMBNAILS texts:
```
#define SEEK_WAVEFORM_TEXT N_( "Show waveform on seek bar" )
#define SEEK_WAVEFORM_LONGTEXT N_( "The seek bar draws the audio waveform of the file playing. " \
    "Only for files on this computer: their audio is scanned once in the background and kept in " \
    "the user data folder." )
```
After `add_bool( "qt-seek-thumbnails", ... )`:
```
    /* redesign: waveform seek bar (P6-06; the Playback tab's "Show Waveform on Seekbar": off) */
    add_bool( "qt-seek-waveform", false, SEEK_WAVEFORM_TEXT, SEEK_WAVEFORM_LONGTEXT )
```

### 5.3 `modules/gui/qt/maininterface/mainui.cpp`

Includes, after `player/rd_seek_thumbnailer.hpp`:
```
#include "player/rd_waveform.hpp"
#include "player/rd_waveform_item.hpp"
```
In the `VLC.Player` block, after the RdSeekThumbnailer registration:
```
        // redesign: waveform seek bar (P6-06): the playing file's waveform, and its bars
        qmlRegisterSingletonInstance<RdWaveform>(uri, versionMajor, versionMinor, "RdWaveform",
                                                 new RdWaveform(m_intf, m_intf->p_mainPlayerController, this));
        qmlRegisterType<RdWaveformItem>(uri, versionMajor, versionMinor, "RdWaveformItem");
```

### 5.4 `modules/gui/qt/style/VLCStyle.qml`

After `rd_seekHandleWidth`: the eight `rd_waveform*` tokens.

| Token | Value |
|---|---|
| `rd_waveformBarWidth` | 2 |
| `rd_waveformBarSpacing` | 3 |
| `rd_waveformBarMinHeight` | 2 |
| `rd_waveformBarMaxHeight` | 14 |
| `rd_waveformBarStep` | 2 |
| `rd_waveformPadding` | 6 |
| `rd_waveformPlayheadWidth` | 4 |
| `rd_waveformPlayheadGap` | 3 |

Each is `MainCtx.dp(n, scale)`.

### 5.5 `modules/gui/qt/player/qml/SliderBar.qml`

Four edits, all in the patch:
1. **Properties,** after `scrubPosition`:
   - `_waveformOption`, which reads `qt-seek-waveform` through RdEffects;
   - `waveformShown: waveform.ready`.
2. **`progressRect`:**
   - `visible: (control.thick || !Player.hasChapters) && opacity > 0`;
   - `opacity: control.waveformShown ? 0 : 1`;
   - a 100 ms Behavior on opacity.
3. **The layer,** before `bufferRect` in the background: the `RdWaveformItem { id: waveform ... }` block. It sets:
   - `source: RdWaveform`;
   - `active: control.thick && control._waveformOption`;
   - `playheadX: sliderHandle.x + sliderHandle.width / 2`, plus `playheadWidth` and `playheadGap`;
   - `playedColor: VLCStyle.palette.rdAccentDim`, `unplayedColor: VLCStyle.palette.rdFgA4`;
   - the six bar tokens;
   - a 100 ms opacity fade.
4. **`sliderHandle.implicitWidth`:**
   - `rd_waveformPlayheadWidth` while `waveformShown`, otherwise `rd_seekHandleWidth`;
   - a 100 ms Behavior that is enabled only while the bar is thick. The thin bar keeps its state transitions.

### 5.6 Nothing else

- The build lists already have the six new files.
- The Settings dialog's Playback page (redesign-settings) has no waveform row. If one is wanted there later, it is one more RdEffects option row on `qt-seek-waveform`.

## 6. Files changed

**New:**
- `modules/gui/qt/player/rd_waveform_scanner.hpp`, `.cpp`
- `modules/gui/qt/player/rd_waveform.hpp`, `.cpp`
- `modules/gui/qt/player/rd_waveform_item.hpp`, `.cpp`
- `redesign/WAVEFORM_HOOKUP.patch`
- `redesign/WAVEFORM_NOTES.md`

**Changed:**
- `modules/gui/qt/meson.build`: moc headers and sources.
- `modules/gui/qt/Makefile.am`: sources and `.moc.cpp`.
- `modules/gui/qt/player/qml/PlaybackSettingsPage.qml`: the toggle row.
- `redesign/INTERACTIONS.md`: section 5, the waveform layer.

## 7. Tests run here

### Scanner

The real `rd_waveform_scanner.cpp` was linked against libvlccore built from this tree. The test files were generated: a 1 kHz tone whose loudness rises linearly to the middle and falls back.

| File | Path | Result | Time |
|---|---|---|---|
| WAV, 60 s, 10 MB | full | 1000 slices: 0, 25, 51 ... 255 ... 51, 25 | 12 ms |
| MOV, MJPEG video + PCM audio, 60 s, 21 MB | full; video not read | same profile | 16 ms |
| WAV, 27 min, 285 MB | sampled | same profile | 68 ms |
| WAV 285 MB, cancelled after 3 / 20 / 200 ms | sampled | empty | stopped within 1 ms |
| MOV, video only | full | empty (no audio) | 0 ms |
| random bytes | no demuxer | empty | 0 ms |
| missing file | | empty | 0 ms |

- All runs were repeated under AddressSanitizer with leak detection: no errors, no leaks.
- These are a minimal build's modules. Real files go through avcodec, mkv and so on, on the PC (section 9).

### Bars

Offscreen render of `RdWaveformItem` (Qt 6.4) with the Figma frame's 244 bar heights as levels, compared with "Player - Music.png" (2x):
- The bars start and repeat on the same device pixels (12-15, 22-25, ... at 2x).
- The heights and round ends match.
- At 125 % the bars are 3 device pixels wide with a 6 px pitch (2.5 px cannot be drawn evenly). At 150 % they are 3 px wide with an 8 px pitch.
- This is not verification: the real check is a screenshot of the built VLC.

## 8. Performance risks to measure first (PERF.md)

The marks in VLC's debug log (verbosity 2, added on the PC): `waveform: job started for the playing file` (GUI thread: the option is on and a thick seek bar shows it), `waveform scan (full|sampled|large, not seekable|no duration): levels|no waveform|no waveform, over the time budget|cancelled in N ms` (the scan alone, worker thread; the scan line comes from the libvlc instance, `main libvlc debug`) and `waveform: ready|no waveform from the cache|from the scan, N ms after the job started` (GUI thread: the bars' data arrived). A scan stops after 60 s (`kTimeBudgetSeconds`; the file is then cached as "no waveform"), and quitting waits at most 500 ms for a cancelled one.

1. **The scan while playing a large local video.**
   - The sampled scan seeks through the same file the player reads. On a hard disk, the head moves between both, so watch for dropped frames during the first seconds of a 4K file with the option on.
   - Expected: about 1000 short reads at the lowest thread priority. If it shows, delay the scan start until playback has buffered (a few seconds), or lower the sample count.
2. **A full scan of a 256 MB file** (the upper bound of the full path, e.g. a long FLAC or an episode).
   - It is CPU bound on one low priority thread. Measure the time to ready, and CPU while playing.
   - If it takes too long, lower `kFullScanMaxBytes` so more files are sampled.
3. **Seek bar frame times while playing and dragging,** with the waveform shown: should be the same as the plain bar.
   - Only the cuts move, and only when the playhead crosses a bar.
   - Check QSG_RENDER_TIMING for texture uploads during playback: there should be none.
4. **Window resize:** each new width paints the texture again.
   - That is one sprite blit per bar, about 700 at 4K.
   - Watch the worst frame while dragging the window edge.
5. **Startup and opening a file:** nothing runs while the option is off.
   - With it on, opening a file starts one worker job.
   - Opening a file should stay the same as stock VLC.
6. **A network share** opened as a local path (a mapped drive) is treated as a local file and read a second time. Check that this is acceptable on a slow share.

## 9. UX pass and tests for the PC

- **The toggle:**
  - on and off, live, over a playing file, in the sidebar;
  - the bars appear or disappear without a jump in the bar's size;
  - the option survives a restart.
- **Timing:**
  - first open of a file: the plain bar, then the bars fade in;
  - reopen: the bars show at once.
- **Media switching:**
  - next and previous in the queue cancel the old scan;
  - each file shows its own waveform;
  - rapid next/next/next leaves no stale waveform.
- **Seek bar behavior, all unchanged with the waveform shown:**
  - seeking, dragging (also past both ends), hover;
  - the preview card;
  - wheel, arrow keys, Shift-precise drag;
  - the right-click menu;
  - a seek to 00:00:00;
  - chapters (the thick bar does not draw chapter segments today).
- **Live colors:**
  - every accent color recolors the played bars at once;
  - the light theme uses Light FG/A4 and the light Accent/DIm.
- **Scaling:**
  - 100, 125 and 150 % Windows scaling: even bars, no blur;
  - fullscreen and a narrow window (the seek bar minimum is 76 px: no bars below about 14 px).
- **Media types:**
  - audio only (the music layout);
  - a video with several audio tracks (the first track is measured);
  - a file with no audio (plain bar);
  - a stream (plain bar);
  - a very long file (sampled).
- **Side by side:**
  - the music layout against "Player - Music.png" and "Player - Music-1.png";
  - the video bar against Controls "Property 1=waveform".

## 10. Not done, or limits

- **Not verified on the PC, nothing.** No runtime QML console here.
- **The audio track** is the first audio track of the file, not the track selected in the player. Following the selected track would need a rescan per track. That is possible, but the video does not show it.
- **No progressive drawing:** the bars appear when the whole scan is ready, as asked. A long full scan shows the plain bar until then.
- **Streams, discs and remote URLs** never get a waveform (VIDEO_INDEX line 671).
- **Real codecs** (MP3, AAC, FLAC, Opus, AC-3, DTS and so on) were not run here: the minimal build has no avcodec. The decoder path is the core's, so they should behave like the araw decoder. Check a few on the PC.
- **The prototype's click on the seek row** that toggles the waveform (FIGMA_FLOWS line 23) is a demo shortcut and was not built. The option is the real trigger.
