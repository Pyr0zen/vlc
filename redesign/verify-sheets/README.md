# Verify sheets (Figma-only rows)

Contact sheets made by the verification harness (`redesign/tools/verify`, branch `wip/verify-harness`)
for the rows that can be confirmed against Figma alone, without the designer's video. Generated from
run `20261016-204509-round` on public build 38890442361 (Cone.exe), with the harness demo state.

Each sheet is one roadmap row: a header (row id, number, item, status, flags), then the row's region
compares and one element panel per spec state, each as **Figma | Build | Diff** at the same scale.
Images are crops of the player window only (PrintWindow capture, generated test media), downscaled
to 1100 px wide and 256 colours.

## How to confirm a row

1. Open the sheet and compare the Build column against the Figma column only.
2. Write one line per row: `ok`, `differs: <what>`, or `can't tell`.
3. The Diff column and the box colours are hints from the harness, not the verdict.

Box legend: green = element matches, yellow = near, red = differs, grey = masked / unchecked.
**Dashed boxes** are derived spec elements: built by `spec.py` from the Controls popup / sidebar /
queue variants, not taken from a spec file directly. Treat those boxes as approximate.

Rows marked `auto-passed WEAK` passed on a single supporting element (for example one icon in the
right-click menu); check that the element really belongs to the row.

Known limits of this run: the demo values were not all applied (Subtitle Track Delay shows
0.000 s where Figma shows -4.000 s), the queue has one generated clip instead of four, there are
no bookmarks, and the sidebar Subtitles tab has extra "Applies from the next file" notes that shift
its rows down. Those show up as differences on several sheets.

## settings-dialogs (26)

| Row | Item | Harness status |
|---|---|---|
| IA-05 | Third icon state: solid orange = active/toggled | differs |
| IA-29 | Sidebar typography and input style | differs |
| IB-20 | Music sub-category icons | differs |
| IB-36 | Right sidebar tab glyphs and states | differs |
| IB-42 | Settings category nav in the zoom | differs |
| IB-43 | Accent swatches: square in Settings, round in Onboarding | differs |
| P3-02 | Problem: subtitle file names do not match video names | differs |
| P4-33 | Playback tab: Reverse toggle | differs |
| P7-16 | Setting explanations visible via info icon | differs |
| P7-17 | Subtitle autodetection fuzziness as human-worded dropdown | differs |
| P7-18 | New settings category list (start) | differs |
| P8-01 | Use words, not numbers, in dropdowns | differs |
| P8-02 | Settings window layout and category list | differs |
| P8-03 | General page ("Global Settings") | differs |
| P8-04 | Light theme | differs |
| P8-05 | Accent color setting | differs |
| P8-06 | Interface page ("Interface Settings") | differs |
| P8-07 | Privacy page ("Privacy Settings") | differs |
| P8-12 | Subtitles page ("Subtitle Defaults") | differs |
| P8-15 | Network page ("Network Connections & Security") | differs |
| P8-16 | Performance page ("Performance Settings") | differs |
| P8-17 | Recording page ("Recording, Casting & Streaming Out") | differs |
| P8-18 | Extensions page ("Extensions & Scripts") | differs |
| P8-20 | Add-ons vs plugins split | differs |
| P8-21 | Info icon on every setting | differs |
| S2-09 | Performance > Advanced Options > Developer: "Encoder" | differs |

## sidebars-menus-panels (19)

| Row | Item | Harness status | Derived spec elements |
|---|---|---|---|
| F-18 | Crop link toggle | auto-passed (weak) | |
| F-23 | "Show Statistics" toggle in the Playback tab | differs | yes |
| IA-11 | Queue panel typography and icon style | differs | yes |
| IA-20 | Audio and video glyphs | auto-passed (weak) | |
| IA-29 | Sidebar typography and input style | differs | |
| IA-30 | Slider styles (three kinds) | differs | |
| IA-39 | Dropdown vs input vs expander styles in sidebar | differs | yes |
| IA-40 | EQ preset mini curve icons | auto-passed (weak) | |
| IB-19 | Queue card header glyphs | auto-passed (weak) | |
| IB-31 | File row "..." menu icons | differs | |
| IB-36 | Right sidebar tab glyphs and states | differs | |
| IB-42 | Settings category nav in the zoom | differs | |
| P1-16 | Toggle playlist becomes Queue | differs | yes |
| P1-18 | Queue popup panel | differs | yes |
| P3-23 | Size Values: Relative / Pixels segmented control | differs | |
| P4-04 | Per-show settings preset selector (sticky footer of the sidebar) | differs | yes |
| P4-07 | Applying a preset changes all values at once | differs | yes |
| P4-33 | Playback tab: Reverse toggle | differs | yes |
| P6-10 | Old version of her app menu, item highlight walkthrough | differs | |

No player-group rows are here: all of them need the video (behaviour) or are blocked by the known
control-bar squeeze regression (fix pending).

Figma source: the designer's Figma file in `redesign/reference/figma` (CC BY 4.0).
