"""Generates the beta gate's playback matrix with ffmpeg (on PATH) into
<TEST_MEDIA_DIR>\\builds\\test-media\\beta (generated media only). Existing files are kept
(--force overwrites them); nothing in that folder is ever deleted by the script.

    python make_beta_media.py [--force] [--list]

Every video is ffmpeg's testsrc2 pattern filling the whole frame (colour bars, a moving
gradient, a frame counter and the time stamp burnt in); the gate's perf part sees the first
frame when the dark centre of the player window turns to the pattern. Audio is a sine (a different pitch per track). Subtitle cues say which
track they belong to ("EN cue 3"). The files and what they cover are in MEDIA (also read by
gate.ps1 through --list, as JSON)."""
import json
import os
import struct
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
from vconfig import load_config  # noqa: E402

# id, file, what the matrix checks on it (audio / subtitle tracks the file has)
MEDIA = [
    {"id": "mp4", "file": "Beta H264 AAC.mp4", "kind": "video", "duration": 180, "audio": 1, "subs": 0,
     "about": "MP4, H.264 + AAC, 1080p30"},
    {"id": "mkv", "file": "Beta HEVC 2a 2s.mkv", "kind": "video", "duration": 180, "audio": 2, "subs": 2,
     "about": "MKV, HEVC + 2 AAC tracks (English, Japanese) + 2 SubRip tracks (English, German)"},
    {"id": "avi", "file": "Beta MPEG4 MP3.avi", "kind": "video", "duration": 180, "audio": 1, "subs": 0,
     "about": "AVI, MPEG-4 Part 2 (XVID) + MP3"},
    {"id": "avi-noindex", "file": "Beta MPEG4 MP3 no index.avi", "kind": "video", "duration": 180, "audio": 1,
     "subs": 0, "about": "the same AVI with its idx1 index removed (VLC asks what to do)"},
    {"id": "mp3", "file": "Beta Audio.mp3", "kind": "audio", "duration": 180, "audio": 1, "subs": 0,
     "about": "MP3, 192 kbit/s"},
    {"id": "flac", "file": "Beta Audio.flac", "kind": "audio", "duration": 180, "audio": 1, "subs": 0,
     "about": "FLAC"},
    {"id": "m4a", "file": "Beta Audio.m4a", "kind": "audio", "duration": 180, "audio": 1, "subs": 0,
     "about": "AAC in .m4a"},
    {"id": "4k60", "file": "Beta 4K60.mp4", "kind": "video", "duration": 60, "audio": 1, "subs": 0,
     "about": "MP4, H.264 3840x2160 60 fps about 40 Mbit/s + AAC, 60 s"},
    {"id": "srt", "file": "Beta External Subs.mp4", "kind": "video", "duration": 180, "audio": 1, "subs": 1,
     "about": "MP4, H.264 + AAC, with Beta External Subs.srt next to it (loaded by VLC's subtitle autodetection)"},
]


def media_dir():
    cfg = load_config()
    return os.path.join(cfg["testMediaDir"], "builds", "test-media", "beta")


