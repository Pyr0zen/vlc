# Sheet confirmations (verify sheets, run 20261016-204509-round)

These are the 45 contact sheets in `redesign/verify-sheets/` (public build 38890442361), each read Figma column against Build column and checked against the spec (`redesign/tools/verify/spec/`) and the page code where a value was unclear on the 1100 px sheet. They were read in a cloud session from the committed sheets only, so they cover the look; behaviour needs the PC. VIDEO_INDEX is not edited: the PC session merges these results.

Allowed and not counted as differences:
- sample content (file names, counts, durations, the clip title);
- the run's demo state (Subtitle Track Delay 0.000 s instead of -4.000 s, option values such as skins or cast discovery left at their defaults, one queue item, no bookmarks);
- differences a Decision covers:
  - "All Cone Settings" (Decision (Claude) W6.1);
  - info icons on every row (W6.2 / P7-16);
  - the OpenSubtitles section (W6.5);
  - "Precise" instead of "Pixels" (W6.2 / P3-22);
  - "Extensions & Scripts" and "Load extensions on startup" (Decision 11);
  - "Give Cone high priority" and the Process priority dropdown (W6.2, Decision 35);
  - rows that depend on an option that is off drawn at 30 % (W6.1);
  - Cone in place of VLC (Decision 48).

