# BUILD_NOTES

Log of every CI problem and fix (newest last). Workflow: `.github/workflows/build-windows.yml`, plan: `redesign/BUILD_PLAN.md` section 3.

## 2026-10-13 W1.1 first workflow
- Added `build-windows.yml`: VideoLAN image `vlc-debian-win64-posix:20260611225331` via `docker run`, prebuilt contribs for contrib SHA a5538c557d27, `build.sh -r -a x86_64 -p`, `make package-win32-zip`, artifact `vlc-redesign-win64`.
