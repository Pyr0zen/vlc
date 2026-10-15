# Per-show presets (W4.7): notes for the PC session

Branch `redesign-presets`, from `origin/redesign` 17e765a36f (2026-10-15). Web session, no build here: nothing in this file is verified on the PC. Every item still needs the build, real screenshots side by side with the Figma PNGs, the UX pass and the regression checklist.

## 1. Status

- Built: the preset manager (C++, `RdPresets`) and the preset selector with its list and per-preset menu (QML, `PresetSelector`).
- Not hooked up: the selector only shows once the PC session adds the shared-file lines in section 5 (`mainui.cpp` and `SettingsSidebar.qml`).
- Checks run on the last commit:
  - qmlcheck `errors: 1 files: 358 crashed: 0` (the known HighResolutionTimeWidget stub);
  - buildlists `0 problem(s)`;
  - privacycheck `0 problem(s)` (generic checks only: the web session has no privacy.local.txt; run it again on the PC);
  - C++ syntax check of `rd_presets.cpp` against Qt 6.4 headers with `-Wall -Wextra -Wconversion`: clean;
  - moc on `rd_presets.hpp`: its output compiles.
- Not run here: the real compile and link, runtime QML warnings.

## 2. What was built

### The preset manager (`player/rd_presets.hpp/.cpp`, QML singleton `RdPresets`)
- **What a preset holds (Decision 18).** One preset holds every setting of the four sidebar tabs that belongs to a show. The table is `entries()` in the .cpp, about 115 settings, in the order they are applied (a filter's values before the filter is turned on).
  - **Subtitles:** delay, speed (fps), duration factor, default track and language, formatted subtitles, font, text color, outline color, outline thickness, background opacity, text size (sub-text-scale), vertical position (sub-margin).
  - **Audio:**
    - delay, stereo mode, default track and language;
    - the equalizer: on or off, preset, preamp, the 10 bands, 2 pass;
    - compressor, spatializer and stereo widener, each on or off with all their values;
    - pitch (scaletempo_pitch and pitch-shift).
  - **Video:**
    - zoom, aspect ratio, crop (list and the four pixel values);
    - HDR mode, preferred resolution;
    - flip/transform, rotate;
    - every filter of the tab with its values: adjust, sharpen, banding removal, film grain, color extraction, color threshold, negate, posterize, gradient, sepia, interactive zoom, wall, puzzle, logo, marquee, logo erase, anaglyph, mirror, psychedelic, waves, water, motion detect, spatial blur, motion blur, anti-flickering, denoiser, clone.
  - **Playback:** speed and audio visualizer. The tab's view toggles (subtitle timeline, waveform, metadata, statistics) and the sleep timer are not per show and stay out.
- **Live apply (P4-07, INTERACTIONS section 4).** Selecting a preset applies its values at once through the same calls the tabs make: RdEffects setters, the player's rate and delays, and the player's choice lists.
  - Only the values that differ are applied, so a switch costs no more than the changes it makes.
  - RdEffects sends them to VLC at most once per frame and saves the configuration on a worker thread, so playback does not wait.
  - The tabs show the new values right away, since they bind to the same cache.
- **Auto-save.** While a preset is selected, every change is kept in it, half a second after it settles. That covers the sidebar, hotkeys, the Settings dialog, and anything else that goes through RdEffects or the player. So a preset always holds what the show was last watched with.
- **Per file.** VLC resets some values for every new file: delays, subtitle speed, playback speed, zoom, aspect ratio, crop, stereo mode, visualizer. They are applied again to every file that starts:
  - once it plays;
  - again when its video or audio output appears.
  - The reset values of the new file are never saved into the preset.
- **Default Preset** always exists, with the settings VLC had when presets were first loaded. It cannot be renamed or deleted (Figma: no "..." on it).
- **Folder link (per show; Decision (Claude), see section 4)**
  - "Use for This Folder" ties a preset to the folder of the media playing.
  - When a file of that folder, or of a folder inside it, starts, it selects the preset, so the next episode comes back with the show's settings.
  - A folder uses one preset.
  - When a media outside the folders of the selected preset starts (another show), the selection goes back to Default Preset, so the show's preset does not take the other media's changes. A preset picked by hand and tied to no folder stays selected.
- **Storage:** `<VLC user data folder>/rd-presets.json`: version, the selected preset, and the presets with their values and folders.
  - Read at startup on a worker thread; until then nothing is applied or saved.
  - Written with QSaveFile on its own single worker thread.

### The selector (`player/qml/PresetSelector.qml`, Figma "Setting Preset" 2372:8834)
- **Closed:** 360x42 (the sidebar footer's width minus its padding), BG/B2, radius 6, padding 2. The 38 px row inside shows the preset's name (Inter 14 FG/A2, padding 2,14) and a chevron up. On hover the row turns BG/A2.
- **Open:** the list grows upward from the selector's bottom edge, as wide as it (Figma "state=open": the list is bottom aligned). Style: BG/A4, radius 6, padding 2, gap 2, drop shadow 35 % blur 14 at no offset. Rows are 38 px, radius 4.
  - "+ New Custom Preset" comes first, in FG/A3.
  - Then the user's presets, each with the "..." button on the left.
  - "Default Preset" comes last, with no button (Figma).
  - The selected row is BG/A2 with the accent check. Hover and the keyboard row are BG/A2 too.
  - More than 9 rows scroll.
  - The list opens and closes instantly (Figma prototype: "instant").
- **Actions:**
  - A click on a preset selects and applies it, and the list closes.
  - "New Custom Preset" copies the current settings into "Custom Preset NN" (Decision 25, Figma's names), selects it and starts renaming it in place. The list stays open.
- **Per-preset menu** (the "...", a right click on the row, or the Menu key; RdMenuPanel / RdOptionRow, Figma menu style):
  - Rename: the name becomes editable in place. Enter or a click elsewhere keeps it, Escape puts the old one back.
  - Duplicate: "<name> Copy", then renaming starts.
  - Use for This Folder: checked when the preset is tied to the folder playing. Only shown while a local file plays.
  - Delete: needs a second click ("Click Again to Delete"). Deleting the selected preset selects and applies Default Preset.
- **Keyboard:**
  - On the closed selector, Enter, Space or Up open the list.
  - In the list, Up/Down move, Enter/Space pick, F2 renames, the Menu key opens the row's menu, and Escape closes.
  - Focus goes back to the selector when the list closes.

## 3. VIDEO_INDEX rows covered

Please update their Status after the PC test. Suggested: `in progress (redesign-presets <hash>, not verified)`.

| Row | Id | What |
|---|---|---|
| 105 | P4-04 | Per-show preset selector in the sidebar's sticky footer, one preset for every tab (needs hookup 5.2) |
| 106 | IA-34 | Preset selector footer: dark selector with chevron up above "Open Advanced Settings" |
| 107 | IA-35 | Preset list style: "+ New Custom Preset", "..." per preset, selected row with check, values change at once |
| 108 | P4-05 | The list opening upward over the panel |
| 109 | P4-06 | Row icons and styling (plus icon and dimmer text on the new row, "..." icons, selected band, check) |
| 110 | P4-07 | Applying a preset changes all values at once |
| 103 | P4-02 | The Subtitles tab values a preset saves |
| 116 | P4-12 | The default subtitle track and language are saved in the preset |
| 122 | P4-15 | The default audio track and language (and stereo mode) are saved in the preset |
| 111 | P4-08 | With a folder-linked preset, the default track and language and every per-show value come back on every episode |
| 127 | P4-21 | The footer stays pinned under scrolling content (RdSidePanel already does; the selector sits in that footer) |

## 4. Decisions (Claude)

Please add these to VIDEO_INDEX.md "Decisions (Claude)".
- 2026-10-15 W4.7: the new preset row reads "New Custom Preset" (Decision 11; Figma says "New Preset"). New presets are named "Custom Preset 01", "Custom Preset 02" ... as in Figma.
- 2026-10-15 W4.7: list order as Figma: "New Custom Preset", the user's presets in creation order, "Default Preset" last. The list grows upward from the selector's bottom edge (Figma "state=open" is bottom aligned).
- 2026-10-15 W4.7: "Default Preset" has no "..." menu (Figma). It cannot be renamed or deleted, and it keeps the changes made while it is selected, like every preset.
- 2026-10-15 W4.7: while a preset is selected, every change of its settings is kept in it, from the sidebar, hotkeys and the Settings dialog alike. The video shows a preset as the saved settings of a show; it never shows a separate "save" step.
- 2026-10-15 W4.7: the per-preset menu (never opened in the video) holds Rename, Duplicate and Delete (Decision 25), plus "Use for This Folder". Delete asks for a second click. Rename and Duplicate edit the name in place in the list.
- 2026-10-15 W4.7 (per-show link, not shown clearly in the video): a preset tied to a folder is selected when a file of that folder or of a folder inside it starts. A media outside the selected preset's folders goes back to Default Preset. A preset picked by hand and tied to no folder stays.
- 2026-10-15 W4.7: the Playback tab's view toggles (subtitle timeline, waveform, metadata, statistics) and the sleep timer are not part of a preset: they are not show settings.
- 2026-10-15 W4.7: the selector is not on the Playback tab, because Figma's "playback" frame has no footer (the existing `footerVisible` rule). The preset still covers the Playback tab's speed and visualizer.

## 5. What the PC session must change in shared files

1. **`modules/gui/qt/maininterface/mainui.cpp`**: create RdPresets with the RdEffects instance. It must exist at startup, because it applies presets on playback.
   - Include, next to the RdEffects include:
     ```cpp
     #include "player/rd_presets.hpp"
     ```
   - In the VLC.Player block (line 335), replace the RdEffects registration with:
     ```cpp
     // redesign: effects and options shown in the settings sidebar, and the per-show presets
     RdEffects* effects = new RdEffects(m_intf, m_intf->p_mainPlayerController, this);
     qmlRegisterSingletonInstance<RdEffects>(uri, versionMajor, versionMinor, "RdEffects", effects);
     qmlRegisterSingletonInstance<RdPresets>(uri, versionMajor, versionMinor, "RdPresets",
                                             new RdPresets(m_intf, effects, this));
     ```
2. **`modules/gui/qt/player/qml/SettingsSidebar.qml`**: put the selector above "Open Advanced Settings" in the footer (Figma "Frame 68": Setting Preset 360x42, gap 10, Button 360x32; RdSidePanel's footer is a Column with padding 20 and spacing 10). `footer` becomes a list:
   ```qml
   footer: [
       PresetSelector {
           width: root.width - 2 * VLCStyle.dp(20)
       },
       Widgets.RdButton {
           width: root.width - 2 * VLCStyle.dp(20)
           style: Widgets.RdButton.Style.Link
           rdIcon: "settings"
           text: qsTr("Open Advanced Settings")
           onClicked: { ... unchanged ... }
       }
   ]
   ```
   Also add `import VLC.Player` to SettingsSidebar.qml (it has none yet), as AudioSettingsPage.qml in the same folder does: PresetSelector is a VLC.Player type and RdPresets a VLC.Player singleton.
3. **qmlcheck** needs no change: its stubs come from mainui.cpp, so it picks RdPresets up once 5.1 is in.
4. **Build lists** are done on this branch: Makefile.am and meson.build list `player/rd_presets.cpp/.hpp`, its moc file and `player/qml/PresetSelector.qml`.

## 6. Not done or limited

- **Options VLC reads only when a file opens** apply from the next file: subtitle font, colors, outline, background, default tracks and languages, HDR mode. This is the sidebar's existing rule (Decision 29 notice). With a folder link they are set as the episode starts, so they usually catch that episode; whether VLC picks them up that early needs the PC test.
- **Zoom, aspect ratio, crop, stereo mode and visualizer** are kept by their title in VLC's list. A change of the interface language makes an old title unknown, and it is then skipped.
- **Video filter previews** (P4-30, preset thumbnails per filter) are not part of this package.
- **Profiles** (Decision 25, "+ New" in the main menu) are a separate package. The preset store is independent of them.
- **Motion:** none to compare. The Figma prototype opens and closes the list "instant", and rows change state instantly.
- **Light theme:** all colors are palette tokens; not checked visually.
- **Offline render:** with mock modules it matched the Figma "Setting Preset" component (closed and open) while coding. That is not verification: the PC screenshots are.

## 7. Files

New:
- `modules/gui/qt/player/rd_presets.hpp`, `modules/gui/qt/player/rd_presets.cpp`
- `modules/gui/qt/player/qml/PresetSelector.qml`
- `redesign/PRESETS_NOTES.md`

Changed (build lists only):
- `modules/gui/qt/Makefile.am`, `modules/gui/qt/meson.build`

## 8. Self-review (no sub-agents, as asked)

Found and fixed while reviewing:
- **Escape while renaming:** it would have closed the list (keeping the half-typed name). It now puts the old name back.
- **Folder-linked presets:** after an episode, another media kept the show's preset and saved its own changes into it. A linked preset now hands back to Default Preset outside its folders.
- **New file's reset values:**
  - when a new file starts, its reset values (delays 0, speed 1) must not overwrite the preset. Capture is blocked from the input change until the preset is applied to the file;
  - a capture that was still pending keeps only the per-show values that do not reset per file.
- **Late video output:** the video output can appear after the file starts playing, so zoom, aspect and crop are applied again when their lists fill.

## 9. For the PC test

1. Open the sidebar on Subtitles: the footer shows "Default Preset" above "Open Advanced Settings". Compare with Figma "Setting Preset" and "Subtitles"/"Audio" frames at the same scale.
2. New Custom Preset: "Custom Preset 01" appears selected and in rename. Type a name and press Enter.
3. Change the subtitle delay, font size and an audio filter. Select Default Preset: the values go back. Select the new preset: they come back at once, without a playback stall (also while video plays at 4K).
4. Rename, Duplicate, Delete (two clicks), and Escape during rename.
5. Use for This Folder on an episode, then play the next episode: the preset is selected and its delays and speed apply. Play a file from another folder: Default Preset.
6. Restart VLC: presets, the selection and the folder links are back.
7. Keyboard only: Tab to the selector, Enter, arrows, F2, Menu key, Escape. Click outside the list: it closes, and the sidebar stays.
8. Performance: switch presets quickly while dragging nothing; the UI keeps 60 fps and the audio has no gap beyond the filter chain rebuild VLC itself makes.
