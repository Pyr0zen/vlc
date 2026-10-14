# SETTINGS_NOTES: Settings dialog category pages (W6.2), web session

Branch `redesign-settings`, branched from `redesign` (10b542199c). Built by the web session; the PC session reviews, merges, builds and tests it (CLAUDE.md "Parallel work"). Draft PR: https://github.com/Pyr0zen/vlc/pull/2. Nothing is marked verified in VIDEO_INDEX.md.

## 1. Status

- All 13 category pages are built and wired to VLC's real options. The Add Subtitles dialog (W6.5) is excluded, as asked.
- qmlcheck (PySide6 6.8.3): `errors: 1` (the known HighResolutionTimeWidget stub limit), `crashed: 0`, 318 files. Every new file imports what it uses.
- C++: syntax and type checked here against VLC's headers with Qt 6.4 headers (the only Qt in this container); the `_WIN32` parts (registry) could not be compiled here. Nothing was compiled, linked or run: the first real compile is the CI build after the merge.
- Independent review: see section 8.

## 2. What was built

**Settings bridge use.** Every row reads and writes VLC's options through `RdEffects` (the bridge of the settings sidebar): a change applies at once where VLC allows it, is saved in VLC's configuration, and the sidebar and the dialog stay in sync. Equalizer, picture and audio effects use the sidebar's own RdEffects calls.

**C++ (new): `dialogs/redesign/settings/settings_catalog.{hpp,cpp}`, singleton `SettingsCatalog` (VLC.Dialogs)**
- Files every option of VLC and of its plugins under one of the 13 categories, from the category VLC itself gives it (VLC subcategory to Settings category table in the .cpp; a few plugins are placed by name: loggers to General, Lua to Extensions, Last.fm to Privacy, media library to Library, GnuTLS to Network). Options VLC hides or never saves (internal, volatile, obsolete) and hotkeys (edited in Keyboard Shortcuts) are left out, as in VLC's own preferences.
- The rows the pages show by name (`curatedOptions()`) are left out of the generated lists, so no option shows twice.
- Read once on a worker thread, the first time a page's Advanced Options opens or the dialog's search runs.
- Also: the plugin list (name, capability, score), `describe(option)` (type, texts, range, default), file and folder pickers, the configuration folder, Reset all settings (VLC's `config_ResetAll` + save), clearing the history (media library), the interface language (Windows registry, as VLC's preferences).

**QML components (new, `dialogs/redesign/settings/`)**
- `SettingsOption`: a row bound to one VLC option. The control follows the option's type (toggle, dropdown in words, number with unit, slider, text, password, file / folder with Browse, color hex + swatch) unless the page names one; VLC's explanation in the info popover; hidden when this build of VLC has no such option; `restartRequired` adds "VLC uses this setting the next time it starts." to the popover.
- `SettingsMoreOptions`: the last section of each page's Advanced Options, "All Other Options": every remaining option of the category, one collapsed row per plugin (with its number of settings); a plugin's settings are created when it is opened. The dialog's search finds a plugin by any of its settings.
- `SettingsOptionGroup`, `SettingsPluginList` (Extensions > Advanced: Name / Capability / Score in a 360 px list with its own search), `SettingsAccentPicker` (nine square swatches, Decision 15 colors, live through `MainCtx.accentColor`), `SettingsEqualizer` (inline equalizer: Open / Close Equalizer, preamp and ten vertical band sliders with value boxes, Figma "EQ"), `SettingsLanguageOption` (track languages in words), `SettingsInterfaceToggle` (VLC extra interfaces: Last.fm, web remote, as `config_AddIntf` / `config_RemoveIntf`).

