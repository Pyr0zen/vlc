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
