"""Figma comparison and report for a verification run.

  python compare.py <run dir>                 compare every shot of the run, write the report
  python compare.py --validate <scenario.json>...   check that every Figma node in the scenarios exists
  python compare.py --nodes <node id> [depth]  list a Figma node's descendants (for writing scenarios)

The run dir holds run.json (written by verify.ps1: scenarios, steps results, shot metadata) and
the screenshots. Output: compare/<scenario>__<id>.png (Figma | build | diff), report.json and
report.md in the run dir. Nothing is written into the repository.

How a compare item maps Figma onto the screenshot (all in logical px = Figma units):
- "ref" is a Figma node that has a known place in the window, "anchor" says which corner of the
  client area that node's same corner sits at (tl, tr, bl, br; a full player frame uses tl, a
  control bar variant bl or br); or "at": [x, y] puts ref's top-left at that client position
  (measured from the corner "from", default tl), e.g. a component variant drawn elsewhere.
- "node" (or "rect" [x, y, w, h] relative to ref) is the part compared, grown by "pad".
- the Figma PNG is the 2x export of the top-level frame that contains ref (FIGMA_FLOWS.md
  "Frame to PNG map"); its crop is scaled to the screenshot's scale (1.25 on a 125 % display).
- transparent Figma pixels are composited over the screenshot (they show what is behind) and
  left out of the diff, or over "backdrop" {"node", "at"}: the Figma colour at that point (for
  components drawn without their background, such as the time label variants).
- "mask" lists nodes / rects (relative to ref) left out of the diff: dynamic content such as
  video pixels, the public build's logo, a cursor.
- "search" (logical px) looks for the best position within that radius (popups and menus that
  open at the cursor); "tolerance.shift" (physical px) allows a sub-pixel rounding offset.
"""
import json
import math
import os
import re
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spec as figspec  # noqa: E402  (the machine-readable Figma spec, or its fixture)

HERE = os.path.dirname(os.path.abspath(__file__))
REDESIGN = os.path.normpath(os.path.join(HERE, "..", ".."))
FIGMA_DIR = os.path.join(REDESIGN, "reference", "figma")
# pass: practically identical; minor: small differences (stroke weight, 1-2 px edges) that need a
# glance at the image; anything beyond is "differs"
DEFAULT_TOL = {"channel": 24, "fraction": 0.01, "core": 0.001, "mean": 4.0, "shift": 1, "minValid": 0.3,
               "minorFraction": 0.04, "minorCore": 0.003, "tile": 0.08, "minorTile": 0.2}


# --- Figma -------------------------------------------------------------------------------
class Figma:
    def __init__(self):
        with open(os.path.join(FIGMA_DIR, "figma_file.json"), encoding="utf-8") as f:
            doc = json.load(f)["document"]
        self.nodes, self.parent, self.top = {}, {}, {}
        for page in doc.get("children", []):
            for frame in page.get("children", []):
                stack = [(frame, None)]
                while stack:
                    n, p = stack.pop()
                    self.nodes[n["id"]] = n
                    self.parent[n["id"]] = p
                    self.top[n["id"]] = frame["id"]
                    for c in n.get("children", []):
                        stack.append((c, n["id"]))
        self.png_of = {}
        flows = open(os.path.join(REDESIGN, "FIGMA_FLOWS.md"), encoding="utf-8").read()
        sec = flows.split("## Frame to PNG map", 1)[1]
        for m in re.finditer(r"^\| [^|]* \| ([0-9]+:[0-9]+) \| [^|]* \| [^|]* \| ([^|]+?\.png) \|", sec, re.M):
            self.png_of[m.group(1)] = m.group(2).strip()
        self._png_cache = {}

    def node(self, nid):
        if nid not in self.nodes:
            raise KeyError(f"Figma node {nid} not found")
        return self.nodes[nid]

    def bbox(self, nid):
        b = self.node(nid)["absoluteBoundingBox"]
        return b["x"], b["y"], b["width"], b["height"]

    def frame_png(self, nid):
        """(RGBA array of the PNG, origin x, origin y, px per Figma unit) for the frame holding nid"""
        top = self.top[nid]
        if top not in self._png_cache:
            name = self.png_of.get(top)
            if not name:
                raise KeyError(f"no PNG export for the frame of node {nid} (top-level {top})")
            im = Image.open(os.path.join(FIGMA_DIR, name)).convert("RGBA")
            t = self.nodes[top]
            rb = t.get("absoluteRenderBounds") or t["absoluteBoundingBox"]
            s = im.width / rb["width"]
            self._png_cache[top] = (im, rb["x"], rb["y"], s, name)
        return self._png_cache[top]

    def name(self, nid):
        n = self.nodes.get(nid, {})
        if n.get("type") == "TEXT":
            return f"text '{n.get('characters', n.get('name'))}'"
        return n.get("name", nid)

    def descendants(self, nid):
        out = []
        stack = list(self.node(nid).get("children", []))
        while stack:
            n = stack.pop()
            if n.get("visible") is False:
                continue
            out.append(n)
            stack.extend(n.get("children", []))
        return out