def srt(path, tag, duration):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        n = 0
        for start in range(1, duration - 2, 5):
            n += 1
            a = "%02d:%02d:%02d,000" % (start // 3600, start // 60 % 60, start % 60)
            e = start + 3
            b = "%02d:%02d:%02d,000" % (e // 3600, e // 60 % 60, e % 60)
            f.write("%d\n%s --> %s\n%s cue %d\n\n" % (n, a, b, tag, n))


def picture(w, h, fps, dur):
    # the test pattern fills the whole frame (scaling problems show in the screenshots)
    return "testsrc2=s={w}x{h}:r={fps}:d={d}[v]".format(w=w, h=h, fps=fps, d=dur)

def ff(args):
    # (the picture comes from -filter_complex sources, so the first -i is input 0)
    cmd = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y"] + args
    print(" ".join(a if " " not in a else '"%s"' % a for a in cmd[5:]))
    subprocess.run(cmd, check=True)


def sine(freq, dur):
    return ["-f", "lavfi", "-i", "sine=frequency=%d:sample_rate=48000:duration=%d" % (freq, dur)]


def strip_avi_index(src, dst):
    """Copies an AVI without its idx1 chunk (RIFF size fixed), so the index is missing."""
    data = open(src, "rb").read()
    assert data[:4] == b"RIFF" and data[8:12] == b"AVI "
    out = bytearray(data[:12])
    pos = 12
    removed = False
    while pos + 8 <= len(data):
        cid = data[pos:pos + 4]
        size = struct.unpack("<I", data[pos + 4:pos + 8])[0]
        end = pos + 8 + size + (size & 1)
        if cid == b"idx1":
            removed = True
        else:
            out += data[pos:end]
        pos = end
    assert removed, "no idx1 chunk found"
    struct.pack_into("<I", out, 4, len(out) - 8)
    open(dst, "wb").write(out)


def make(item, d):
    out = os.path.join(d, item["file"])
    dur = item["duration"]
    i = item["id"]
    if i == "mp4" or i == "srt":
        ff(["-filter_complex", picture(1920, 1080, 30, dur), *sine(440, dur), "-map", "[v]", "-map", "0:a",
            "-c:v", "libx264", "-preset", "veryfast", "-crf", "23", "-pix_fmt", "yuv420p", "-g", "60",
            "-c:a", "aac", "-b:a", "128k", "-ac", "2", "-movflags", "+faststart", out])
        if i == "srt":
            srt(os.path.splitext(out)[0] + ".srt", "EXT", dur)
    elif i == "mkv":
        # the two subtitle tracks are muxed from temporary files outside the media folder
        tmp = tempfile.mkdtemp(prefix="beta-subs-", dir=os.environ.get("GATE_TMP") or None)
        en = os.path.join(tmp, "en.srt")
        de = os.path.join(tmp, "de.srt")
        srt(en, "EN", dur)
        srt(de, "DE", dur)
        ff(["-filter_complex", picture(1280, 720, 30, dur), *sine(440, dur), *sine(660, dur),
            "-i", en, "-i", de,
            "-map", "[v]", "-map", "0:a", "-map", "1:a", "-map", "2:s", "-map", "3:s",
            "-c:v", "libx265", "-preset", "fast", "-crf", "28", "-pix_fmt", "yuv420p", "-x265-params", "log-level=error",
            "-c:a", "aac", "-b:a", "128k", "-ac", "2", "-c:s", "srt",
            "-metadata:s:a:0", "language=eng", "-metadata:s:a:0", "title=English",
            "-metadata:s:a:1", "language=jpn", "-metadata:s:a:1", "title=Japanese",
            "-metadata:s:s:0", "language=eng", "-metadata:s:s:0", "title=English",
            "-metadata:s:s:1", "language=ger", "-metadata:s:s:1", "title=German",
            "-disposition:s:0", "0", "-disposition:s:1", "0", out])
        for p in (en, de):
            os.remove(p)
        os.rmdir(tmp)
    elif i == "avi":
        ff(["-filter_complex", picture(640, 360, 25, dur), *sine(440, dur), "-map", "[v]", "-map", "0:a",
            "-c:v", "mpeg4", "-vtag", "XVID", "-q:v", "4", "-c:a", "libmp3lame", "-b:a", "128k", "-ac", "2", out])
    elif i == "avi-noindex":
        src = os.path.join(d, next(m["file"] for m in MEDIA if m["id"] == "avi"))
        if not os.path.exists(src):
            make(next(m for m in MEDIA if m["id"] == "avi"), d)
        strip_avi_index(src, out)
    elif i == "mp3":
        ff([*sine(440, dur), "-c:a", "libmp3lame", "-b:a", "192k", "-ac", "2",
            "-metadata", "title=Beta Audio MP3", "-metadata", "artist=Gate", out])
    elif i == "flac":
        ff([*sine(523, dur), "-c:a", "flac", "-ac", "2", "-metadata", "title=Beta Audio FLAC", "-metadata", "artist=Gate", out])
    elif i == "m4a":
        ff([*sine(587, dur), "-c:a", "aac", "-b:a", "160k", "-ac", "2",
            "-metadata", "title=Beta Audio AAC", "-metadata", "artist=Gate", out])
    elif i == "4k60":
        ff(["-filter_complex", picture(3840, 2160, 60, dur), *sine(440, dur), "-map", "[v]", "-map", "0:a",
            "-c:v", "libx264", "-preset", "veryfast", "-b:v", "40M", "-maxrate", "40M", "-bufsize", "80M",
            "-x264-params", "nal-hrd=cbr:force-cfr=1", "-pix_fmt", "yuv420p", "-g", "120",
            "-c:a", "aac", "-b:a", "128k", "-ac", "2", "-movflags", "+faststart", out])


def main():
    d = media_dir()
    if "--list" in sys.argv:
        print(json.dumps({"dir": d, "media": MEDIA}))
        return
    force = "--force" in sys.argv
    os.makedirs(d, exist_ok=True)
    for item in MEDIA:
        out = os.path.join(d, item["file"])
        if os.path.exists(out) and not force:
            print("ok   %s" % item["file"])
            continue
        make(item, d)
        print("made %s (%.1f MB)" % (item["file"], os.path.getsize(out) / 1e6))


if __name__ == "__main__":
    main()
