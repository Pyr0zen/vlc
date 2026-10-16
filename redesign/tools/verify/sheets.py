"""Contact sheets and per-group manifests for a compared run (called by compare.py).

For every compared row: one sheet per screen group, sheets/<group>/<row>.png in the run folder:
a header (row id, number, item, status, flags), the row's region compares (Figma | build | diff)
and one element panel per spec state (Figma | build | diff of the area the row's elements cover,
same scale, the spec's element boxes drawn on top: green pass, yellow near, red differs, grey
mask / unchecked; dashed = element from a derived spec part).
manifest-<group>.json lists, per row: status, supporting elements, weak flags, sheets, derived
spec elements, known regressions, and needs_video (behaviour, or nothing in Figma) vs figma_only.
"""
import json
import math
import os
import re

import numpy as np
from PIL import Image, ImageDraw

GROUPS = {
    "player": {"bar", "bars"},
    "sidebars-menus-panels": {"tracks", "sidebar", "sidebar-subs", "queue", "menu", "menus"},
    "settings-dialogs": {"settings", "advanced"},
    "library-customize": {"library"},
}
SCENARIO_GROUP = {"hide-ui": "player"}  # Hide UI is driven from the right-click menu session
BEHAVIOUR = re.compile(r"\b(hover|transition|animat\w*|opens?|closes?|show/hide|appear\w*|disappear\w*|drag\w*|click\w*|switch\w*|"
                       r"instantly|auto-hide|timing|toast|morph|slides?|fades?|scroll\w*|shortcut|keyboard|behaviou?r|jumps?)\b", re.I)
COLORS = {"pass": (60, 200, 90), "minor": (230, 200, 40), "differs": (235, 60, 60)}
MAX_W = 1400


def group_of(scen):
    if scen["id"] in SCENARIO_GROUP:
        return SCENARIO_GROUP[scen["id"]]
    for g, sessions in GROUPS.items():
        if scen.get("session") in sessions:
            return g
    return "player"


def needs_video(info, has_checks):
    fig = (info.get("figma") or "").strip().lower()
    no_figma = fig in ("", "-", "none") or fig.startswith("none") or fig.startswith("- (")
    behaviour = bool(BEHAVIOUR.search(info.get("item", "") or ""))
    return no_figma or behaviour or has_checks, ("no Figma frame" if no_figma else "behaviour" if (behaviour or has_checks) else "")


def _font():
    from PIL import ImageFont
    try:
        return ImageFont.load_default(size=16)
    except TypeError:
        return ImageFont.load_default()


def _fit(im, w=MAX_W):
    if im.width > w:
        im = im.resize((w, max(1, round(im.height * w / im.width))), Image.Resampling.LANCZOS)
    return im


