# UI update analysis of a ddagrab capture (dup_frames=0: one frame per screen change) against the
# input log that vlcperf.ps1 writes next to it.
#
#   python motion.py <capture.mkv> <input.json|-> <kind> <roi x,y,w,h> [--scale 4] [--png out.png]
#
# kind
#   drag    seek / volume drag: every input step moves the UI, so the screen should change on
#           every refresh while the pointer moves
#   scroll  wheel notches over a list: same analysis as drag
#   hover   pointer sweep along a bar: the UI changes only where the pointer crosses a control
#   open    a click that opens or closes a panel: latency and animation length
# The ROI is in window pixels; --scale is how much the capture was shrunk (vlcperf.ps1: 4).
#
# Clock: ddagrab stamps each frame when it acquires it, relative to its first frame; the input log
# has QueryPerformanceCounter times. A small square of our own (the marker, listed in the log)
# flips black/white at logged times; each flip shows up in the capture, so
#   capture time = QPC time + offset,  offset = min over the flips of (flip seen - flip logged)
# (the earliest a change can show up; a flip is painted with GDI and composited by DWM at the next
# refresh, like VLC's own frames). sync.spread_ms says how much the flips disagree.
#
# Output (JSON), times in ms. On this PC (99 Hz) a smooth UI changes every ~10.1 ms; a gap over
# 16.7 ms is below 60 fps. Capture stamps are within ~4 ms of the real present (240 Hz polling).
#   drag/scroll: steps / step_ms (pacing the driver achieved), updates, update_hz,
#     gap_median_ms / gap_p95_ms / worst_gap_ms between consecutive UI changes while the input
#     moved, gaps_over_16_7 / gaps_over_25, worst_gap_steps (input steps that arrived inside the
#     worst gap, i.e. inputs the screen did not show for that long), stalls (gaps over 16.7 ms
#     with an input step waiting more than one refresh), response_p50/p95/max_ms (per input
#     step: time to the next screen change), first_response_ms, settle_ms (last change after the
#     last input step)
#   hover: segments (bursts of changes split at 100 ms of stillness), hover_latency_median/max_ms
#     (burst start minus the last time the pointer crossed into or out of the area that changed),
#     hover_latency_n; anim_runs and anim_gap_median_ms / anim_worst_gap_ms / anim_gaps_over_16_7
#     (frame pacing inside animations: runs of changes split at 25 ms; a missed refresh shows as
#     a 17-25 ms gap, a longer freeze splits a run and shows up as a late burst instead)
#   open: latency_ms (click release -> first ROI change), duration_ms (first -> last change, the
#     animation), stable_ms (release -> last change), frames, worst_gap_ms / gaps_over_16_7
#     during the animation; error when nothing changed (the panel did not open: see --png)
import argparse, json, subprocess, sys
import numpy as np

REFRESH_MS = 1000.0 / 99
SPLIT_MS = 100.0      # hover: stillness that separates two bursts
OPEN_WINDOW_MS = 2000  # open: changes counted after the click

ap = argparse.ArgumentParser()
ap.add_argument("capture")
ap.add_argument("inputlog")
ap.add_argument("kind", choices=["drag", "scroll", "hover", "open"])
ap.add_argument("roi")
ap.add_argument("--scale", type=int, default=1)
ap.add_argument("--png", default=None, help="save the capture's last frame here (to check the region)")
ap.add_argument("--thr", type=int, default=6, help="gray level difference that counts as a change")
ap.add_argument("--minpix", type=int, default=3, help="changed pixels needed in the ROI")
a = ap.parse_args()
S = a.scale

# ---------------------------------------------------------------- capture
probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                        "frame=pts_time,best_effort_timestamp_time:stream=width,height", "-of", "json", a.capture],
                       capture_output=True, text=True, check=True)
info = json.loads(probe.stdout)
W, H = info["streams"][0]["width"], info["streams"][0]["height"]
times = np.array([float(f.get("pts_time", f.get("best_effort_timestamp_time"))) for f in info["frames"]])
raw = subprocess.run(["ffmpeg", "-v", "error", "-i", a.capture, "-fps_mode", "passthrough",
                      "-f", "rawvideo", "-pix_fmt", "gray", "-"], capture_output=True, check=True).stdout
frames = np.frombuffer(raw, np.uint8).reshape(-1, H, W)
n = min(len(frames), len(times))
frames, times = frames[:n], times[:n] * 1000.0          # ms
if a.png:
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", a.capture, "-fps_mode", "passthrough",
                    "-update", "1", a.png], check=False)

