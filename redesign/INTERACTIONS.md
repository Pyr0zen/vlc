# INTERACTIONS: how the redesigned features affect each other

Read this before starting any work package and check it again before marking one done. Every new component must satisfy every rule below that touches it, even if the feature it depends on is built much later. When a new interaction is discovered, add it here.

## 1. Live theme and accent (video 17:39-17:49, 19:49; Decisions 9, 15, 16, 20)
The user can switch Dark / Light / System and pick one of 9 accent colors at any time, from Settings > General and from onboarding, and everything recolors instantly.
- Never hardcode a color in QML or C++. Use `VLCStyle.palette.rd*` (design colors) or a `ColorContext` role. Hardcoded design colors are a bug.
- `palette.rd*` must switch with the theme: dark values from the Figma "Dark" styles, light values from the "Light" styles (light FG/1, FG/2 to be corrected, Decision 20). Status: rd* are dark-only today; fix in the W2.1 fix batch.
- Everything accent-colored must follow the live accent: play button, seek fill and playhead, toggles ON, selected tabs and underlines, checks, active icons, sliders, Save / primary buttons, focus borders, the cone app icon (video 17:46: the cone turns green / purple), the subtitle timeline buttons, waveform played bars.
- Icons: SVGs with colorizer slots only (`_res_C1` gray, `_res_C2` Accent/DIm, `_res_ACCENT` accent). No baked-in orange. Two-tone menu icons use Accent/DIm, which is derived from the accent too.
- Accent shades (Bright, DIm, BG/Accent Bright, BG/Accent Dark) are derived from the chosen accent; light theme has its own Accent set (Light/Accent/Main #E8851A) to derive from.
- Exceptions shown in the video: the volume cone keeps its green to red gradient in every accent and theme (17:44-17:49); the video area stays dark in light theme (17:43).
- VLC's Qt is built without Canvas, Shapes and Path (also no AnimatedImage, Flipable, Sprite, particles): custom drawing (cone, video frame, waveform, subtitle timeline) uses ShaderEffect shaders in modules/gui/qt/shaders or plain Rectangles/Images, bound to palette colors so it recolors live.

## 2. Bars, panels and video area
- Windowed: both bars show on mouse movement over the window and fade out about 3 s after it stops. Fullscreen: each bar shows per hover zone and fades out (Decisions 4 and 30). Mouse moves over the native video only reach the UI through the cursor poll in Player.qml. Anything that opens from a bar (tracks popup, settings sidebar, queue sidebar, menus, tooltips, the editable time field, the resume toast) must keep the bars visible while open (lock) and release the lock when closed, including when closed by Escape, outside click, media change or window change.
- Only one player panel at a time (RdPanels): tracks popup, settings sidebar (Playback / Video / Audio / Subtitles), queue sidebar (Queue / Bookmarks / Chapters). Opening one closes the other; clicking the same button again closes it (F-06).
- Hide UI (Ctrl+\, right-click item) hides both bars and every panel; showing the UI again restores the bars but not panels.
- Fullscreen: same bars and zones; window buttons hidden; video frame (W3.7) not drawn; the fullscreen button in the top bar shows the exit icon.
- Side panels and the compact library dock inside the inset video area (IA-28, IA-43, P5-23); the video frame, panels, toast and seek thumbnail must not overlap each other badly at small window sizes.
- Pinned controls (VLC's existing option) keep working: bars always visible, video between them.

## 3. Customize Player and profiles (video 19:12-19:36; W8.1, W8.2)
- Every control bar and top bar element must be a self-contained control that works wherever the user drags it (left, center, right, top bar, bottom bar), at any order, with any neighbours. No control may assume its position or look up siblings by position.
- The seek row (time, seek bar, duration) must work as a movable item (19:22 alternate layout moves it to its own row).
- New controls (File / Folder / Playlist / Artist name, Favorite, Thumbnail, Bookmarks, Right Sidebar, Go Home ...) are added as `ControlListModel` types (append-only enum) with palette entries.
- Profiles switch layout and settings; any setting UI must reflect a profile switch live (bind to the source, never cache values).

## 4. One source of truth for settings
The same option can be changed in several places: the right sidebar tabs, the Settings dialog pages, menus, hotkeys, per-show presets and profiles.
- All of them read and write the same VLC option / player property and update live when it changes elsewhere (e.g. subtitle delay from the sidebar slider, from G/H hotkeys, from a preset).
- Presets (Decision 18) apply to every tab at once; the sidebar must show the active preset's values right after it is applied.
- Options that only apply on the next file or vout must say so (Decision 29 notice) instead of silently doing nothing.

## 5. Seek bar modes
The seek bar has several looks that can combine: thick bar (default), chapter segments (IB-46), subtitle timeline (P3-16, zoomed window with asterisk times), waveform (P6-06, music and the "Show Waveform" option), hover thumbnail (Decision 6), bookmarks marks. Build the seek bar so these are layers / modes of one component, not separate copies.

## 6. Library and playback
- The folder chip and sidebar toggle open the compact library over the video (W5.1); the full library, mini player and queue card share the same models and selection.
- Drag and drop from the library or the file manager into the queue must work over the video, the panels and the mini player.
- Watched state / progress (thumbnails, Unwatched First sort, resume toast time) all come from the media library progress.

## 7. Keyboard, focus, accessibility, translation
- Every new interactive element: keyboard reachable, visible focus, `Accessible.name`, `qsTr` / `qtr` text. Escape closes the top-most popup first.
- Hotkeys keep VLC defaults (Decision 22); new shortcuts: Ctrl+\ Hide UI, Ctrl+B bookmark. OSD shows the pressed key (W7.3).

## 8. Sizes and scaling
- All sizes go through `VLCStyle.rd_*` / `VLCStyle.dp()` so Windows scaling 100 / 125 / 150 % and VLC's own interface scale work. Test at small window sizes: panels, toast and title must elide or shrink, never overlap the window buttons.

## 9. Fonts and text
- Inter everywhere (`VLCStyle.rd_fontFamily`), bundled with the app. Long file names elide.