# --- geometry ----------------------------------------------------------------------------
def place(fig, spec, client_wl, client_hl):
    """returns f(x, y) mapping absolute Figma coords to client logical coords"""
    rx, ry, rw, rh = fig.bbox(spec["ref"])
    if "at" in spec:  # ref's top-left at a client position, measured from the corner "from"
        x, y = spec["at"]
        frm = spec.get("from", "tl")
        ax = client_wl - x if frm.endswith("r") else x
        ay = client_hl - y if frm.startswith("b") else y
        return lambda px, py: (ax + px - rx, ay + py - ry)
    anchor = spec.get("anchor", "tl")
    ax = client_wl - rw if anchor.endswith("r") else (client_wl - rw) / 2 if anchor.endswith("c") else 0
    ay = client_hl - rh if anchor.startswith("b") else (client_hl - rh) / 2 if anchor.startswith("c") else 0
    return lambda x, y: (ax + x - rx, ay + y - ry)


def region_abs(fig, spec, item):
    """absolute Figma rect (x, y, w, h) of a node or a ref-relative rect"""
    if "node" in item:
        return fig.bbox(item["node"])
    rx, ry, _, _ = fig.bbox(spec["ref"])
    x, y, w, h = item["rect"]
    return rx + x, ry + y, w, h


# --- image helpers -----------------------------------------------------------------------
def figma_crop(fig, spec, gx, gy, aw, ah, scale):
    """the Figma area whose top-left (gx, gy) falls on a screenshot pixel corner, resampled to the
    screenshot scale on the screenshot's pixel grid"""
    im, ox, oy, s, png = fig.frame_png(spec["ref"])
    size = (max(1, round(aw * scale)), max(1, round(ah * scale)))
    x0, y0 = (gx - ox) * s, (gy - oy) * s
    x1, y1 = x0 + size[0] * s / scale, y0 + size[1] * s / scale
    # an integer crop with a margin first (areas outside the PNG come out transparent), then the
    # exact resampling box inside it
    ix, iy = int(math.floor(x0)) - 4, int(math.floor(y0)) - 4
    sub = im.crop((ix, iy, int(math.ceil(x1)) + 4, int(math.ceil(y1)) + 4))
    box = (x0 - ix, y0 - iy, x1 - ix, y1 - iy)
    return np.asarray(sub.resize(size, Image.Resampling.LANCZOS, box=box)).astype(np.float32), png


def best_offset(fa, build, x0, y0, radius, skip=None):
    """position (x, y) of the Figma crop in the build image near (x0, y0) with the least mean
    difference over opaque, unmasked Figma pixels; on ties (flat areas) the nearest wins"""
    h, w = fa.shape[:2]
    wmask = fa[..., 3] / 255.0 > 0.9
    if skip is not None:
        wmask &= ~skip
    if wmask.sum() < 16:
        wmask = np.ones_like(wmask)
    # brightness only, on a sparse grid for big crops: fast enough for a few hundred positions
    st = max(1, int(math.sqrt(h * w / 60000)))
    lw = np.array([0.299, 0.587, 0.114], np.float32)
    fl = (fa[..., :3] @ lw)[::st, ::st]
    wm = wmask[::st, ::st]
    bl = build[..., :3] @ lw
    best = (math.inf, x0, y0)
    H, W = build.shape[:2]
    offsets = sorted(((dx, dy) for dy in range(-radius, radius + 1) for dx in range(-radius, radius + 1)),
                     key=lambda o: o[0] * o[0] + o[1] * o[1])
    for dx, dy in offsets:
        x, y = x0 + dx, y0 + dy
        if x < 0 or y < 0 or x + w > W or y + h > H:
            continue
        d = np.abs(bl[y:y + h:st, x:x + w:st] - fl)
        score = d[wm].mean() + 0.02 * math.hypot(dx, dy)
        if score < best[0]:
            best = (score, x, y)
    return best[1], best[2]


