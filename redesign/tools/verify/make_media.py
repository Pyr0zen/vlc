"""Generates the harness's own test media (ffmpeg on PATH) into
<TEST_MEDIA_DIR>/builds/test-media/verify. Only generated media is used by the harness: never
the owner's music or videos.

  python make_media.py            create what is missing
  python make_media.py --force    recreate everything

"Videos/Verify Clip.mkv" matches the Figma player frames so the time labels and the seek fill can be
compared as they are: 25:40 long (Figma "00:25:40"; scenarios set it paused to 2:10, Figma
"00:02:10"), a still dark picture in the Figma video colour and two subtitle tracks (off by
default). "Verify Tracks.mkv" adds two silent audio tracks; "Verify Chapters.mkv" (2 h) has the
five chapters of the Figma Chapters tab.
Track languages and the external subtitle file name follow the Figma tracks popup (English /
Japanese, "The_Wand_S01_EN.srt").
"""
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vconfig import load_config  # noqa: E402

DURATION = 25 * 60 + 40
VIDEO_COLOR = "0x2D2B29"  # the flat area of the video picture in Player.png (test media only)
# the top bar shows the media title and the folder chip the parent folder: Player.png shows
# "VLC Media Player" and "Videos", so the clip carries that title and lives in a "Videos" folder
# (a test fixture only: it lets the title and the chip be compared pixel for pixel)
TITLE = "VLC Media Player"
FOLDER = "Videos"


def srt(lang_lines):
    out = []
    t = 5
    for i in range(1, 60):
        a, b = t, t + 4
        out.append(f"{i}\n{fmt(a)} --> {fmt(b)}\n{lang_lines[i % len(lang_lines)]} {i}\n")
        t += 25
    return "\n".join(out)


def fmt(s):
    return f"{s // 3600:02d}:{s % 3600 // 60:02d}:{s % 60:02d},000"


# the Chapters tab in Figma (Controls "chapters" variant): names and start times
CHAPTERS = [("Winter", 135), ("Spring", 1785), ("Summer", 3090), ("Fall", 4430), ("Winter (5 Years Later)", 6250)]
CHAPTERS_DURATION = 2 * 3600


def chapters_meta():
    lines = [";FFMETADATA1", f"title={TITLE}"]
    for i, (n, s) in enumerate(CHAPTERS):
        e = CHAPTERS[i + 1][1] if i + 1 < len(CHAPTERS) else CHAPTERS_DURATION
        lines += ["[CHAPTER]", "TIMEBASE=1/1", f"START={s}", f"END={e}", f"title={n}"]
    return "\n".join(lines) + "\n"

def make_clip(path, chapters=False, audio=False):
    duration = CHAPTERS_DURATION if chapters else DURATION
    with tempfile.TemporaryDirectory() as tmp:
        en = os.path.join(tmp, "en.srt")
        es = os.path.join(tmp, "es.srt")
        meta = os.path.join(tmp, "meta.txt")
        open(en, "w", encoding="utf-8").write(srt(["Test subtitle line", "Another test line"]))
        open(es, "w", encoding="utf-8").write(srt(["Test line two", "Second track"]))
        open(meta, "w", encoding="utf-8").write(chapters_meta() if chapters else f";FFMETADATA1\ntitle={TITLE}\n")
        cmd = ["ffmpeg", "-y", "-v", "error",
               "-f", "lavfi", "-i", f"color=c={VIDEO_COLOR}:s=1280x720:r=2:d={duration}"]
        maps = ["-map", "0:v"]
        n = 1
        if audio:
            cmd += ["-f", "lavfi", "-i", f"anullsrc=r=48000:cl=stereo:d={DURATION}",
                    "-f", "lavfi", "-i", f"anullsrc=r=48000:cl=mono:d={DURATION}"]
            maps += ["-map", "1:a", "-map", "2:a"]
            n = 3
        cmd += ["-i", en, "-i", es, "-i", meta]
        maps += ["-map", f"{n}:s", "-map", f"{n + 1}:s", "-map_metadata", str(n + 2), "-map_chapters", str(n + 2)]
        cmd += maps + [
            "-c:v", "libx264", "-preset", "veryfast", "-tune", "stillimage", "-g", "20", "-pix_fmt", "yuv420p",
            "-color_range", "tv", "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709",
            "-c:s", "srt",
            "-metadata:s:s:0", "language=eng", "-metadata:s:s:1", "language=jpn",
            # subtitles off by default: no subtitle text over the bars in the screenshots
            "-disposition:s:0", "0", "-disposition:s:1", "0",
        ]
        if audio:
            cmd += ["-c:a", "aac", "-b:a", "24k",
                    "-metadata:s:a:0", "language=eng", "-metadata:s:a:1", "language=jpn",
                    "-disposition:a:0", "default", "-disposition:a:1", "0"]
        cmd += ["-t", str(duration), path]
        subprocess.run(cmd, check=True)

def main():
    cfg = load_config()
    out_dir = os.path.join(cfg["testMediaDir"], "builds", "test-media", "verify", FOLDER)
    os.makedirs(out_dir, exist_ok=True)
    force = "--force" in sys.argv
    # "Verify Clip" has no audio and no chapters: an audio track draws the waveform on the seek
    # bar when the test profile has "Show Waveform on Seekbar" on (Qt reads that setting from the
    # profile, a command-line option does not override it) and chapter marks split the bar;
    # Figma's default bar shows neither. "Verify Tracks" has the audio tracks (tracks popup),
    # "Verify Chapters" the chapters (Chapters tab).
    clips = (("Verify Clip.mkv", False, False), ("Verify Tracks.mkv", False, True), ("Verify Chapters.mkv", True, False))
    for name, chapters, audio in clips:
        clip = os.path.join(out_dir, name)
        if force or not os.path.exists(clip):
            print("making", clip)
            make_clip(clip, chapters, audio)
    # an external subtitle file named like the one in the Figma tracks popup ("External Tracks")
    ext = os.path.join(out_dir, "The_Wand_S01_EN.srt")
    if force or not os.path.exists(ext):
        open(ext, "w", encoding="utf-8").write(srt(["External test line", "External line"]))
    print("media ready in", out_dir)


if __name__ == "__main__":
    main()