def element_panel(cmp, fig, shots, run_dir, els):
    """Figma | build | diff of the union of these element entries, boxes drawn on top"""
    shot = shots.get(els[0]["shot"])
    if not shot:
        return None
    S = shot["scale"]
    xs = [e["box"][0] for e in els]; ys = [e["box"][1] for e in els]
    xe = [e["box"][0] + e["box"][2] for e in els]; ye = [e["box"][1] + e["box"][3] for e in els]
    pad = 10
    cx0, cy0 = max(0.0, min(xs) - pad), max(0.0, min(ys) - pad)
    cx1, cy1 = min(shot["client"]["wl"], max(xe) + pad), min(shot["client"]["hl"], max(ye) + pad)
    if cx1 - cx0 < 4 or cy1 - cy0 < 4:
        return None
    # Figma absolute coordinates of the same area (abs - box is the same translation for all)
    dx, dy = els[0]["abs"][0] - els[0]["box"][0], els[0]["abs"][1] - els[0]["box"][1]
    X0, Y0 = int(math.floor(cx0 * S)), int(math.floor(cy0 * S))
    w, h = int(math.ceil((cx1 - cx0) * S)), int(math.ceil((cy1 - cy0) * S))
    gx, gy = X0 / S + dx, Y0 / S + dy
    fa, _ = cmp.figma_crop(fig, {"ref": els[0]["placing"]["ref"]}, gx, gy, w / S, h / S, S)
    build = cmp.load_shot(run_dir, shot["file"])[Y0:Y0 + fa.shape[0], X0:X0 + fa.shape[1]]
    hh, ww = build.shape[:2]
    fa = fa[:hh, :ww]
    alpha = fa[..., 3:4] / 255.0
    figc = fa[..., :3] * alpha + build * (1 - alpha)
    diff = np.clip(np.abs(figc - build).max(axis=2) * 3, 0, 255)
    heat = np.stack([diff, diff * 0.25, diff * 0.25], axis=2) + build * 0.2
    panels = [Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)) for a in (figc, build, heat)]
    for pi in (0, 1):
        d = ImageDraw.Draw(panels[pi])
        for e in els:
            bx, by, bw, bh = e["box"]
            r = [(bx - cx0) * S, (by - cy0) * S, (bx + bw - cx0) * S, (by + bh - cy0) * S]
            col = COLORS.get(e["status"], (150, 150, 150))
            if e.get("derived"):
                for k in range(0, int(r[2] - r[0]), 8):  # dashed: derived spec part
                    d.line([r[0] + k, r[1], min(r[2], r[0] + k + 4), r[1]], fill=col, width=2)
                    d.line([r[0] + k, r[3], min(r[2], r[0] + k + 4), r[3]], fill=col, width=2)
                for k in range(0, int(r[3] - r[1]), 8):
                    d.line([r[0], r[1] + k, r[0], min(r[3], r[1] + k + 4)], fill=col, width=2)
                    d.line([r[2], r[1] + k, r[2], min(r[3], r[1] + k + 4)], fill=col, width=2)
            else:
                d.rectangle(r, outline=col, width=2)
    k = 1
    while hh * k < 140 and k < 4 and ww * (k + 1) * 3 < 3000:
        k += 1
    if k > 1:
        panels = [pi_.resize((ww * k, hh * k), Image.Resampling.NEAREST) for pi_ in panels]
        ww, hh = ww * k, hh * k
    gap = 8
    out = Image.new("RGB", (ww * 3 + gap * 2, hh + 22), (24, 24, 24))
    dr = ImageDraw.Draw(out); f = _font()
    for i, (pimg, name) in enumerate(zip(panels, ("Figma", "Build", "Diff"))):
        out.paste(pimg, (i * (ww + gap), 22))
        dr.text((i * (ww + gap) + 4, 2), name, fill=(220, 220, 220), font=f)
    return out


