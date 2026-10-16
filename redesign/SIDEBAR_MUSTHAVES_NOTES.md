# Sidebar must-haves (wip/sidebar-musthaves)

Base: wip/next-batch 514a7c399e. Nothing here is verified: no build was run and there are no screenshots. Offline compile checks only.

## What was built
1. **EQ preset curve icons** (rows 132, 133, 134). `widgets/native/rd_eq_curve_item.{hpp,cpp}` (RdEqCurveItem, a QQuickPaintedItem) draws the Figma "name=EQ" geometry: a 24x24 box, an FG/A2 baseline from x 1 to x 23 on y 12 (2 px, round caps), and Accent/Main lobes standing on y 10 (boost) or hanging from y 14 (cut), at most 6 px, about 0.6 px per dB. The curve is a monotone cubic through VLC's real band gains (`RdEffects.equalizerPresetBands`). Colours are palette bindings, so the accent colour and the light theme apply live. The `RdEqCurve.qml` rewrite (in the patch) wraps the item at 24x24.
2. **Video filter preset previews** (row 139, VIDEO_INDEX line 853). Engine only:
   - `player/rd_filter_math.{hpp,cpp}`: VLC's adjust, sepia, invert, posterize, transform and rotate math, run on a still RGBA frame.
   - `player/rd_filter_preview.{hpp,cpp}`: RdFilterPreview.
     - Grabs the frame on screen with VLC's thumbnailer, using its own input item copy, software decode, 2 decoder threads, local files only.
     - Applies the filter values on one lowest-priority worker thread, keeps an LRU cache of 32 previews and serves them through the `image://rdfilterpreview` provider.
     - Playback is never blocked.
   - `player/qml/RdFilterPreviewImage.qml`: one preview, 16:9 and 24 px tall, BG/B2 placeholder. It goes in an RdOptionRow `leading` slot.
3. **Crop link toggle** (row 344). `player/qml/VideoSettingsPage.qml`:
   - Figma active icon `link_state-active` (Accent/Main 2 px with the bar), default FG/A2, hover with the ToolButton colour set (6 % white, radius 4).
   - While linked, an edit keeps the ratio the two sides had when the link was turned on. If one side was 0, both stay equal.
   - The state is saved per row (`rd/cropLinked/0|1`).
   - Values go to VLC's real `crop-top/bottom/left/right` vout variables through `RdEffects.setVideoValue`.

## Hookups for the PC session
`git apply redesign/SIDEBAR_MUSTHAVES_HOOKUP.patch` (it applies cleanly on this branch):
- Makefile.am and meson.build: sources, moc entries and the QML file.
- mainui.cpp/.hpp: the RdEqCurveItem registration in VLC.Widgets, the RdFilterPreview singleton in VLC.Player and its image provider.
- The `widgets/qml/RdEqCurve.qml` rewrite.

Checks with the patch applied: buildlists 0, qmlcheck errors 1 / crashed 0 (401 files). Without the patch: the same results (400 files). privacycheck 0.

## Not done / open
- **Filter preview placement:** neither Figma nor the video shows a video filter preset list or its previews (line 853). No list exists in the Video tab, so the previews are not placed anywhere yet. This needs StickyGonzales's decision, with a Q image from the PC session. Usage: `RdFilterPreviewImage { values: ({ adjust: true, hue: 90 }) }` as an RdOptionRow `leading`.
- **Filters the previews leave unchanged:** sharpen, gradfun, grain, extract, colorthres and gradient. The previews also apply filters in one fixed order, while VLC uses the order they were turned on.
- **EQ shapes:** our shapes come from the real gains, so they differ in detail from Figma's hand-drawn icons. Compare them on the build.
- **Still to do on the build:** the video is not used here; the PC session checks rows 132-134 and 139 against it. Also to do: screenshots against Figma 2372:8487 and 543:995, the UX pass, 60 fps, the independent review and the VIDEO_INDEX status updates.
