"""The machine-readable Figma spec (spec/, made by make_spec.py): the one place the harness reads it.

Interface used by compare.py:
  db = load_spec()
  db.row_id(number)                  VIDEO_INDEX row number -> row id ("P2-03")
  db.frame_by_png(png)               index entry of a frame / component set
  st = db.state(png, props=None, node=None)
      the elements of one screen state, normalised (below):
      - a frame:                   state("Player-6.png")
      - a component set variant:   state("Controls.png", {"Property 1": "queue"})
      - a part of a variant or frame that the spec files leave out (the popups and sidebars of
        the Controls variants sit outside the variant's bounds): state(..., node="491:2243").
        Its elements are built here with make_spec's own Builder and row matcher, so they have
        the same shape and row suggestions; they are marked derived.
  st.elements, st.rows (frame rows as ids), st.node (Figma node the bounds are relative to),
  st.size, st.source

Normalised element (from the spec's element format, spec/README.md):
  id, name, path, type, bounds [x, y, w, h] relative to st.node, icon, component, variant,
  fill: {"hex", "alpha", "token"} of the first solid fill (dark value), or None
  text: {"content", "font", "weight", "size", "hex"} or None
  mask (reason or None), translucent, brand, clipped
  rows: row ids; rows_source: "element" (the spec's suggestion) or "frame" (fallback)
  row_count: how many rows the element suggests (many = a generic container: weak)
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SPEC_DIR = os.path.join(HERE, "spec")


class State:
    def __init__(self, node, size, elements, rows, source, png):
        self.node, self.size, self.elements, self.rows, self.source, self.png = node, size, elements, rows, source, png


class SpecDB:
    def __init__(self):
        self.index = json.load(open(os.path.join(SPEC_DIR, "index.json"), encoding="utf-8"))
        self._rows = {int(k): v["id"] for k, v in self.index["rows"].items()}
        self._by_png = {f["png"]: f for f in self.index["frames"]}
        self._files = {}
        self._derived = {}
        self._ms = None

    def row_id(self, n):
        n = int(n)
        if n in self._rows:
            return self._rows[n]
        if self._ms is None:
            self._load_builder()
        r = self._ms_rows.get(n)
        return r["id"] if r else str(n)

    def frame_by_png(self, png):
        return self._by_png[png]

    def _file(self, png):
        f = self._by_png[png]["file"]
        if f not in self._files:
            self._files[f] = json.load(open(os.path.join(SPEC_DIR, f), encoding="utf-8"))
        return self._files[f]

    def state(self, png, props=None, node=None):
        spec = self._file(png)
        frame_rows = [self.row_id(r) for r in spec.get("rows", [])]
        if spec["kind"] == "component_set":
            var = [v for v in spec["variants"] if all(v["props"].get(k) == val for k, val in (props or {}).items())]
            if not var:
                raise KeyError(f"{png}: no variant {props}")
            v = var[0]
            base_node, size, els = v["node"], v["bounds"][2:], v["elements"]
            src = f"{png} variant {v['props']}"
        else:
            base_node, size, els = spec["node"], spec["size"], spec["elements"]
            src = png
        if node and node != base_node:
            els, size = self._derive(node, spec, png)
            return State(node, size, [self._norm(e, frame_rows) for e in els], frame_rows,
                         f"{src} / node {node} (derived with make_spec.Builder)", png)
        return State(base_node, size, [self._norm(e, frame_rows) for e in els], frame_rows, src, png)

    # --- elements the spec files leave out, built the same way --------------------------------
    def _load_builder(self):
        sys.path.insert(0, HERE)
        import make_spec as ms  # the spec generator: same element format and row matcher
        import math
        self._ms = ms
        with open(ms.FIGMA, encoding="utf-8") as f:
            self._figma = json.load(f)
        self._nodes = {}
        stack = [self._figma["document"]]
        while stack:
            n = stack.pop()
            self._nodes[n["id"]] = n
            stack.extend(n.get("children", []))
        png_map = ms.load_png_map()
        rows, cites, _ = ms.load_rows({v[2] for v in png_map.values()})
        self._ms_rows, self._cites = rows, cites
        df = {}
        for r in rows.values():
            for w in r["_words"]:
                df[w] = df.get(w, 0) + 1
        self._idf = {w: math.log(len(rows) / c) for w, c in df.items()}
        self._builder = ms.Builder(self._figma, ms.load_tokens())
        self._set_rows = {nid: cites.get(png, set()) for nid, (_, kind, png) in png_map.items() if kind == "component_set"}

    def _derive(self, node_id, spec, png):
        if node_id in self._derived:
            return self._derived[node_id]
        if self._ms is None:
            self._load_builder()
        node = self._nodes[node_id]
        bb = node["absoluteBoundingBox"]
        theme = spec.get("theme", "dark")
        set_names = [spec["name"]] if spec["kind"] == "component_set" else []
        set_ids = [spec["node"]] if spec["kind"] == "component_set" else []
        ctx = {"sets": set_names, "set_ids": set_ids, "seek": False, "frame_w": bb["width"], "frame_h": bb["height"]}
        els = []
        self._builder.walk(node, (bb["x"], bb["y"]), theme, [], els, ctx)
        self._ms.assign_rows(els, sorted(self._cites.get(png, set())), self._set_rows, self._ms_rows, self._idf)
        self._derived[node_id] = (els, [bb["width"], bb["height"]])
        return self._derived[node_id]

    # --- normalisation: the spec format -> what the checks use ---------------------------------
    def _norm(self, e, frame_rows):
        fill = None
        for p in e.get("fills", []) or []:
            if "dark" in p or "color" in p:
                fill = {"hex": p.get("dark", p.get("color")), "alpha": p.get("alpha", p.get("dark_alpha", 1)), "token": p.get("token")}
                break
        text = None
        t = e.get("text")
        if t:
            col = t.get("color")
            if isinstance(col, list):
                col = col[0] if col else None
            hexv = (col or {}).get("dark", (col or {}).get("color")) if isinstance(col, dict) else None
            text = {"content": t.get("content"), "font": t.get("font"), "weight": t.get("weight"), "size": t.get("size"), "hex": hexv}
        rows = [self.row_id(r) for r in e.get("rows", [])]
        return {"id": e["id"], "name": e.get("name"), "path": e.get("path"), "type": e.get("type"),
                "bounds": e["bounds"], "icon": e.get("icon"), "component": e.get("component"), "variant": e.get("variant"),
                "fill": fill, "text": text, "radius": e.get("radius"), "mask": e.get("mask"),
                "translucent": bool(e.get("translucent")) or bool(fill and fill.get("alpha", 1) < 1),
                "brand": bool(e.get("brand")), "clipped": bool(e.get("clipped")),
                "rows": rows or list(frame_rows), "rows_source": "element" if rows else "frame", "row_count": len(rows)}


_DB = None


def load_spec():
    global _DB
    if _DB is None:
        _DB = SpecDB()
    return _DB


if __name__ == "__main__":
    db = load_spec()
    if len(sys.argv) >= 2:
        png = sys.argv[1]
        props = json.loads(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2] != "-" else None
        node = sys.argv[3] if len(sys.argv) > 3 else None
        st = db.state(png, props, node)
        print(st.source, st.node, st.size, "frame rows", st.rows)
        for e in st.elements:
            print(f"  {e['id']:<28} {e['type']:<9} {str(e['bounds']):<28} {e['path'][:50]:<50} "
                  f"{'mask:' + e['mask'] if e['mask'] else ''}{' brand' if e['brand'] else ''}{' transl' if e['translucent'] else ''} "
                  f"rows {e['rows']} ({e['rows_source']})")
    else:
        print(__doc__)