def make_sheets(cmp, fig, report, run, run_dir, vi, known):
    shots_by_scen = {sc["id"]: {s["name"]: s for s in sc.get("shots", [])} for sc in run["scenarios"]}
    scen_by_id = {sc["id"]: sc for sc in run["scenarios"]}
    rep_scen = {s["id"]: s for s in report["scenarios"]}
    manifests = {g: [] for g in GROUPS}
    row_by_id = {x["row"]: x for x in report["rows"]}
    # which groups each row appears in
    row_groups = {}
    for s in report["scenarios"]:
        g = group_of(dict(scen_by_id.get(s["id"], {}), id=s["id"]))
        for c in s["compares"]:
            if c.get("status") in ("skipped", "unchecked"):
                continue
            for row in c.get("rows") or []:
                row_groups.setdefault(row, {}).setdefault(g, []).append((s["id"], c))
        for row in s["rows"]:
            row_groups.setdefault(row, {}).setdefault(g, [])
    f = _font()
    for row, groups in row_groups.items():
        x = row_by_id.get(row)
        if not x:
            continue
        info = vi.get(row, {})
        has_checks = x.get("checks", "0/0") != "0/0"
        nv, why = needs_video(info, has_checks)
        for g, entries in groups.items():
            parts = []
            regions = [(sid, c) for sid, c in entries if c.get("kind") != "element" and c.get("image")]
            for sid, c in regions:
                try:
                    parts.append(_fit(Image.open(os.path.join(run_dir, c["image"])).convert("RGB")))
                except OSError:
                    pass
            by_state = {}
            for sid, c in entries:
                if c.get("kind") == "element" and c.get("box"):
                    by_state.setdefault((sid, c.get("spec_source")), []).append(c)
            for (sid, src), els in by_state.items():
                try:
                    pnl = element_panel(cmp, fig, shots_by_scen.get(sid, {}), run_dir, els)
                except Exception:
                    pnl = None
                if pnl is not None:
                    hdr = Image.new("RGB", (pnl.width, 20), (40, 40, 40))
                    ImageDraw.Draw(hdr).text((4, 2), f"{sid}: spec {src}", fill=(230, 230, 230), font=f)
                    both = Image.new("RGB", (pnl.width, pnl.height + 20)); both.paste(hdr, (0, 0)); both.paste(pnl, (0, 20))
                    parts.append(_fit(both))
            if not parts:
                continue
            if len(parts) > 8:  # keep sheets readable: the first 8 panels, the rest in the report
                parts = parts[:8]
            status = x["status"]
            kn = known.get(row)
            title = f"{row} (#{x.get('num')})  {x.get('item', '')[:90]}"
            sub = f"{status}" + (f"  KNOWN REGRESSION: {kn}" if kn and status == 'differs' else "") + \
                  (f"  WEAK: {'; '.join(x.get('weak', []))}" if x.get("weak") else "") + \
                  ("  needs video" if nv else "  Figma only")
            W = max(p.width for p in parts)
            H = 52 + sum(p.height + 8 for p in parts)
            sheet = Image.new("RGB", (W, H), (18, 18, 18))
            d = ImageDraw.Draw(sheet)
            d.text((8, 6), title, fill=(240, 240, 240), font=f)
            d.text((8, 28), sub, fill=(250, 190, 80) if status != "auto-passed" else (120, 220, 130), font=f)
            y = 52
            for p in parts:
                sheet.paste(p, (0, y)); y += p.height + 8
            rel = os.path.join("sheets", g, re.sub(r"[^A-Za-z0-9-]", "_", row) + ".png")
            os.makedirs(os.path.join(run_dir, "sheets", g), exist_ok=True)
            sheet.save(os.path.join(run_dir, rel), optimize=True)
            derived = sorted({c.get("path") for _, c in entries if c.get("kind") == "element" and c.get("derived")})
            sources = sorted({c.get("spec_source") for _, c in entries if c.get("kind") == "element"})
            manifests[g].append({
                "row": row, "num": x.get("num"), "item": x.get("item"), "area": info.get("area"),
                "status": "differs (known regression, fix pending)" if kn and status == "differs" else status,
                "known_regression": kn if kn and status == "differs" else None,
                "support": x.get("support", []), "weak": x.get("weak", []),
                "differences": x.get("differences", [])[:12], "human_checks": x.get("human", []),
                "sheet": rel.replace("\\", "/"), "needs_video": nv, "figma_only": not nv, "needs_video_reason": why,
                "figma_pngs": info.get("figma"), "spec_sources": sources,
                "derived_spec_elements": derived,
                "derived_note": "elements from spec parts built by spec.py (Controls popups / sidebars / queue), not from the spec files" if derived else None})
    paths = {}
    for g, rows in manifests.items():
        if not rows:
            continue
        rows.sort(key=lambda r: (r["num"] or 9999, r["row"]))
        counts = {}
        for r in rows:
            counts[r["status"]] = counts.get(r["status"], 0) + 1
        man = {"run": report.get("run"), "build": report.get("build"), "group": g, "counts": counts,
               "legend": {"boxes": "green pass, yellow near, red differs, grey mask / unchecked, dashed = derived spec part",
                          "needs_video": "behaviour, or nothing in Figma: confirm against the video",
                          "figma_only": "confirm against Figma only"},
               "rows": rows}
        p = os.path.join(run_dir, f"manifest-{g}.json")
        json.dump(man, open(p, "w", encoding="utf-8"), indent=1)
        paths[g] = p
    return paths
