# Frame-update analysis of a ddagrab capture (dup_frames=0: one frame per screen change).
#
#   python motion.py <capture.mkv> <roi x,y,w,h> [cursor x,y|-] [capture scale]
#
# Coordinates are window pixels; "capture scale" is how much the capture was shrunk (vlcperf.ps1
# captures at 1/4 size so the capture itself costs little), default 1.
#
# The capture holds only frames where the captured area changed, with the GPU present time as
# pts. For the region of interest (ROI) this prints:
#   input_ms   first frame where the cursor box at (cursor x,y) changed (the scripted mouse jump
#              that precedes the click / drag), i.e. the input time
#   latency_ms from the input to the first frame where the ROI changed
#   active_ms  from the first to the last ROI change (animation or drag length)
#   frames     ROI-changing frames
#   worst_gap_ms / gaps_over_16_7 / gaps_over_33
#              largest interval between consecutive ROI-changing frames while it was changing,
#              and how many intervals were longer than one 60 fps frame / two 60 fps frames
# A smooth animation on this PC's 99 Hz monitor updates every ~10 ms; > 16.7 ms is below 60 fps.
# The cursor box (48 px around the cursor) is excluded from the ROI so pointer moves do not count.
import json, subprocess, sys
import numpy as np

cap = sys.argv[1]
rx, ry, rw, rh = (int(v) for v in sys.argv[2].split(","))
cur = tuple(int(v) for v in sys.argv[3].split(",")) if len(sys.argv) > 3 and sys.argv[3] != "-" else None
CS = int(sys.argv[4]) if len(sys.argv) > 4 else 1

probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                        "frame=pts_time:stream=width,height", "-of", "json", cap],
                       capture_output=True, text=True, check=True)
info = json.loads(probe.stdout)
W, H = info["streams"][0]["width"], info["streams"][0]["height"]
times = [float(f["pts_time"]) for f in info["frames"]]

S = max(1, 4 // CS) * CS   # analyse at quarter resolution of the window
w, h = W * CS // S, H * CS // S
raw = subprocess.run(["ffmpeg", "-v", "error", "-i", cap, "-fps_mode", "passthrough",
                      "-vf", "scale=%d:%d:flags=area,format=gray" % (w, h), "-f", "rawvideo", "-"],
                     capture_output=True, check=True).stdout
frames = np.frombuffer(raw, np.uint8).reshape(-1, h, w).astype(np.int16)
n = min(len(frames), len(times))
frames, times = frames[:n], times[:n]

roi = np.zeros((h, w), bool)
roi[ry // S:(ry + rh) // S, rx // S:(rx + rw) // S] = True
cbox = np.zeros((h, w), bool)
if cur:
    cx, cy = cur[0] // S, cur[1] // S
    cbox[max(0, cy - 12):cy + 12, max(0, cx - 12):cx + 12] = True
roi &= ~cbox

def changed(mask, k, thr=6, minpix=3):
    d = np.abs(frames[k] - frames[k - 1])[mask]
    return int((d > thr).sum()) >= minpix

input_t = None
if cur:
    for k in range(1, n):
        if changed(cbox, k):
            input_t = times[k]
            break
roi_t = [times[k] for k in range(1, n) if changed(roi, k) and (input_t is None or times[k] >= input_t)]
res = {"capture_frames": n, "input_ms": None if input_t is None else round(input_t * 1000, 1)}
if roi_t:
    gaps = np.diff(roi_t) * 1000 if len(roi_t) > 1 else np.array([0.0])
    res.update({
        "latency_ms": None if input_t is None else round((roi_t[0] - input_t) * 1000, 1),
        "active_ms": round((roi_t[-1] - roi_t[0]) * 1000, 1),
        "frames": len(roi_t),
        "worst_gap_ms": round(float(gaps.max()), 1),
        "median_gap_ms": round(float(np.median(gaps)), 1),
        "gaps_over_16_7": int((gaps > 16.7).sum()),
        "gaps_over_33": int((gaps > 33.4).sum()),
    })
else:
    res["frames"] = 0
print(json.dumps(res))
