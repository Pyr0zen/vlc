"""Reads the harness settings: verify.local.json next to this file (gitignored, real paths of
this PC) on top of verify.example.json (committed, placeholders only)."""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))


def load_config():
    cfg = json.load(open(os.path.join(HERE, "verify.example.json"), encoding="utf-8"))
    local = os.path.join(HERE, "verify.local.json")
    if os.path.exists(local):
        cfg.update(json.load(open(local, encoding="utf-8-sig")))
    for k in ("testMediaDir", "outRoot"):
        if "<" in str(cfg.get(k, "")):
            raise SystemExit(f"set {k} in {local} (see README.md)")
    return cfg