def search_offset(fa, build, x0, y0, radius, skip=None):
    if radius <= 4:
        return best_offset(fa, build, x0, y0, radius, skip)
    # coarse on 4x smaller images, then refine at full size
    f = 4
    sw, sh = max(1, fa.shape[1] // f), max(1, fa.shape[0] // f)
    fs = np.asarray(Image.fromarray(fa.astype(np.uint8)).resize((sw, sh), Image.Resampling.BOX)).astype(np.float32)
    bs = np.asarray(Image.fromarray(build.astype(np.uint8)).resize((build.shape[1] // f, build.shape[0] // f), Image.Resampling.BOX)).astype(np.float32)
    ss = None
    if skip is not None:
        ss = np.asarray(Image.fromarray((skip * 255).astype(np.uint8)).resize((sw, sh), Image.Resampling.BOX)) > 127
    cx, cy = best_offset(fs, bs, x0 // f, y0 // f, radius // f + 1, ss)
    return best_offset(fa, build, cx * f, cy * f, f + 1, skip)


def box3(a):
    p = np.pad(a, ((1, 1), (1, 1), (0, 0)), mode="edge")
    out = np.zeros_like(a)
    for dy in range(3):
        for dx in range(3):
            out += p[dy:dy + a.shape[0], dx:dx + a.shape[1]]
    return out / 9.0


def shift2(a, dx, dy):
    """a shifted by (dx, dy) with edge padding (same shape)"""
    pad = [(1, 1), (1, 1)] + [(0, 0)] * (a.ndim - 2)
    p = np.pad(a, pad, mode="edge")
    return p[1 + dy:1 + dy + a.shape[0], 1 + dx:1 + dx + a.shape[1]]


def erode(b):
    """pixels whose whole 3x3 neighbourhood differs: real shapes, not anti-aliased edges"""
    p = np.pad(b, 1)
    out = np.ones_like(b)
    for dy in range(3):
        for dx in range(3):
            out &= p[dy:dy + b.shape[0], dx:dx + b.shape[1]]
    return out


def clusters(bad, cell):
    """bounding boxes (x, y, w, h in px) of connected groups of differing cells"""
    h, w = bad.shape
    gh, gw = (h + cell - 1) // cell, (w + cell - 1) // cell
    g = np.zeros((gh, gw), bool)
    for y in range(gh):
        for x in range(gw):
            blk = bad[y * cell:(y + 1) * cell, x * cell:(x + 1) * cell]
            g[y, x] = blk.sum() >= max(2, blk.size // 8)
    seen = np.zeros_like(g)
    out = []
    for y in range(gh):
        for x in range(gw):
            if g[y, x] and not seen[y, x]:
                q = deque([(y, x)]); seen[y, x] = True
                ys, xs = [], []
                while q:
                    cy, cx = q.popleft(); ys.append(cy); xs.append(cx)
                    for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                        if 0 <= ny < gh and 0 <= nx < gw and g[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True; q.append((ny, nx))
                out.append((min(xs) * cell, min(ys) * cell, (max(xs) - min(xs) + 1) * cell, (max(ys) - min(ys) + 1) * cell, len(ys)))
    out.sort(key=lambda c: -c[4])
    return out


def label_font(size=14):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def side_by_side(fig_rgb, build_rgb, heat, title, out):
    h, w = fig_rgb.shape[:2]
    k = 1
    while h * k < 140 and k < 4:
        k += 1
    while w * k * 3 > 3600 and k > 1:
        k -= 1
    if w * 3 > 3600:  # very wide crops (a full bar): stack the panels
        panels = [fig_rgb, build_rgb, heat]
        img = Image.new("RGB", (w * k, (h * k + 22) * 3 + 24), (24, 24, 24))
        d = ImageDraw.Draw(img); font = label_font()
        d.text((6, 4), title, fill=(230, 230, 230), font=font)
        for i, (p, name) in enumerate(zip(panels, ("Figma", "Build", "Diff"))):
            y = 24 + i * (h * k + 22)
            d.text((6, y + 2), name, fill=(200, 200, 200), font=font)
            img.paste(Image.fromarray(p.astype(np.uint8)).resize((w * k, h * k), Image.Resampling.NEAREST), (0, y + 20))
    else:
        img = Image.new("RGB", (w * k * 3 + 16, h * k + 46), (24, 24, 24))
        d = ImageDraw.Draw(img); font = label_font()
        d.text((6, 4), title, fill=(230, 230, 230), font=font)
        for i, (p, name) in enumerate(zip((fig_rgb, build_rgb, heat), ("Figma", "Build", "Diff"))):
            x = i * (w * k + 8)
            d.text((x + 6, 24), name, fill=(200, 200, 200), font=font)
            img.paste(Image.fromarray(p.astype(np.uint8)).resize((w * k, h * k), Image.Resampling.NEAREST), (x, 44))
    img.save(out)


# --- one compare item --------------------------------------------------------------------
def compare_item(fig, spec, shot, run_dir, out_dir, scen_id):
    tol = dict(DEFAULT_TOL); tol.update(spec.get("tolerance", {}))
    S = shot["scale"]
    wl, hl = shot["client"]["wl"], shot["client"]["hl"]
    build = np.asarray(Image.open(os.path.join(run_dir, shot["file"])).convert("RGB")).astype(np.float32)
    to_client = place(fig, spec, wl, hl)
    pad = spec.get("pad", 2)
    ax, ay, aw, ah = region_abs(fig, spec, spec)
    ax, ay, aw, ah = ax - pad, ay - pad, aw + 2 * pad, ah + 2 * pad
    cx, cy = to_client(ax, ay)
    x0, y0 = int(math.floor(cx * S + 0.5)), int(math.floor(cy * S + 0.5))
    # the Figma origin that lands exactly on the screenshot pixel x0, y0
    ax, ay = ax + (x0 - cx * S) / S, ay + (y0 - cy * S) / S
    fa, png = figma_crop(fig, spec, ax, ay, aw, ah, S)
    h, w = fa.shape[:2]
    # the spec's masks in crop pixels (also kept out of the position search)
    mask = np.zeros((h, w), bool)
    for m in spec.get("mask", []):
        mx, my, mw, mh = region_abs(fig, spec, m)
        mp = m.get("pad", 1)
        x1 = int(math.floor((mx - mp - ax) * S)); y1 = int(math.floor((my - mp - ay) * S))
        x2 = int(math.ceil((mx + mw + mp - ax) * S)); y2 = int(math.ceil((my + mh + mp - ay) * S))
        mask[max(0, y1):max(0, y2), max(0, x1):max(0, x2)] = True
    # sample content the spec marks (times, titles): left out before any pixel diff
    if spec.get("specMasks"):
        sp = figspec.load_spec()
        for m in sp.masks(spec["specMasks"]):
            el = dict(sp.element(m["element"]), rect=m["rect"])
            mx, my, mw, mh = figspec.client_rect(sp, el, wl, hl)
            x1 = int(math.floor(mx * S)) - x0 - 1; y1 = int(math.floor(my * S)) - y0 - 1
            x2 = int(math.ceil((mx + mw) * S)) - x0 + 1; y2 = int(math.ceil((my + mh) * S)) - y0 + 1
            mask[max(0, y1):max(0, y2), max(0, x1):max(0, x2)] = True
    radius = max(round(spec.get("search", 0) * S), int(tol["shift"]))
    if radius > 0:
        bx, by = search_offset(fa, build, x0, y0, radius, mask)
    else:
        bx, by = x0, y0
    res = {"id": spec["id"], "shot": shot["name"], "png": png, "node": spec.get("node"), "nodeName": fig.name(spec["node"]) if "node" in spec else None,
           "expected": [x0, y0], "found": [bx, by], "offset": [bx - x0, by - y0]}
    H, W = build.shape[:2]
    if bx < 0 or by < 0 or bx + w > W or by + h > H:
        res.update(status="error", detail=f"region {bx},{by} {w}x{h} outside the screenshot {W}x{H}")
        return res
    bcrop = build[by:by + h, bx:bx + w]
    alpha = fa[..., 3:4] / 255.0
    if "backdrop" in spec:
        # a component drawn without its background (e.g. a time label variant): put it on the
        # colour Figma shows under it, read from the PNG at "at" (relative to the node "node")
        bd = spec["backdrop"]
        bim, box_, boy, bs, _ = fig.frame_png(bd["node"])
        nx, ny, _, _ = fig.bbox(bd["node"])
        px = bim.getpixel((round((nx + bd["at"][0] - box_) * bs), round((ny + bd["at"][1] - boy) * bs)))
        under = np.array(px[:3], np.float32)
        comp = fa[..., :3] * alpha + under * (1 - alpha)
    else:
        comp = fa[..., :3] * alpha + bcrop * (1 - alpha)
        mask |= (alpha[..., 0] < 0.05)
    valid = ~mask
    # brightness differences pixel by pixel, colour differences after a 3x3 blur: Qt draws text
    # with ClearType (coloured fringes), Figma in grey; the blur keeps real colour changes.
    # Fuzzy match: a pixel only counts when no build pixel within 1 px matches it, so sub-pixel
    # rounding (1.25 scale) and anti-aliasing do not count, shapes and colours do.
    lw = np.array([0.299, 0.587, 0.114], np.float32)
    bc3, cc3 = box3(bcrop), box3(comp)
    yb, yc = bcrop @ lw, comp @ lw
    d = np.full((h, w), np.inf, np.float32)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            yb_s = shift2(yb, dx, dy)
            bc_s = shift2(bc3, dx, dy)
            dd = np.maximum(np.abs(yc - yb_s), np.abs(cc3 - bc_s).max(axis=2))
            d = np.minimum(d, dd)
    d_exact = np.maximum(np.abs(yc - yb), np.abs(cc3 - bc3).max(axis=2))
    bad = (d > tol["channel"]) & valid
    core = erode(bad) & valid
    nvalid = max(1, int(valid.sum()))
    frac, cfrac = bad.sum() / nvalid, core.sum() / nvalid
    # colour shift of flat areas (backgrounds, fills): mean difference where the Figma crop is
    # locally flat, so glyph weight and anti-aliasing do not count
    yf = comp @ lw
    flat = valid & (np.abs(yf - box3(comp) @ lw) < 2.0) & (np.abs(box3(comp) - comp).max(axis=2) < 3.0)
    mean = (bcrop - comp)[flat].mean(axis=0) if flat.sum() > 0.05 * nvalid else np.zeros(3)
    shift_ok = abs(bx - x0) <= tol["shift"] and abs(by - y0) <= tol["shift"] if spec.get("search", 0) == 0 else True
    valid_frac = float(valid.mean())
    passed = frac <= tol["fraction"] and cfrac <= tol["core"] and float(np.abs(mean).max()) <= tol["mean"] and shift_ok
    # local check: the worst 24 x 24 (logical px) tile, so a wrong word or icon in a large crop
    # is not diluted by the rest of it
    ts = max(8, round(24 * S))
    worst = 0.0
    for ty in range(0, h, ts // 2):
        for tx in range(0, w, ts // 2):
            v = valid[ty:ty + ts, tx:tx + ts]
            if v.sum() >= ts * ts * 0.25:
                worst = max(worst, float(bad[ty:ty + ts, tx:tx + ts].sum() / v.sum()))
    passed = passed and worst <= tol["tile"]
    minor = frac <= tol["minorFraction"] and cfrac <= tol["minorCore"] and float(np.abs(mean).max()) <= tol["mean"] and shift_ok and worst <= tol["minorTile"]
    status = "pass" if passed else "minor" if minor else "differs"
    # "place" (logical px): how far a searched popup may sit from its Figma position
    misplaced = None
    if spec.get("search", 0) and "place" in tol:
        off_l = (round((bx - x0) / S), round((by - y0) / S))
        if max(abs(off_l[0]), abs(off_l[1])) > tol["place"]:
            misplaced = off_l
            if status == "pass":
                status = "minor"
    if valid_frac < tol["minValid"]:
        status = "inconclusive"  # mostly masked or transparent: too little left to judge
    res.update(fraction=round(float(frac), 4), core=round(float(cfrac), 4), tile=round(worst, 3), mean=[round(float(v), 1) for v in mean],
               masked=round(1 - valid_frac, 3), status=status, tolerance=tol)
    # where it differs, named after the smallest Figma nodes under each cluster
    diffs = []
    if status != "pass":
        cell = max(4, round(4 * S))
        for (x, y, cw, ch, n) in clusters(bad | core, cell)[:4]:
            lx, ly = ax + x / S, ay + y / S
            names = []
            for dn in (fig.descendants(spec["node"]) if "node" in spec else []):
                b = dn.get("absoluteBoundingBox")
                if not b:
                    continue
                if b["x"] < lx + cw / S and b["x"] + b["width"] > lx and b["y"] < ly + ch / S and b["y"] + b["height"] > ly:
                    if not dn.get("children") or dn.get("type") in ("TEXT", "INSTANCE"):
                        names.append(fig.name(dn["id"]))
            uniq = list(dict.fromkeys(names))[:4]
            diffs.append({"at": [round(lx - ax - pad), round(ly - ay - pad), round(cw / S), round(ch / S)], "nodes": uniq})
        if not shift_ok:
            diffs.insert(0, {"offset": [bx - x0, by - y0]})
        if misplaced:
            diffs.insert(0, {"placed": list(misplaced)})
    res["diffs"] = diffs
    # images
    heat = np.zeros((h, w, 3), np.float32)
    heat[..., 0] = np.clip(d_exact * 2, 0, 255) * valid
    heat[..., 1] = np.where(core, 255, 0)
    heat[mask] = heat[mask] * 0.3 + np.array([30, 50, 110])
    base = bcrop * 0.25
    heat = np.clip(base + heat, 0, 255)
    os.makedirs(out_dir, exist_ok=True)
    img_name = f"{scen_id}__{spec['id']}.png"
    title = f"{scen_id} / {spec['id']}  {res['status']}  bad {res['fraction']:.2%} core {res['core']:.2%} tile {worst:.0%} mean {res['mean']} offset {res['offset']}"
    side_by_side(comp, bcrop, heat, title, os.path.join(out_dir, img_name))
    res["image"] = "compare/" + img_name
    return res


# --- measured checks against the spec ------------------------------------------------------
def measure_item(spec_item, shot, run_dir):
    """geometry from UI Automation (logical px, same scale as Figma) and sampled colours against
    the spec values with the spec's tolerances; fonts are listed (UIA has no font information)"""
    sp = figspec.load_spec()
    sid = spec_item["screen"]
    wl, hl, S = shot["client"]["wl"], shot["client"]["hl"], shot["scale"]
    img = np.asarray(Image.open(os.path.join(run_dir, shot["file"])).convert("RGB")).astype(np.float32)
    measured = shot.get("spec", {}) or {}
    results = []
    for el in sp.elements(sid):
        tol = el["tolerance"]
        ex, ey, ew, eh = figspec.client_rect(sp, el, wl, hl)
        r = {"element": el["id"], "name": el.get("name"), "rows": el.get("rows", []), "checks": []}
        if el.get("uia"):
            got = measured.get(el["id"])
            if not got:
                r["checks"].append({"what": "geometry", "pass": False, "detail": "element not found through UI Automation"})
            else:
                d = {"x": got["x"] - ex, "y": got["y"] - ey, "w": got["w"] - ew, "h": got["h"] - eh}
                ok = abs(d["x"]) <= tol["pos"] and abs(d["y"]) <= tol["pos"] and abs(d["w"]) <= tol["size"] and abs(d["h"]) <= tol["size"]
                r["checks"].append({"what": "geometry", "pass": ok, "expected": [round(ex, 1), round(ey, 1), ew, eh],
                                    "measured": [got["x"], got["y"], got["w"], got["h"]],
                                    "detail": "" if ok else "off by " + ", ".join(f"{k} {v:+.1f}" for k, v in d.items() if abs(v) > 0.05)})
        for col in el.get("colors", []):
            px, py = figspec.client_point(sp, el, col["at"], wl, hl)
            X, Y = int(round(px * S)), int(round(py * S))
            patch = img[max(0, Y - 1):Y + 2, max(0, X - 1):X + 2].reshape(-1, 3).mean(axis=0)
            want = np.array([int(col["hex"][i:i + 2], 16) for i in (1, 3, 5)], np.float32)
            diff = float(np.abs(patch - want).max())
            got_hex = "#%02X%02X%02X" % tuple(int(round(v)) for v in patch)
            r["checks"].append({"what": f"colour {col.get('role', '')}", "pass": diff <= tol["color"], "expected": col["hex"],
                                "measured": got_hex, "detail": "" if diff <= tol["color"] else f"{got_hex} instead of {col['hex']} ({diff:.0f} levels)"})
        if el.get("font"):
            f = el["font"]
            r["checks"].append({"what": "font", "pass": None, "expected": f"{f.get('family')} {f.get('weight')} {f.get('size')} px {f.get('color', '')}",
                                "detail": "not measured: UI Automation reports no font; judged by the pixel compare"})
        fails = [c for c in r["checks"] if c["pass"] is False]
        r["status"] = "differs" if fails else "pass"
        results.append(r)
    return results


# --- VIDEO_INDEX ---------------------------------------------------------------------------
def video_index():
    rows = {}
    for line in open(os.path.join(REDESIGN, "VIDEO_INDEX.md"), encoding="utf-8"):
        m = re.match(r"^\| (\d+) \| ([A-Z0-9-]+) \| [^|]* \| ([^|]*) \| ([^|]*) \|.*\| ([^|]*) \|\s*$", line)
        if m:
            rows[m.group(2)] = {"num": int(m.group(1)), "area": m.group(3).strip(), "item": m.group(4).strip(), "status": m.group(5).strip()}
    return rows


# --- report --------------------------------------------------------------------------------
SEVERITY = {"error": 0, "differs": 1, "inconclusive": 2, "minor": 3, "pass": 4}


def describe(c):
    if c["status"] == "error" or c.get("kind") == "measure":
        return f"{c['id']}: {c.get('detail') or c['status']}"
    parts = [f"{c['id']}: {c['fraction']:.1%} px differ, core {c['core']:.1%}, worst tile {c.get('tile', 0):.0%}"]
    if c["status"] == "minor":
        parts.insert(0, "minor")
    if c["status"] == "inconclusive":
        parts.insert(0, f"INCONCLUSIVE ({c['masked']:.0%} masked or transparent)")
    if max(abs(v) for v in c["mean"]) > 3:
        parts.append(f"mean build-Figma {c['mean']}")
    if c["offset"] != [0, 0]:
        parts.append(f"offset {c['offset']} px")
    for dd in c.get("diffs", []):
        if "placed" in dd:
            parts.append(f"opens {dd['placed']} logical px from its Figma position")
    for dd in [x for x in c.get("diffs", []) if "at" in x][:2]:
        if "at" in dd:
            parts.append(f"at {dd['at']}" + (f" ({', '.join(dd['nodes'])})" if dd["nodes"] else ""))
    return "; ".join(parts)


def run_compare(run_dir):
    run = json.load(open(os.path.join(run_dir, "run.json"), encoding="utf-8-sig"))
    fig = Figma()
    vi = video_index()
    out_dir = os.path.join(run_dir, "compare")
    results = []
    for sc in run["scenarios"]:
        r = {"id": sc["id"], "title": sc.get("title", ""), "rows": sc.get("rows", []), "status": sc.get("status"),
             "error": sc.get("error"), "checks": sc.get("checks", []), "human": sc.get("human", []),
             "notes": sc.get("notes", []), "seconds": sc.get("seconds"), "compares": []}
        shots = {s["name"]: s for s in sc.get("shots", [])}
        for spec in sc.get("compare", []):
            if spec.get("measure") == "spec" and spec.get("shot") in shots:
                # one compare entry per spec element, in the same shape as the pixel compares
                for m in measure_item(spec, shots[spec["shot"]], run_dir):
                    bad = [c for c in m["checks"] if c["pass"] is False]
                    r["compares"].append({"id": f"{spec['id']}:{m['element']}", "status": m["status"], "kind": "measure",
                                          "checks": m["checks"], "rows": m["rows"] or spec.get("rows", r["rows"]),
                                          "detail": "; ".join(f"{c['what']} {c['detail']}" for c in bad)})
                continue
            if spec.get("shot") not in shots:
                r["compares"].append({"id": spec["id"], "status": "error", "detail": f"no shot '{spec.get('shot')}'", "rows": spec.get("rows", r["rows"])})
                continue
            try:
                c = compare_item(fig, spec, shots[spec["shot"]], run_dir, out_dir, sc["id"])
            except Exception as e:  # a broken spec must not stop the report
                c = {"id": spec["id"], "status": "error", "detail": f"{type(e).__name__}: {e}"}
            c["rows"] = spec.get("rows", r["rows"])
            r["compares"].append(c)
        results.append(r)
    # rows
    rows = {}
    for r in results:
        for c in r["compares"]:
            for row in c["rows"]:
                rows.setdefault(row, {"compares": [], "checks": [], "human": [], "errors": [], "scenarios": []})["compares"].append((r["id"], c))
        covered = list(dict.fromkeys(list(r["rows"]) + [row for c in r["compares"] for row in (c.get("rows") or [])]))
        for row in covered:
            e = rows.setdefault(row, {"compares": [], "checks": [], "human": [], "errors": [], "scenarios": []})
            e["scenarios"].append(r["id"])
            e["checks"] += [(r["id"], ch) for ch in r["checks"]]
            e["human"] += [(r["id"], h) for h in r["human"]]
            if r["error"]:
                e["errors"].append((r["id"], r["error"]))
    row_out = []
    for row, e in rows.items():
        comps = [c for _, c in e["compares"]]
        failed = [c for c in comps if c["status"] != "pass"]
        failed_checks = [ch for _, ch in e["checks"] if not ch["pass"]]
        if e["errors"] or any(c["status"] == "error" for c in comps):
            status = "error"
        elif failed_checks or any(c["status"] == "differs" for c in comps):
            status = "differs"
        elif any(c["status"] == "inconclusive" for c in comps):
            status = "inconclusive"
        elif any(c["status"] == "minor" for c in comps):
            status = "near-match"
        elif comps or e["checks"]:
            status = "auto-passed"
        else:
            status = "human only"
        info = vi.get(row, {})
        row_out.append({"row": row, "num": info.get("num"), "item": info.get("item", "?"), "indexStatus": info.get("status", "?"),
                        "status": status, "compares": f"{len(comps) - len(failed)}/{len(comps)}",
                        "checks": f"{len(e['checks']) - len(failed_checks)}/{len(e['checks'])}",
                        "differences": [f"{sid}/{describe(c)}" for sid, c in sorted(e["compares"], key=lambda sc: SEVERITY.get(sc[1]["status"], 9)) if c["status"] != "pass"]
                        + [f"{sid}/check '{ch['check']}' failed: {ch['detail']}" for sid, ch in e["checks"] if not ch["pass"]]
                        + [f"{sid}: {err}" for sid, err in e["errors"]],
                        "human": [f"{sid}: {h}" for sid, h in e["human"]],
                        "images": [c.get("image") for _, c in e["compares"] if c.get("image")]})
    row_out.sort(key=lambda x: (x["num"] or 9999, x["row"]))
    report = {"run": run.get("run"), "build": run.get("build"), "started": run.get("started"), "seconds": run.get("seconds"),
              "cleanup": run.get("cleanup"), "rows": row_out, "scenarios": results}
    json.dump(report, open(os.path.join(run_dir, "report.json"), "w", encoding="utf-8"), indent=1)
    write_md(report, os.path.join(run_dir, "report.md"))
    counts = {}
    for x in row_out:
        counts[x["status"]] = counts.get(x["status"], 0) + 1
    print("rows:", ", ".join(f"{k} {v}" for k, v in sorted(counts.items())))
    print("report:", os.path.join(run_dir, "report.md"))


def write_md(rep, path):
    L = [f"# Verification run {rep['run']}", "",
         f"- Build: {rep.get('build')}", f"- Started: {rep.get('started')}, took {rep.get('seconds')} s",
         f"- Cleanup: {rep.get('cleanup')}",
         "- Auto-passed rows are a proposal for review: the main session checks them and marks VIDEO_INDEX.",
         "- near-match: only small differences (stroke weight, 1-2 px edges): a glance at the images decides.",
         "- differs: a real difference was found (listed per row); inconclusive: the compared area was mostly masked.", ""]
    counts = {}
    for x in rep["rows"]:
        counts[x["status"]] = counts.get(x["status"], 0) + 1
    L.append("Rows: " + ", ".join(f"{k} {v}" for k, v in sorted(counts.items())))
    L += ["", "| # | Row | Item | Index status | Result | Compares | Checks | Main difference | Human checks |", "|---|---|---|---|---|---|---|---|---|"]
    for x in rep["rows"]:
        diff = x["differences"][0] if x["differences"] else ""
        L.append(f"| {x['num'] or ''} | {x['row']} | {x['item'][:50]} | {x['indexStatus'][:24]} | **{x['status']}** | {x['compares']} | {x['checks']} | {diff.replace('|', '/')} | {len(x['human'])} |")
    L += ["", "## Differences and human checks per row", ""]
    for x in rep["rows"]:
        if not x["differences"] and not x["human"]:
            continue
        L.append(f"### {x['num'] or ''} {x['row']} {x['item'][:60]} ({x['status']})")
        for d in x["differences"]:
            L.append(f"- differs: {d}")
        for h in x["human"]:
            L.append(f"- human check: {h}")
        for im in x["images"][:6]:
            L.append(f"- image: {im}")
        L.append("")
    L += ["## Scenarios", ""]
    for s in rep["scenarios"]:
        L.append(f"### {s['id']} ({s['status']}, {s.get('seconds')} s): {s['title']}")
        if s.get("error"):
            L.append(f"- ERROR: {s['error']}")
        for c in s["compares"]:
            if c.get("kind") == "measure":
                L.append(f"- {c['id']}: {c['status']} (measured: " + "; ".join(
                    f"{k['what']} " + ("pass" if k["pass"] else "not measured" if k["pass"] is None else "FAIL") +
                    (f" exp {k.get('expected')} got {k.get('measured')}" if k.get("measured") is not None else "") for k in c["checks"]) + ")")
                continue
            L.append(f"- {c['id']}: {c['status']}" + (f" ({describe(c)})" if c["status"] != "pass" else f" (bad {c.get('fraction', 0):.2%}, core {c.get('core', 0):.2%})") + (f" [{c['image']}]" if c.get("image") else ""))
        for ch in s["checks"]:
            L.append(f"- check {ch['check']}: {'pass' if ch['pass'] else 'FAIL ' + ch['detail']}")
        for n in s.get("notes", []):
            L.append(f"- note: {n}")
        L.append("")
    open(path, "w", encoding="utf-8").write("\n".join(L) + "\n")


# --- authoring helpers ---------------------------------------------------------------------
def validate(files):
    fig = Figma()
    problems = 0
    for f in files:
        data = json.load(open(f, encoding="utf-8-sig"))
        for se in data["sessions"]:
            for sc in se["scenarios"]:
                for c in sc.get("compare", []):
                    for key in ("ref", "node"):
                        if key in c and c[key] not in fig.nodes:
                            print(f"{os.path.basename(f)} {sc['id']}/{c['id']}: {key} {c[key]} not in figma_file.json"); problems += 1
                    for m in c.get("mask", []):
                        if "node" in m and m["node"] not in fig.nodes:
                            print(f"{os.path.basename(f)} {sc['id']}/{c['id']}: mask node {m['node']} not found"); problems += 1
                    if "ref" in c and c["ref"] in fig.nodes:
                        try:
                            fig.frame_png(c["ref"])
                        except KeyError as e:
                            print(f"{os.path.basename(f)} {sc['id']}/{c['id']}: {e}"); problems += 1
    print(f"validate: {problems} problem(s)")
    return problems


def list_nodes(nid, depth=4):
    fig = Figma()
    rx, ry, _, _ = fig.bbox(nid)

    def walk(n, d):
        b = n.get("absoluteBoundingBox")
        if b:
            extra = f" '{n.get('characters')}'" if n.get("type") == "TEXT" else ""
            hid = " (hidden)" if n.get("visible") is False else ""
            print("  " * d + f"{n['type']} {n['name']!r} {n['id']} x={b['x'] - rx:.0f} y={b['y'] - ry:.0f} w={b['width']:.0f} h={b['height']:.0f}{extra}{hid}")
        if d < depth:
            for c in n.get("children", []):
                walk(c, d + 1)
    walk(fig.node(nid), 0)


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "--validate":
        sys.exit(1 if validate(sys.argv[2:]) else 0)
    if len(sys.argv) >= 3 and sys.argv[1] == "--nodes":
        list_nodes(sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 4)
        sys.exit(0)
    if len(sys.argv) != 2:
        print(__doc__); sys.exit(2)
    run_compare(sys.argv[1])
