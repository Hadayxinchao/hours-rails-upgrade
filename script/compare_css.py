#!/usr/bin/env python3
"""Semantic diff of two compiled stylesheets.

Used in the upgrade to prove the Dart Sass build matches the 2020 libsass
build: rules are flattened to (selector list, declaration) pairs, selector
order inside a list is ignored, and equivalent spellings are normalised
(#aaa == #aaaaaa == rgb(170,170,170) == hsl(...), 0.5 == .5, quotes, spacing).

    python3 script/compare_css.py old.css new.css
"""
import colorsys
import re
import sys

NAMED = {
    "black": (0, 0, 0, 1), "white": (255, 255, 255, 1), "transparent": (0, 0, 0, 0),
    "red": (255, 0, 0, 1), "gray": (128, 128, 128, 1), "grey": (128, 128, 128, 1),
    "whitesmoke": (245, 245, 245, 1),
}
COLOR = re.compile(
    r"#[0-9a-fA-F]{3,8}\b|rgba?\([^)]*\)|hsla?\([^)]*\)|(?<![\w-])(?:%s)(?![\w-])" % "|".join(NAMED)
)


def _channel(value):
    value = value.strip()
    return float(value[:-1]) * 2.55 if value.endswith("%") else float(value)


def _color(match):
    text = match.group(0).lower()
    alpha = 1.0
    if text.startswith("#"):
        hexa = text[1:]
        if len(hexa) in (3, 4):
            hexa = "".join(c * 2 for c in hexa)
        r, g, b = (int(hexa[i:i + 2], 16) for i in (0, 2, 4))
        if len(hexa) == 8:
            alpha = int(hexa[6:8], 16) / 255
    elif text.startswith("rgb"):
        parts = text[text.index("(") + 1:-1].split(",")
        r, g, b = (round(_channel(p)) for p in parts[:3])
        if len(parts) > 3:
            alpha = float(parts[3])
    elif text.startswith("hsl"):
        parts = [p.strip().rstrip("%") for p in text[text.index("(") + 1:-1].split(",")]
        rr, gg, bb = colorsys.hls_to_rgb(float(parts[0]) / 360, float(parts[2]) / 100, float(parts[1]) / 100)
        r, g, b = round(rr * 255), round(gg * 255), round(bb * 255)
        if len(parts) > 3:
            alpha = float(parts[3])
    else:
        r, g, b, alpha = NAMED[text]
    return f"rgba({r},{g},{b},{round(alpha, 2):g})"


def _declaration(decl):
    decl = re.sub(r"\s*:\s*", ":", decl, count=1).lower()
    decl = COLOR.sub(_color, decl)
    decl = re.sub(r"(?<![\w.])0\.(\d)", r".\1", decl)
    decl = re.sub(r"(?<![\w.])\.0(?!\d)", "0", decl)
    decl = re.sub(r"(\d+\.\d{3})\d+", r"\1", decl)
    decl = re.sub(r"\s*/\s*", "/", decl)
    decl = re.sub(r",\s+", ",", decl)
    return decl.replace('"', "").replace("'", "")


def rules(path):
    css = open(path, encoding="utf-8").read().lstrip("﻿")
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    css = re.sub(r"@charset[^;]*;|@import[^;]*;", "", css)
    css = re.sub(r"\s+", " ", css)
    out = set()
    for block in css.split("}"):
        if "{" not in block:
            continue
        selector, body = block.rsplit("{", 1)
        selector = selector.split("{")[-1].strip().replace('"', "").replace("'", "")
        selector = re.sub(r"\s*([>+~,])\s*", r"\1", selector)
        selector = ",".join(sorted(selector.split(",")))
        for decl in body.split(";"):
            if decl.strip():
                out.add((selector, _declaration(decl.strip())))
    return out


def main(old_path, new_path):
    old, new = rules(old_path), rules(new_path)
    print(f"identical declarations: {len(old & new)}")
    print(f"only in {old_path}: {len(old - new)}")
    for item in sorted(old - new):
        print("  -", item)
    print(f"only in {new_path}: {len(new - old)}")
    for item in sorted(new - old):
        print("  +", item)


if __name__ == "__main__":
    main(*sys.argv[1:3])
