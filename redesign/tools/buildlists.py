#!/usr/bin/env python3
# Checks the Qt module's build lists before a push (run from the repo root):
#   python redesign/tools/buildlists.py
# 1. modules/gui/qt/Makefile.am: inside a continued list every line but the last ends with "\"
#    (a lost backslash after a merge breaks the autotools build CI uses).
# 2. The .qml / .js / .cpp / .hpp files under modules/gui/qt named in Makefile.am and in
#    meson.build are the same set, and every listed file exists.
# Prints the problems and exits 1 if there are any.
import os
import re
import sys

QT = "modules/gui/qt"
MAKEFILE = os.path.join(QT, "Makefile.am")
MESON = os.path.join(QT, "meson.build")
EXT = (".qml", ".js", ".cpp", ".hpp", ".frag", ".vert")

problems = []

def file_refs(text):
    return set(re.findall(r"[\w./+-]+(?:%s)\b" % "|".join(re.escape(e) for e in EXT), text))

with open(MAKEFILE, encoding="utf-8") as f:
    lines = f.read().split("\n")

# 1. continuation lines
in_list = False
for i, line in enumerate(lines):
    stripped = line.rstrip()
    is_entry = line.startswith("\t") and stripped and not stripped.lstrip().startswith("#")
    if in_list and is_entry:
        nxt = lines[i + 1] if i + 1 < len(lines) else ""
        nxt_is_entry = nxt.startswith("\t") and nxt.strip() and not nxt.strip().startswith("#") \
            and not re.match(r"\t(if|else|endif)\b", nxt)
        if not stripped.endswith("\\") and nxt_is_entry and re.search(r"\.(%s)$" % "|".join(e[1:] for e in EXT), nxt.strip()):
            problems.append("%s:%d: list line without a trailing backslash: %s" % (MAKEFILE, i + 1, stripped.strip()))
    if stripped.endswith("\\"):
        in_list = True
    elif not is_entry:
        in_list = False

# 2. same files in both build systems
with open(MESON, encoding="utf-8") as f:
    meson = f.read()
def code(text):
    # comments name example files (foo/qml/Bar.qml)
    return "\n".join(l for l in text.split("\n") if not l.lstrip().startswith("#"))

make_refs = {r for r in file_refs(code("\n".join(lines))) if not r.startswith("$")}
meson_refs = file_refs(code(meson))

def norm(r):
    return r[len("qt/"):] if r.startswith("qt/") else r

make_set = {norm(r) for r in make_refs if not r.endswith(".moc.cpp")}
meson_set = {norm(r) for r in meson_refs}
for r in sorted(make_set - meson_set):
    if r.endswith(".qml") or r.endswith(".js"):
        problems.append("only in Makefile.am: " + r)
for r in sorted(meson_set - make_set):
    if r.endswith(".qml") or r.endswith(".js"):
        problems.append("only in meson.build: " + r)
for r in sorted(meson_set | make_set):
    if r.endswith(".qml") and not os.path.exists(os.path.join(QT, r)):
        problems.append("listed but missing: " + r)

for p in problems:
    print(p)
print("buildlists: %d problem(s)" % len(problems))
sys.exit(1 if problems else 0)