Verdicts: **matches**, **differs** (element, expected, actual) or **unclear** (the sheet doesn't show the row's element, or the run's state hides it).

## Summary

| Group | Sheets | Matches | Differs | Unclear |
|---|---|---|---|---|
| settings-dialogs | 26 | 19 | 3 | 4 |
| sidebars-menus-panels | 19 | 5 | 3 | 11 |
| **Total** | **45** | **24** | **6** | **15** |

**Differences found**
- **General page, Log details:** the dropdown reads "Errors", Figma reads "Errors only" (`SettingsGeneralPage.qml:149`; spec settings-global "Errors only" at 720, 593.5).
- **Privacy page, extra row:** the build has "Ask about internet access when Cone starts" between "Fetch titles and cover art from the internet" and "Submit played tracks to last.fm". Figma has no such row and no Decision covers it.
- **Subtitles page, default values:** Preferred language reads "Automatic" where Figma reads "System language" (`SettingsLanguageOption.qml:80`: the empty value is labelled Automatic and the system language is a separate entry). Text encoding reads "Default (Windows-1252)" where Figma reads "Automatic".
- **Sidebar Subtitles tab, Defaults note:** an extra "Applies from the next file" line sits under the Defaults header (Figma has none, and Decision (Claude) W4.6 covers only the Appearance note). It moves every row of the tab about 17 px down.
- **Queue panel, title position:** queue row titles start about 6 px left of Figma (Figma x 42 in the row: 32 px handle frame plus 10 px gap; build about 36).
- **Chapters tab, title position:** titles start right after the number box with no gap (Figma x 48 in the row, build about 38).

**Problems with the harness run itself (for the next run)**
- **Main menu crops:** they show the library rail instead of the open "..." menu. The menu didn't open before the capture (sheet P6-10), so every main-menu panel on IB-31, IB-36 and IB-42 compares nothing.
- **Weak auto-passes:** five weak or derived rows matched an icon of the right-click menu, not the row's own element (F-18, IA-40, IB-19, and the menu crops of IB-31 / IB-36 / IB-42).
- **Wrong elements:** IB-20 and IB-36 in settings-dialogs compare Settings category icons and Advanced Options chevrons, not the music sub-category icons and sidebar tab glyphs their rows are about.
- **Missing elements:** F-23 (Show Statistics) shows the Subtitles tab instead of the Playback tab, and P3-23 (Size Values) is cut off above the control.

## settings-dialogs (26)

| Row | Item | Verdict | What was compared |
|---|---|---|---|
| IA-05 (#15) | Third icon state: solid orange = active/toggled | matches | the 10 active category icons (General to Library) are solid accent with the same shapes as Figma |
| IA-29 (#93) | Sidebar typography and input style | matches | Settings page labels, section headers, value boxes and dropdowns; rows below Loading Subtitles move down because of the allowed OpenSubtitles section. The sidebar sheet of this row differs (see below) |
| IB-20 (#206) | Music sub-category icons | unclear | the sheet compares the Settings category icons, not the library's music sub-category icons; the category icons match |
| IB-36 (#249) | Right sidebar tab glyphs and states | unclear | the sheet compares Advanced Options chevrons, not the sidebar tab glyphs; the chevrons match |
| IB-42 (#269) | Settings category nav in the zoom | matches | 13 categories under App / Media / System, icons, labels, active row fill and accent icon; extra "All Cone Settings" allowed |
| IB-43 (#272) | Accent swatches: square in Settings, round in Onboarding | matches | Settings half only: 9 square swatches, the first one selected; the round onboarding swatches aren't on the sheet |
| P3-02 (#72) | Problem: subtitle file names do not match video names | matches | File name matching dropdown in words ("Title with extra characters") |
| P4-33 (#143) | Playback tab: Reverse toggle | unclear | the sheet compares the toggles of the Settings pages; the Reverse toggle is not built (reverse playback postponed by Decision 29). The toggle style (knob, ON / OFF, colours) matches on every page |
| P7-16 (#264) | Setting explanations visible via info icon | matches | info icon after each label; extra icons on rows without one in Figma allowed |
| P7-17 (#265) | Subtitle autodetection fuzziness as human-worded dropdown | matches | worded File name matching dropdown |
| P7-18 (#268) | New settings category list (start) | matches | category list on every page sheet, active row per page |
| P8-01 (#267) | Use words, not numbers, in dropdowns | matches | dropdowns show words (Automatic, Title with extra characters, Normal) |
| P8-02 (#270) | Settings window layout and category list | matches | window, header with search and close, category column, page column, Advanced Options bar; the Log details wording is listed under P8-03 |
| P8-03 (#273) | General page ("Global Settings") | differs | Log details dropdown: expected "Errors only", actual "Errors". Rest matches; Interface language "System language" instead of "English" is the run's value |
| P8-04 (#276) | Light theme | unclear | the sheet shows the dark theme only; the Dark / Light / System control matches, the light theme itself isn't captured |
| P8-05 (#279) | Accent color setting | matches | Accent color row with 9 square swatches, the selected one outlined |
| P8-06 (#281) | Interface page ("Interface Settings") | matches | rows, order and controls of Skin, Window, Playback Controls; "Use a custom skin" OFF is the run's value and dims Skin file (allowed) |
| P8-07 (#282) | Privacy page ("Privacy Settings") | differs | extra row "Ask about internet access when Cone starts" in Network (not in Figma, no Decision), which moves the last.fm rows down. The last.fm rows dimmed while submitting is off are allowed |
| P8-12 (#289) | Subtitles page ("Subtitle Defaults") | differs | Preferred language: expected "System language", actual "Automatic". Text encoding: expected "Automatic", actual "Default (Windows-1252)". OpenSubtitles section and "Precise" allowed |
| P8-15 (#293) | Network page ("Network Connections & Security") | matches | Buffering, Proxy, Security rows and controls; the caching fields show their values where Figma is empty |
| P8-16 (#294) | Performance page ("Performance Settings") | matches | Decoding, Smooth Playback, Developer rows; priority wording and dropdown allowed |
| P8-17 (#295) | Recording page ("Recording, Casting & Streaming Out") | matches | Recording, Casting, Streaming rows and controls; folder text, cast quality and discovery are the run's values |
| P8-18 (#296) | Extensions page ("Extensions & Scripts") | matches | list, search, Find more extensions / Add / Remove, startup toggle; wording allowed |
| P8-20 (#298) | Add-ons vs plugins split | matches | same page as P8-18 |
| P8-21 (#299) | Info icon on every setting | matches | an info icon on every row |
| S2-09 (#358) | Performance > Advanced Options > Developer: "Encoder" | matches | Encoder dropdown "Automatic" as the first Developer row, above Decoder |

## sidebars-menus-panels (19)

| Row | Item | Verdict | What was compared |
|---|---|---|---|
| F-18 (#344) | Crop link toggle | unclear | the single element is the audio icon of the right-click menu, not the crop link |
| F-23 (#349) | "Show Statistics" toggle in the Playback tab | unclear | the sheet shows the Subtitles tab; the Playback tab toggle isn't captured. The tab bar matches |
| IA-11 (#29) | Queue panel typography and icon style | differs | queue row title: expected x 42 in the row, actual about 36. Chapters title: expected x 48, actual about 38 (no 10 px gap after the number). Tabs, header icons, count text and durations match; no bookmarks in the run |
| IA-20 (#54) | Audio and video glyphs | matches | the two-tone audio glyph matches; the video glyph isn't on the sheet |
| IA-29 (#93) | Sidebar typography and input style | differs | extra "Applies from the next file" line under the Defaults header (not in Figma, no Decision), about 17 px, moves every row down. Labels, headers and value boxes otherwise match |
| IA-30 (#95) | Slider styles (three kinds) | matches | delay slider thumb and -10 s / 0 s / +10 s labels, speed and duration thumbs; the bipolar fill isn't visible because the run's delay was 0 |
| IA-39 (#128) | Dropdown vs input vs expander styles in sidebar | matches | value boxes, colour swatches and the expander bar with its chevron; positions moved by the Defaults note (see IA-29) |
| IA-40 (#132) | EQ preset mini curve icons | unclear | the single element is the right-click menu audio icon, not the EQ preset icons |
| IB-19 (#200) | Queue card header glyphs | unclear | compares the right-click menu queue icon (matches), not the queue card header |
| IB-31 (#231) | File row "..." menu icons | unclear | the right-click menu icon matches; the main-menu crop shows the library rail (capture failed); the library file menu isn't on the sheet |
| IB-36 (#249) | Right sidebar tab glyphs and states | unclear | menu chevrons: the right-click ones match, the main-menu crop failed; not the sidebar tab glyphs |
| IB-42 (#269) | Settings category nav in the zoom | unclear | menu gear icons, not the category nav (the right-click one matches, the main-menu crop failed); the nav itself matches on the settings-dialogs sheet |
| P1-16 (#24) | Toggle playlist becomes Queue | matches | Queue / Bookmarks / Chapters tabs, queue icon, header icons and count format |
| P1-18 (#28) | Queue popup panel | differs | same queue row title offset as IA-11 (expected x 42, actual about 36); panel, tabs and header match |
| P3-23 (#100) | Size Values: Relative / Pixels segmented control | unclear | the control isn't inside the crop; the code uses Relative / Precise (allowed) |
| P4-04 (#105) | Per-show settings preset selector | matches | footer selector "Default Preset" with its chevron |
| P4-07 (#110) | Applying a preset changes all values at once | unclear | a behaviour row: the sheet shows only the selector (matches) |
| P4-33 (#143) | Playback tab: Reverse toggle | unclear | not built (Decision 29); the crop lands on the Subtitles tab Appearance note |
| P6-10 (#218) | Old version of her app menu, item highlight walkthrough | unclear | the build capture shows the library rail, not the "..." menu (it didn't open); context row |