**Pages (`dialogs/redesign/settings/pages/`)**: rows and order from the Figma frames ("Settings - *"), wording from the video where it differs (Decision 11), values in words.
- General: interface language (Windows), Theme (Dark / Light / System through `MainCtx.colorScheme`, instant), Accent color (live), Startup, Diagnostics (logging), Advanced: minor warnings, log format, statistics, configuration folder, Reset all settings, Developer Options (system log; Linux/BSD only).
- Interface: skin, window, playback controls (Decision 30: "Auto-hide the controls" = VLC's pin controls), tray and notifications, playlist; Advanced: opacity, minimized pause, raising, cover art, open dialog, app icon, fullscreen controls opacity and sensitivity, menu bar, interface size, smooth scrolling, blur, picture-in-picture, safe area.
- Privacy: history, remember position, Clear history, internet metadata, ask about internet access, Last.fm (no Advanced Options, as the video and Figma).
- Controls: Edit Keyboard Shortcuts (opens the dialog), Reset all shortcuts (HotkeysModel), skip amounts, single click, scroll wheels and reverse direction in words, web remote with port and password; Advanced: mouse / key handling on the video, media keys.
- Playback: continue where you left off, autostart, default speed slider, cork; video quality, menu language, default tracks in words; repeat (Off / All / One) and end of list (Stop / Pause on the last frame / Quit VLC); precise seeking; optical drive, AVI repair, MKV preload; Advanced: time-shift folder and size, start paused, playback states, default video track, audio CD drive.
- Video: output, picture sliders (the sidebar's adjust filter) and Reset picture, deinterlacing, framing in words, snapshots; Advanced: custom ratios, monitor PAR, video output, filters, zoom factor, black and white, decorations.
- Audio: output, device of the output in use, speaker setup; maximum volume, startup volume (stacked choice, Figma "Values"), volume step in %; loudness, replay gain; Effects: equalizer toggle, preset, inline equalizer, two-pass, spatial audio and its mode, stereo widening, compressor, pitch shift, chorus/flanger, karaoke; track language and delay; visualizer; Advanced: passthrough, Dolby detection, resampler, media role, visualization size, output module, time stretch, stereo mode, gain, audio filters.
- Subtitles: enable, language, encoding; automatic loading and file name matching in words (P7-17); font, Size values (Relative words / Precise percent), font size, bold, colors, opacities, outline, shadow, background, vertical position; delay (bipolar slider); on-screen messages; Advanced: folders, shadow angle, text direction, monospace font, title position, alignment, second subtitles.
- Library: one window and its two dependent rows (dimmed while off, video 18:15), folders in words, hidden files, metadata, media library; Advanced: preparsing, ignored extensions.
- Network: Buffering in words (Low latency / Normal / More buffering / Custom; the four sizes dimmed until Custom), proxy, certificates, ciphers in words; Advanced: connection timeout, MTU.
- Performance: hardware decoding, post-processing and loop filter in words, threads; late frames, priority; Advanced "Developer": decoder, clock options.
- Recording: recording folder and native recording, cast quality, stream out tracks, x264 preset and tuning in words; Advanced: keep / all tracks, H.264 profile and level.
- Extensions: the add-ons VLC manages (VLC's add-ons model, `ServicesDiscoveryModel`): installed list, search, Find more extensions (VLC's online catalog), Add (selected catalog add-on, or a `.vlp` package file / drop), Remove (with confirmation), Load extensions on startup; Advanced: plugins list (P8-20).
- Every page ends its Advanced Options with "All Other Options" (except Privacy, which has none).

**Snappiness**: pages load when first shown (dialog shell); the catalog is read once off the UI thread; the generated lists are built once (asynchronous Loader) and never rebuilt on keystrokes; a plugin's rows exist only while it is open; the plugin and add-on lists create rows as they scroll in; no timers.

**Opaque bodies**: every panel and popup these pages add is opaque (equalizer BG/A4, lists BG/B2, accent strip BG/B2, dropdown lists BG/A4 from the kit). The info popover is the shared `Widgets.RdTooltip`, still on `rdBgB1Transparent` (section 5).

## 3. VIDEO_INDEX rows covered

Status: **built** = coded on this branch, needs the PC test; **partly** = built, with the limit named in section 6; **PC** = needs a shared-file change (section 5).

| Rows | Status | Where |
|---|---|---|
| P7-14 (basic first, advanced below on one page), P8-45 | built | every page; "All Other Options" |
| P7-15 (every setting has a place, none repeated) | built | SettingsCatalog, curated list |
| P7-16, P8-21 (info icon on every setting) | built | SettingsOption (VLC's descriptions) and own descriptions on custom rows |
| P7-17, IB-41, P8-01 (words instead of numbers) | built | Subtitles "File name matching" and every dropdown |
| P3-22 (exact font sizes) | partly | Subtitles "Size values" Relative / Precise (section 6) |
| P8-03 General, P8-22 Advanced Options rows | partly | General (section 6: command line options) |
| P8-04, P8-41 theme | built (instant switch is the palette's) | General > Theme |
| P8-05, P8-42, IB-43 accent | built | SettingsAccentPicker |
| P8-06 Interface | partly | (section 6: window size memory, popup duration) |
| P8-07 Privacy | partly | (section 6: "Never remember items matching") |
| P8-08 Controls | partly | (section 6: double click) |
| P8-09 Playback | partly | (section 6: thumbnail while scrubbing) |
| P8-10 Video | built | |
| P8-11 Audio, P8-44 inline equalizer, IB-45 slider variants | partly | (section 6: night mode) |
| P8-12 Subtitles | partly | (section 6: OSD feedback duration, ASS styling) |
| P8-13 shortcut shown in OSD | not built | needs a core change (section 6) |
| P8-14 Library | built | |
| P8-15 Network | built | |
| P8-16 Performance | partly | (section 6: process priority, rescan, encoder) |
| P8-17 Recording | partly | (section 6: discover cast devices) |
| P8-18 Extensions, P8-19, P8-20 add-ons vs plugins | built | |
| P8-43 control styles | built (Rd kit) | |
| F-19 switching | built (dialog shell + pages) | |

Rows of the dialog shell (P7-18, IB-42, P8-02, P8-39, P8-40) and the Keyboard Shortcuts dialog (P7-12, IB-40) were done on `redesign` before this branch.

## 4. Decisions (Claude) to add to VIDEO_INDEX.md

- Every VLC option has a place: the page's curated rows first, then under Advanced Options "All Other Options", one row per plugin, from VLC's own category of each option. "All VLC Settings" (VLC's old preferences) stays in the dialog as before.
- Developer mode = VLC's "qt-verbose" (debug messages of the interface); Developer Options are always under Advanced Options (as in Figma, where they show with Developer mode off).
- "Show confirmation and error dialogs" = "interact"; "Show minor warnings" = "qt-error-dialogs".
- Font size: VLC 4 has no pixel font size ("freetype-fontsize" is obsolete); "Size values" is Relative (Smaller / Small / Automatic / Large / Larger) or Precise (exact percent of VLC's size, "sub-text-scale").
- Track languages: Automatic (VLC's default), System language (the system's code), then languages by name (ISO 639-1 codes).
- Auto-hide the controls: Always = VLC's pin controls off, In fullscreen only = on (Decision 30).
- Remember the playback position (Privacy) is ON = Always; Playback > Continue where you left off has Never / Ask / Always.
- Spatial audio: VLC's headphone virtualization filter or the room spatializer, chosen by "Spatial audio mode".
- Reverse scroll direction reverses wheels set to Seek (VLC's "Position control reversed").
- Accent: the first swatch writes VLC's orange explicitly.
- Extensions page keeps the video's words ("Extensions", "Load extensions on startup", Decision 11).
- Performance: "Give VLC high priority" (VLC's "high-priority" raises the process priority, it is not real-time).
- Recording: Cast quality uses VLC's levels (High / Medium / Low / Low processor use); there is no "Automatic".

## 5. What the PC session must change in shared files

1. `maininterface/mainui.cpp`: this branch adds one include and one registration line (`SettingsCatalog` singleton in the VLC.Dialogs block); without it no page can list VLC's options or plugins. Review it with the merge. Build lists (`Makefile.am`, `meson.build`) register the new C++ and QML files.
2. `widgets/qml/RdTooltip.qml` (the info popover) still uses `rdBgB1Transparent`: make it opaque like the other popups (`Qt.alpha(..., 1.0)`), so it never shows the video through where it passes the dialog's edge.
3. Palette: a red text token for the "Reset all settings" button (Figma red text, P8-43); until then it uses the standard button.
4. `widgets/qml/RdSegmented.qml` (Theme, Size values, sensitivity) is mouse-only: give it keyboard focus and arrow keys.
5. When the seek-bar thumbnails (P2-04) are built, add their option and a "Show thumbnail while scrubbing" SettingsOption row to Playback > Seeking.
6. VIDEO_INDEX.md: set the rows of section 3 to "in progress" (built, unverified) at the merge; add the decisions of section 4.

## 6. Not done / limits

Rows of the design without a VLC option behind them (left out rather than shown without effect):
- General > Advanced "Additional command line options": VLC keeps no such setting.
- Interface "Remember window size and position" (VLC 4 always remembers), "Popup duration" (no option).
- Privacy "Never remember items matching" (VLC 4 removed the filter).
- Controls "Double click on the video" (always fullscreen in VLC).
- Playback "Show thumbnail while scrubbing" (the feature is not built yet; section 5).
- Audio "Night mode" (no VLC option; the compressor row is the closest).
- Subtitles "Show feedback for (duration)" and P8-13 (the shortcut shown in on-screen messages): need a core change (Decision 27, own build); "Ignore styling in ASS and SSA subtitles" (no option).
- Performance "Process priority" (only "high-priority" exists), "Rescan plugins" (VLC rescans at every start; its options are not saved), "Encoder" (obsolete in VLC 4).
- Recording "Discover cast devices" (discovery runs while the cast menu is open).
- Extensions: "Add" installs catalog add-ons or reads a `.vlp` package; loose Lua files cannot be installed (no VLC API).
- Reset all settings resets VLC's options (the accent color included); the interface's own state kept outside them (window layout, library, pins) stays, unlike VLC's old Reset Preferences which also cleared it.
- The Windows-only code (registry language) was not compiled here.

## 7. Files

New C++: `dialogs/redesign/settings/settings_catalog.{hpp,cpp}`.
New QML: `dialogs/redesign/settings/SettingsOption.qml`, `SettingsOptionGroup.qml`, `SettingsMoreOptions.qml`, `SettingsPluginList.qml`, `SettingsAccentPicker.qml`, `SettingsEqualizer.qml`, `SettingsLanguageOption.qml`, `SettingsInterfaceToggle.qml`.
Rewritten pages: all 13 in `dialogs/redesign/settings/pages/`.
Changed shared files: `maininterface/mainui.cpp` (registration), `Makefile.am`, `meson.build`.
Not touched: the dialog shell (SettingsDialog, SettingsPage, SettingsRow, SettingsSection, ...), the palette, MainCtx, RdEffects, the widgets.

## 8. Independent review

REVIEW_PLACEHOLDER
