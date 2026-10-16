#!/bin/bash
# release.yml: turns the build's packages into the release files.
#   release-package.sh <built dir> <out dir> <version tag>
# <built dir> holds the build's vlc-<vlc version>-win64.zip and cone-<vlc version>-win64.exe.
# The zip's content is kept as built; only its top folder and the file names carry Cone's
# version: cone-<version>-win64.zip (folder cone-<version>) and cone-<version>-win64-setup.exe,
# with SHA256SUMS.txt. Writes zip, exe, their SHA-256 and vlc_version to GITHUB_OUTPUT when set.
set -euo pipefail

BUILT=$1
OUT=$2
VER=${3#v}

shopt -s nullglob
ZIPS=("$BUILT"/vlc-*-win64.zip)
EXES=("$BUILT"/cone-*-win64.exe)
[ ${#ZIPS[@]} -eq 1 ] || { echo "::error::expected one vlc-*-win64.zip in $BUILT, found ${#ZIPS[@]}"; exit 1; }
[ ${#EXES[@]} -eq 1 ] || { echo "::error::expected one cone-*-win64.exe in $BUILT, found ${#EXES[@]}"; exit 1; }

VLC_VERSION=$(basename "${ZIPS[0]}" -win64.zip)
VLC_VERSION=${VLC_VERSION#vlc-}
ZIP=cone-$VER-win64.zip
EXE=cone-$VER-win64-setup.exe

mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
WORK=$(mktemp -d)
unzip -q "${ZIPS[0]}" -d "$WORK"
TOP=("$WORK"/*)
if [ ${#TOP[@]} -ne 1 ] || [ ! -d "${TOP[0]}" ]; then
    echo "::error::the zip does not hold exactly one top folder"
    exit 1
fi
mv "${TOP[0]}" "$WORK/cone-$VER"
(cd "$WORK" && zip -q -r -9 -X "$OUT/$ZIP" "cone-$VER")
rm -rf "$WORK"
cp "${EXES[0]}" "$OUT/$EXE"

(cd "$OUT" && sha256sum "$ZIP" "$EXE" > SHA256SUMS.txt)
cat "$OUT/SHA256SUMS.txt"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
        echo "zip=$ZIP"
        echo "exe=$EXE"
        echo "zip_sha256=$(sha256sum "$OUT/$ZIP" | cut -d' ' -f1)"
        echo "exe_sha256=$(sha256sum "$OUT/$EXE" | cut -d' ' -f1)"
        echo "vlc_version=$VLC_VERSION"
    } >> "$GITHUB_OUTPUT"
fi
