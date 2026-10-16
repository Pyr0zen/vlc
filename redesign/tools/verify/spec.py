"""Machine-readable Figma spec: the one place the harness reads it from.

Interface used by the harness (keep it when the real spec lands; only the loader changes):
  spec = load_spec()                  the spec (or the fixture until the real one exists)
  spec.screens()                      screen ids
  spec.screen(sid)                    {"id", "figmaFrame", "size": [w, h]}
  spec.elements(sid)                  elements of a screen
  spec.element(eid)                   one element
  spec.rows_for(eid)                  VIDEO_INDEX row IDs of an element
  spec.elements_for_row(row)          elements that belong to a row
  spec.masks(sid)                     regions to leave out of pixel diffs: [{"element", "rect", "reason"}]
  client_rect(el, client_w, client_h) the element's rect in client logical px (anchor applied)

Element fields ASSUMED until the real schema (wip/verify-spec) is known; map them in _normalise():
  id            unique element id, e.g. "player.control-bar.play"
  screen        screen id, e.g. "player"
  name          readable name
  figmaNode     Figma node id
  rect          [x, y, w, h] in the screen frame, logical px (Figma units)
  anchor        corner of the window the element keeps its distance to: tl, tr, bl, br
                (stretching elements: "stretch-x" = left and right edge both kept)
  uia           {"name", "role", "match"} to find it through UI Automation (optional)
  colors        [{"role", "hex", "at": [x, y]}]: expected colour at a point of the screen frame
  font          {"family", "size", "weight", "color"}: reported, not measurable through UIA
  rows          VIDEO_INDEX row IDs
  sample        {"text", "mask": true}: sample content (times, titles) masked in pixel diffs
  tolerance     {"pos": px, "size": px, "color": levels} (defaults below)

  python spec.py --uia <screen>       JSON list of the screen's UIA lookups (used by steps.ps1)
  python spec.py --list               print the loaded spec
"""
import glob
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SPEC_DIR = os.path.join(HERE, "spec")                 # where the real spec files will live
FIXTURE = os.path.join(HERE, "spec_fixture.json")     # hand-written stand-in (2-3 Player elements)
DEFAULT_TOL = {"pos": 1.0, "size": 1.0, "color": 6}


class Spec:
    def __init__(self, data, source):
        self.source = source
        self._screens = {s["id"]: s for s in data.get("screens", [])}
        self._elements = {}
        for e in data.get("elements", []):
            e = _normalise(e)
            self._elements[e["id"]] = e

    def screens(self):
        return list(self._screens)

    def screen(self, sid):
        return self._screens[sid]

    def elements(self, sid):
        return [e for e in self._elements.values() if e["screen"] == sid]

    def element(self, eid):
        return self._elements[eid]

    def rows_for(self, eid):
        return list(self._elements[eid].get("rows", []))

    def elements_for_row(self, row):
        return [e for e in self._elements.values() if row in e.get("rows", [])]

    def masks(self, sid):
        out = []
        for e in self.elements(sid):
            smp = e.get("sample") or {}
            if smp.get("mask"):
                out.append({"element": e["id"], "rect": smp.get("rect", e["rect"]), "anchor": e["anchor"],
                            "reason": f"sample content '{smp.get('text', '')}'"})
        return out


def _normalise(e):
    """maps one element of the spec file to the fields the harness uses (the place to adapt when
    the real schema differs from the assumed one)"""
    e = dict(e)
    e.setdefault("anchor", "tl")
    e.setdefault("colors", [])
    e.setdefault("rows", [])
    tol = dict(DEFAULT_TOL)
    tol.update(e.get("tolerance", {}))
    e["tolerance"] = tol
    return e


def load_spec():
    files = sorted(glob.glob(os.path.join(SPEC_DIR, "*.json")))
    if files:
        data = {"screens": [], "elements": []}
        for f in files:
            d = json.load(open(f, encoding="utf-8-sig"))
            data["screens"] += d.get("screens", [])
            data["elements"] += d.get("elements", [])
        return Spec(data, SPEC_DIR)
    return Spec(json.load(open(FIXTURE, encoding="utf-8-sig")), FIXTURE)


def _place(anchor, x, y, w, h, frame_w, frame_h, client_w, client_h):
    dx = client_w - frame_w if anchor.endswith("r") else 0
    dy = client_h - frame_h if anchor.startswith("b") else 0
    if anchor == "stretch-x":
        return x, y, w + client_w - frame_w, h
    if anchor.startswith("stretch-x-b"):
        return x, y + client_h - frame_h, w + client_w - frame_w, h
    return x + dx, y + dy, w, h


def client_rect(spec, el, client_w, client_h):
    """element rect in client logical px for a client of this size (anchor applied)"""
    fw, fh = spec.screen(el["screen"])["size"]
    x, y, w, h = el["rect"]
    return _place(el["anchor"], x, y, w, h, fw, fh, client_w, client_h)


def client_point(spec, el, pt, client_w, client_h):
    fw, fh = spec.screen(el["screen"])["size"]
    x, y, _, _ = _place(el["anchor"], pt[0], pt[1], 0, 0, fw, fh, client_w, client_h)
    return x, y


if __name__ == "__main__":
    s = load_spec()
    if len(sys.argv) >= 3 and sys.argv[1] == "--uia":
        print(json.dumps([{"element": e["id"], **e["uia"]} for e in s.elements(sys.argv[2]) if e.get("uia")]))
    elif len(sys.argv) >= 2 and sys.argv[1] == "--list":
        print("source:", s.source)
        for sid in s.screens():
            print(sid, s.screen(sid))
            for e in s.elements(sid):
                print("  ", e["id"], e["rect"], e["anchor"], e.get("rows"))
    else:
        print(__doc__)
