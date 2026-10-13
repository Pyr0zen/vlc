# PERF: performance and motion log

Sticky's rule (CLAUDE.md, Quality rules): the redesign must feel at least as snappy as stock VLC.
Every build round is measured on this PC against stock VLC 4 (Phase 1 build, run 38315049322),
both in portable mode, same media, on a quiet machine. A regression on any target stops
everything, like a crash.

## How to measure
- `redesign/tools/perf/vlcperf.ps1 -Build <build dir> -Kind stock|redesign -Out <json>` runs every
  scenario (startup, open, play, idle, panel, seek, motion, 4k, queue); results go into the
  tables below. It refuses to run when the PC is busy (> 15 % CPU before starting).
- PC: 8 logical cores, NVIDIA RTX 2060, 2560x1440 at 99 Hz, Windows scaling 125 %; window
  2400x1350 physical (1920x1080 logical). Media: `<TEST_VIDEO>` (2560x1440 H.264),
  `perfmedia\4k60_80mbps.mp4` (3840x2160 60 fps, about 80 Mbit/s, generated with ffmpeg),
  `perfmedia\queue500.m3u` (520 entries).
- Smoothness: VLC renders its QML through its own compositor (QQuickRenderControl), so
  QSG_RENDER_TIMING prints nothing, and VLC's Qt has no QML profiler. Instead the screen is
  captured with Desktop Duplication (ffmpeg ddagrab, 120 fps, only changed frames, GPU present
  timestamps) during scripted interactions on a paused video; `motion.py` gives the input-to-
  first-change latency and the gaps between UI updates. On the 99 Hz monitor a smooth update is
  every ~10 ms; a gap over 16.7 ms is below 60 fps.
- CPU from the process times, RAM private bytes, GPU from nvidia-smi (whole GPU and the video
  decoder; valid because the machine is quiet). Dropped frames from VLC's own statistics (cli
  interface on 127.0.0.1, `stats`: frames displayed / lost).

## Targets
| Target | Measure | Limit |
|---|---|---|
| UI never below 60 fps (hover, panels, popups, seek/volume drag, list scroll) | worst gap between UI updates during the interaction | <= 16.7 ms, and no worse than stock |
| Clicks and keys react instantly | input to first visible change | <= 1 frame (~10-17 ms) plus the stock baseline |
| Animations short | measured duration | Figma duration, else 150-200 ms |
| Startup / open file | launch to window / launch to first video frame | no worse than stock |
| CPU, GPU, RAM (playing, idle, panels open, seeking) | averages | close to stock; any big gap is a bug |
| 4K / high bitrate, windowed and fullscreen | frames lost (VLC stats) | no more than stock |
| 500+ item queue | open latency, scroll gaps | smooth (as above) |

## Rounds
(numbers to be filled by the first quiet-machine round: stock run 38315049322 vs redesign)

## Motion measurements
| Element | Source | Measured | Built |
|---|---|---|---|
| Main "..." menu open | video 5:08.15-5:08.40 (unedited prototype stretch), 60 fps | opacity fade, no slide, about 7 frames = ~115 ms (steps every 3-4 frames suggest a lower-fps capture) | 120 ms OutQuad fade in (`rd_menuFadeDuration`), close instant |
| Submenu open | video 19:30.45-19:30.80 | instant (absent at frame 13, complete at 15) | instant |
| Right-click menu | video 5:13-5:30 | no usable motion (meme cut, magic-wand edit effect) | same 120 ms fade as the main menu |
| Dialogs (Open Network Stream, Settings, Keyboard Shortcuts) | Figma prototype: overlays open instantly; video fades are edits | instant | instant (Decision 32) |
| Settings sidebar open | video 7:10-7:13 | editing only (dissolve of the old Effects window, then a camera zoom) | instant (no Figma transition) |
| Library open | Figma prototype | smart animate "slow" 208 ms | (Phase 5) |
| Hide UI | Figma prototype | smart animate ease-in-and-out 300 ms | to check against the perf cap with Sticky |
| Volume drag | Figma prototype | smart animate ease-in-and-out 300 ms | to check |
| Mini player | Figma prototype | smart animate ease-out 300 ms | (Phase 5) |
| Customize drags | Figma prototype | 50 ms | (W8.1) |
