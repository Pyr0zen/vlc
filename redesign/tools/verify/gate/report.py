"""Beta gate report: merges the parts of a gate run folder into gate-report.md / gate-report.json,
draws one contact sheet per part (and per theme pass) and keeps review.json, the list of every
screenshot a person (or the reviewing session) must look at.

    python report.py <gate run folder>

UI items pass only when their screenshots were looked at: in review.json each shot has
"viewed" (true once looked at), "seen" (what the screenshot shows, in words) and "verdict"
("match" or "differs"). A UI item whose measurements passed but whose screenshots are not all
viewed is "not verified"; one "differs" makes it fail. Running report.py again keeps the review
entries already filled in and adds new shots."""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

PARTS = ["footprint", "branding", "screens", "playback", "quit", "perf", "smoke", "soak"]
UI_PARTS = {"screens", "playback", "smoke", "soak", "branding"}


def load(path):
    with open(path, encoding="utf-8-sig") as f:
        return json.load(f)


def as_list(x):
    if x is None:
        return []
    return x if isinstance(x, list) else [x]


def contact_sheet(run, shots, out, title, cols=4, width=420):
    """Thumbnails of the shots (relative paths), each labelled, in one PNG."""
    shots = [s for s in shots if os.path.exists(os.path.join(run, s["rel"]))]
    if not shots:
        return None
    try:
        font = ImageFont.load_default(size=15)
        big = ImageFont.load_default(size=22)
    except TypeError:
        font = big = ImageFont.load_default()
    thumbs = []
    for s in shots:
        im = Image.open(os.path.join(run, s["rel"])).convert("RGB")
        h = int(im.height * width / im.width)
        thumbs.append((s, im.resize((width, h), Image.LANCZOS)))
    th = max(t.height for _, t in thumbs)
    cell_h = th + 26
    rows = (len(thumbs) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (width + 10) + 10, rows * (cell_h + 10) + 50), (40, 40, 40))
    d = ImageDraw.Draw(sheet)
    d.text((10, 12), title, fill=(255, 255, 255), font=big)
    for i, (s, t) in enumerate(thumbs):
        x = 10 + (i % cols) * (width + 10)
        y = 50 + (i // cols) * (cell_h + 10)
        sheet.paste(t, (x, y))
        d.text((x + 2, y + th + 4), s["label"], fill=(230, 230, 230), font=font)
    sheet.save(out)
    return out


def collect_shots(run):
    """Every shot of the run: {rel, part, state, should, label}."""
    out = []
    for part in PARTS:
        pj = os.path.join(run, part, "shots.json")
        if not os.path.exists(pj):
            continue
        for s in as_list(load(pj)):
            rel = s.get("rel") or "%s/%s" % (part, s["file"])
            sub = s.get("pass") or ""
            out.append({"rel": rel.replace("\\", "/"), "part": part, "pass": sub, "state": s.get("state", ""),
                        "should": s.get("should", ""),
                        "label": "%s%s" % (sub + " " if sub else "", os.path.splitext(os.path.basename(rel))[0])})
            # the player's other windows of a "windows": "all" shot (dialogs such as About)
            for e in as_list(s.get("extra")):
                erel = os.path.dirname(rel).replace("\\", "/") + "/" + e["file"]
                out.append({"rel": erel, "part": part, "pass": sub, "state": s.get("state", ""),
                            "should": s.get("should", "") + " (window '%s')" % e.get("title", ""),
                            "label": "%s%s" % (sub + " " if sub else "", os.path.splitext(e["file"])[0])})
    perf = os.path.join(run, "perf")
    if os.path.isdir(perf):
        for f in sorted(os.listdir(perf)):
            if f.endswith(".png"):
                out.append({"rel": "perf/" + f, "part": "perf", "pass": "", "state": f[:-4],
                            "should": "the player playing the measured file (stock VLC or the build)", "label": f[:-4]})
    return out


def update_review(run, shots):
    path = os.path.join(run, "review.json")
    review = load(path) if os.path.exists(path) else {}
    review.setdefault("how", "Open every shot (or its contact sheet, then the shot itself where in doubt), write what it "
                             "shows in 'seen', set 'viewed' true and 'verdict' to 'match' (shows what 'should' says) or "
                             "'differs'. Then run report.py again.")
    entries = review.setdefault("shots", {})
    for s in shots:
        e = entries.setdefault(s["rel"], {"viewed": False, "seen": "", "verdict": ""})
        e["part"] = s["part"]
        e["state"] = s["state"]
        e["should"] = s["should"]
    with open(path, "w", encoding="utf-8") as f:
        json.dump(review, f, indent=1, ensure_ascii=False)
    return entries


def view_status(entries, rels):
    """verified / differs / not verified (n of m viewed) for a set of shots."""
    rels = [r for r in rels if r]
    if not rels:
        return "no screenshot"
    es = [entries.get(r, {}) for r in rels]
    if any(e.get("verdict") == "differs" for e in es):
        return "FAIL (screenshot differs)"
    viewed = [e for e in es if e.get("viewed") and e.get("verdict") == "match"]
    if len(viewed) == len(es):
        return "verified (%d screenshot(s) viewed)" % len(es)
    return "not verified (%d of %d screenshot(s) viewed)" % (len(viewed), len(es))


def main():
    run = os.path.abspath(sys.argv[1])
    results = {}
    for part in PARTS:
        d = os.path.join(run, part)
        if not os.path.isdir(d):
            continue
        rj = os.path.join(d, "result.json")
        if os.path.exists(rj):
            results[part] = load(rj)
        for f in sorted(os.listdir(d)):
            if f.startswith("error-") and f.endswith(".json"):
                err = load(os.path.join(d, f))
                if part not in results or results[part].get("verdict") != "error":
                    results.setdefault(part, err)
                    if not os.path.exists(rj):
                        results[part] = err
    shots = collect_shots(run)
    entries = update_review(run, shots)

    # contact sheets: one per part, the screens one per theme pass
    sheets = {}
    groups = {}
    for s in shots:
        key = s["part"] + ("-" + s["pass"] if s["pass"] else "")
        groups.setdefault(key, []).append(s)
    for key, ss in groups.items():
        out = os.path.join(run, "contact-%s.png" % key)
        if contact_sheet(run, ss, out, "%s (%d shots)" % (key, len(ss))):
            sheets[key] = os.path.basename(out)

    # items: measured verdict + viewing status for the UI parts
    rows = []
    for part in PARTS:
        r = results.get(part)
        if not r:
            rows.append({"part": part, "measured": "not run", "viewed": "", "evidence": ""})
            continue
        rels = [s["rel"] for s in shots if s["part"] == part]
        if part == "branding":
            rels = sorted({h.get("shot") for h in as_list(r.get("hits")) if h.get("shot")})
        viewed = view_status(entries, rels) if part in UI_PARTS else ""
        if part == "branding" and not rels:
            viewed = "no screen hits to view"
        ev = ", ".join(sorted(v for k, v in sheets.items() if k.split("-")[0] == part)) or "%s/result.json" % part
        rows.append({"part": part, "measured": r.get("verdict", "?"), "viewed": viewed, "evidence": ev})

    def overall(row):
        m = row["measured"]
        if m in ("not run",):
            return "not run"
        if m == "pass" or m.startswith("measured pass"):
            if row["part"] in UI_PARTS and not (row["viewed"].startswith("verified") or row["viewed"].startswith("no screen")):
                return "not verified" if not row["viewed"].startswith("FAIL") else "FAIL"
            return "pass"
        return m

    for row in rows:
        row["result"] = overall(row)

    lines = ["# Beta gate report", "", "Run folder: `%s`" % os.path.basename(run), ""]
    lines += ["| Part | Result | Measured | Screenshots viewed | Evidence |", "|---|---|---|---|---|"]
    for row in rows:
        lines.append("| %s | **%s** | %s | %s | %s |" % (row["part"], row["result"], row["measured"], row["viewed"], row["evidence"]))
    lines.append("")
    lines.append("A UI part passes only when every screenshot in review.json is viewed and matches; "
                 "'not verified' = measurements passed, screenshots not (all) looked at yet.")
    lines.append("")

    r = results.get("screens")
    if r and r.get("items"):
        lines += ["## Screens", "", r.get("rule", ""), "",
                  "| Pass | Screen | Checks | Status | Screenshots | Viewed |", "|---|---|---|---|---|---|"]
        for it in as_list(r["items"]):
            checks = "; ".join("%s %s" % (c["check"], "ok" if c["pass"] else "FAIL " + str(c.get("detail", ""))) for c in as_list(it.get("checks")))
            st = it["status"] + (" (%s)" % it["error"] if it.get("error") else "")
            rels = ["screens/" + x for x in as_list(it.get("shots"))]
            lines.append("| %s | %s | %s | %s | %s | %s |" % (it["pass"], it["title"], checks, st,
                                                            ", ".join(os.path.basename(x) for x in rels), view_status(entries, rels)))
        lines.append("")
    r = results.get("playback")
    if r and r.get("rows"):
        lines += ["## Playback matrix", "", r.get("rule", ""), "",
                  "| File | Plays | Seeks | Audio track | Subtitle track | Verdict | Details | Viewed |", "|---|---|---|---|---|---|---|---|"]
        for row in as_list(r["rows"]):
            det = "; ".join("%s" % v for v in (row.get("checks") or {}).values())
            if row.get("dialog"):
                det += "; " + row["dialog"]
            if row.get("error"):
                det += "; ERROR " + row["error"]
            if row.get("log_errors"):
                det += "; %d log error line(s) in %s" % (len(row["log_errors"]), row["log"])
            rels = ["playback/" + x for x in as_list(row.get("shots"))]
            lines.append("| %s | %s | %s | %s | %s | **%s** | %s | %s |" % (row["file"], row["plays"], row["seeks"], row.get("audio_track", ""),
                                                                    row.get("subtitle_track", ""), row["verdict"], det, view_status(entries, rels)))
        lines.append("")
    r = results.get("quit")
    if r and "tries" in r:
        lines += ["## Quit test", "", r.get("rule", ""), "",
                  "- clean exits: %s of %s (Ctrl+Q %s, WM_CLOSE %s), slowest %s s" % (r["clean"], r["tries"], r["ctrl_q_clean"], r["wm_close_clean"], r.get("exit_seconds_max")),
                  "- players left: %s" % (", ".join(as_list(r.get("players_left"))) or "0"),
                  "- crash / WER events: %d" % len(as_list(r.get("crash_events"))), ""]
        for e in as_list(r.get("crash_events")):
            lines.append("  - %s %s: %s" % (e["time"], e["provider"], e["message"][:200]))
        for t in as_list(r.get("detail")):
            if t["state"] != "clean":
                lines.append("  - try %s %s %s: %s %s" % (t["try"], t["quit"], t["file"], t["state"], t.get("note") or ""))
        lines.append("")
    r = results.get("perf")
    if r and r.get("comparison"):
        lines += ["## Performance vs stock VLC 4", "", r.get("rule", ""), "", "Background CPU before: %s %%" % r.get("background_cpu_pct"), "",
                  "| Measure | Stock | Build | Limit | Pass |", "|---|---|---|---|---|"]
        for c in as_list(r["comparison"]):
            lines.append("| %s | %s | %s | %s | %s |" % (c["measure"], c["stock"], c["build"], c["limit"], c["pass"]))
        lines.append("")
    r = results.get("soak")
    if r and "samples" in r:
        lines += ["## Soak", "", r.get("rule", ""), "",
                  "- %s min, %s samples, %s responsiveness checks; crash: %s; WER events: %d; freezes: %s; playback stalls: %s" % (
                      r["minutes"], r["samples"], r["checks"], r.get("crash") or "none", len(as_list(r.get("crash_events"))), r["freezes"], r["playback_stalls"]),
                  "- private bytes: base %s MB, growth %s MB, trend %s MB/h; handles +%s, threads +%s" % (
                      r.get("private_base_mb"), r.get("private_growth_mb"), r.get("private_trend_mb_per_hour"), r.get("handle_growth"), r.get("thread_growth")), ""]
    r = results.get("smoke")
    if r and r.get("checks"):
        lines += ["## Smoke", "", r.get("rule", ""), "", "| Step | Pass | Detail |", "|---|---|---|"]
        for k, v in r["checks"].items():
            lines.append("| %s | %s | %s |" % (k, v.get("pass"), v.get("detail")))
        lines += ["", "%s s" % r.get("seconds"), ""]
    r = results.get("footprint")
    if r and "changes" in r:
        lines += ["## Portable footprint", "", r.get("rule", ""), ""]
        for k, v in (r.get("targets") or {}).items():
            lines.append("- %s: %s" % (k, v))
        lines.append("- changes: %d" % r.get("change_count", 0))
        for c in as_list(r.get("changes"))[:40]:
            lines.append("  - %s" % c)
        lines.append("")
    r = results.get("branding")
    if r and "hits" in r:
        lines += ["## Branding", "", r.get("rule", ""), "",
                  "- names checked: %s (%s), libVLC internal names: %s; screen texts checked: %s" % (
                      r.get("names_checked"), r.get("names_source"), r.get("internal_names"), r.get("screen_texts_checked")),
                  "- exe version info: %s" % ", ".join("%s=%s" % kv for kv in (r.get("version_info") or {}).items() if kv[1]), ""]
        if r.get("note"):
            lines += ["- note: " + r["note"], ""]
        for h in as_list(r.get("hits")):
            lines.append("  - %s: `%s`%s" % (h["where"], h["what"], (" (x%s, e.g. %s)" % (h.get("count"), ", ".join(as_list(h.get("shots"))))) if h.get("shots") else ""))
        lines.append("")
    for part, r in results.items():
        if r.get("verdict") == "error":
            lines += ["## %s stopped" % part, "", r.get("error", ""), ""]

    with open(os.path.join(run, "gate-report.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    with open(os.path.join(run, "gate-report.json"), "w", encoding="utf-8") as f:
        json.dump({"rows": rows, "contact_sheets": sheets}, f, indent=1)
    for row in rows:
        print("%-10s %-14s %s" % (row["part"], row["result"], row["viewed"]))
    print("report: %s" % os.path.join(run, "gate-report.md"))


if __name__ == "__main__":
    main()