res = {"capture_frames": int(n), "capture_ms": round(float(times[-1] - times[0]), 1) if n else 0}
warn = []
if n > 3:
    grid = np.abs(times / (1000.0 / 120) - np.round(times / (1000.0 / 120)))
    if (grid < 0.07).all():
        warn.append("timestamps sit on the 1/120 s grid: an old capture without -enc_time_base, "
                    "gaps are rounded to 8.3 ms steps")


def rect_mask(x, y, w, h):
    m = np.zeros((H, W), bool)
    m[max(0, y // S):min(H, -(-(y + h) // S)), max(0, x // S):min(W, -(-(x + w) // S))] = True
    return m


rx, ry, rw, rh = (int(v) for v in a.roi.split(","))
roi = rect_mask(rx, ry, rw, rh)

# ---------------------------------------------------------------- input log and sync
log = None
if a.inputlog != "-":
    with open(a.inputlog, encoding="utf-8-sig") as fh:
        log = json.load(fh)

offset = None
if log:
    mx, my, mw, mh = log["marker"]
    mk = rect_mask(mx, my, mw, mh)
    roi &= ~rect_mask(mx - S, my - S, mw + 2 * S, mh + 2 * S)   # never count the marker
    # inner pixels only (edges are blended by the downscale)
    ys, xs = np.nonzero(mk)
    inner = np.zeros((H, W), bool)
    inner[ys.min() + 1:ys.max(), xs.min() + 1:xs.max()] = True
    if not inner.any():
        inner = mk
    level = np.array([frames[k][inner].mean() > 128 for k in range(n)])
    seen = [(times[k], int(level[k])) for k in range(1, n) if level[k] != level[k - 1]]
    flips = [(f["t"] / 1000.0, f["v"]) for f in log["flips"]]
    # pair the i-th transition seen with flip i+s, same colour; the shift with the most pairs and
    # the most consistent offsets wins
    best = None
    for s in range(-len(seen), len(flips)):
        pairs = [(seen[j][0], flips[j + s][0]) for j in range(len(seen))
                 if 0 <= j + s < len(flips) and seen[j][1] == flips[j + s][1]]
        if len(pairs) < 3 or len(pairs) < min(len(seen), len(flips)) - 2:
            continue
        d = np.array([p[0] - p[1] for p in pairs])
        key = (-len(pairs), float(d.max() - d.min()))
        if best is None or key < best[0]:
            best = (key, d)
    res["sync"] = {"flips_logged": len(flips), "flips_seen": len(seen)}
    if best is None:
        res["error"] = "sync failed: the marker flips were not found in the capture"
    else:
        d = best[1]
        offset = float(d.min())
        res["sync"].update({"pairs": int(len(d)), "spread_ms": round(float(d.max() - d.min()), 1)})
        if d.max() - d.min() > 2 * REFRESH_MS + 4:
            warn.append("sync spread over two refreshes: the clock mapping is unreliable")


def changed(k, mask):
    if k == 0:
        return False
    d = np.abs(frames[k].astype(np.int16) - frames[k - 1].astype(np.int16))[mask]
    return int((d > a.thr).sum()) >= a.minpix


chg = np.array([changed(k, roi) for k in range(n)])
ct = times[chg]                                  # capture times of ROI changes (ms)


def stats(g):
    g = np.asarray(g, float)
    if len(g) == 0:
        return {}
    return {"gap_median_ms": round(float(np.median(g)), 1), "gap_p95_ms": round(float(np.percentile(g, 95)), 1),
            "worst_gap_ms": round(float(g.max()), 1), "gaps_over_16_7": int((g > 16.7).sum()),
            "gaps_over_25": int((g > 25).sum())}


def r1(x):
    return None if x is None else round(float(x), 1)


if log is None:
    # no input log (round 1 captures): only the raw change times over the whole capture
    warn.append("no input log: gaps include pauses between script steps, no latency")
    res["frames"] = int(chg.sum())
    if len(ct) > 1:
        res.update(stats(np.diff(ct)))
elif offset is not None:
    ev = [dict(e, ct=e["t"] / 1000.0 + offset) for e in log["events"]]
    phase = [e for e in ev if e["tag"] == "phase"]
    if a.kind in ("drag", "scroll"):
        st = np.array([e["ct"] for e in phase])
        if len(st) < 2:
            res["error"] = "no input phase in the log"
        else:
            p0, p1 = st[0], st[-1]
            res.update({"steps": int(len(st)), "step_ms": round(float(np.median(np.diff(st))), 2),
                        "step_max_ms": round(float(np.diff(st).max()), 2)})
            u = ct[(ct > p0) & (ct <= p1 + 2 * REFRESH_MS)]
            res["updates"] = int(len(u))
            if len(u) == 0:
                res["error"] = "the ROI never changed while the input moved"
            else:
                res["first_response_ms"] = r1(u[0] - p0)
                after = ct[ct > p1]
                res["settle_ms"] = r1((after[after <= p1 + 1000].max() - p1) if (after <= p1 + 1000).any() else 0)
                if len(u) > 1:
                    g = np.diff(u)
                    res["update_hz"] = round(float((len(u) - 1) / (u[-1] - u[0]) * 1000), 1)
                    res.update(stats(g))
                    inside = [int(((st > u[i]) & (st <= u[i + 1])).sum()) for i in range(len(g))]
                    wi = int(np.argmax(g))
                    res["worst_gap_steps"] = inside[wi]
                    res["max_steps_in_gap"] = int(max(inside))
                    # a stall: the screen did not change for more than 16.7 ms although an input
                    # step had been waiting for more than one refresh
                    res["stalls"] = int(sum(1 for i in range(len(g)) if g[i] > 16.7 and
                                            ((st > u[i]) & (st <= u[i + 1] - REFRESH_MS)).any()))
                resp = []
                for s in st:
                    nxt = ct[ct > s]
                    if len(nxt):
                        resp.append(nxt[0] - s)
                if resp:
                    resp = np.array(resp)
                    res.update({"response_p50_ms": r1(np.median(resp)), "response_p95_ms": r1(np.percentile(resp, 95)),
                                "response_max_ms": r1(resp.max())})
    elif a.kind == "hover":
        st = np.array([e["ct"] for e in phase])
        px = np.array([e["x"] for e in phase]); py = np.array([e["y"] for e in phase])
        if len(st) < 2:
            res["error"] = "no input phase in the log"
        else:
            p0, p1 = st[0], st[-1]
            res.update({"steps": int(len(st)), "step_ms": round(float(np.median(np.diff(st))), 2),
                        "step_max_ms": round(float(np.diff(st).max()), 2)})
            idx = [k for k in np.nonzero(chg)[0] if p0 < times[k] <= p1 + SPLIT_MS]
            segs = []
            for k in idx:
                if segs and times[k] - times[segs[-1][-1]] <= SPLIT_MS:
                    segs[-1].append(k)
                else:
                    segs.append([k])
            res["segments"] = len(segs)
            res["updates"] = len(idx)
            # frame pacing inside animations: runs of changes no more than 25 ms apart (a pointer
            # resting inside a button changes nothing, which is not a stall)
            runs = []
            for k in idx:
                if runs and times[k] - times[runs[-1][-1]] <= 25:
                    runs[-1].append(k)
                else:
                    runs.append([k])
            res["anim_runs"] = len(runs)
            res.update({"anim_" + k: v for k, v in stats([g for r in runs for g in np.diff(times[r])]).items()})
            lat = []
            for s in segs:
                k = s[0]
                dm = (np.abs(frames[k].astype(np.int16) - frames[k - 1].astype(np.int16)) > a.thr) & roi
                yy, xx = np.nonzero(dm)
                x0, x1 = xx.min() * S, (xx.max() + 1) * S - 1
                y0, y1 = yy.min() * S, (yy.max() + 1) * S - 1
                ins = (px >= x0) & (px <= x1) & (py >= y0) & (py <= y1)
                before = np.nonzero(st < times[k])[0]
                cross = [i for i in before[1:] if ins[i] != ins[i - 1]]
                if before.size and ins[before[0]] and not cross:
                    cross = [before[0]]                 # already inside when the sweep started
                if cross and times[k] - st[cross[-1]] <= 400:
                    lat.append(times[k] - st[cross[-1]])
            res["hover_latency_n"] = len(lat)
            if lat:
                res["hover_latency_median_ms"] = r1(np.median(lat))
                res["hover_latency_max_ms"] = r1(max(lat))
    else:  # open
        ups = [e for e in ev if e["type"] == "up" and e["tag"] == "click"]
        if not ups:
            res["error"] = "no click in the log"
        else:
            t0 = ups[-1]["ct"]
            downs = [e for e in ev if e["type"] == "down" and e["tag"] == "click"]
            u = ct[(ct > t0) & (ct <= t0 + OPEN_WINDOW_MS)]
            res["frames"] = int(len(u))
            early = ct[(ct > (downs[-1]["ct"] if downs else t0)) & (ct <= t0)]
            if len(early):
                res["changes_before_release"] = int(len(early))
            if len(u) == 0:
                res["error"] = ("no change in the ROI after the click: the panel did not open or the "
                                "region is wrong (check the --png frame)")
            else:
                res.update({"latency_ms": r1(u[0] - t0), "duration_ms": r1(u[-1] - u[0]),
                            "stable_ms": r1(u[-1] - t0)})
                if len(u) > 1:
                    res.update(stats(np.diff(u)))
if warn:
    res["warnings"] = warn
print(json.dumps(res))
