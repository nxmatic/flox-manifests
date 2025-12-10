#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import re
import sys

PATTERN = re.compile(r'^(?P<indent>\s*)(?P<key>[A-Za-z0-9_.\-]+)\s*=\s*"(?P<value>(?:[^"\\]|\\.)*)"', re.MULTILINE)

def decode_escaped(value: str) -> str:
    return bytes(value, "utf-8").decode("unicode_escape")

def maybe_multiline(match: re.Match[str]) -> str:
    value = match.group("value")
    if "\\n" not in value:
        return match.group(0)
    decoded = decode_escaped(value).rstrip("\n")
    indent = match.group("indent")
    key = match.group("key")
    body = decoded
    return f"{indent}{key} = \"\"\"\n{body}\n{indent}\"\"\""

def fix_file(path: pathlib.Path) -> None:
    original = path.read_text()
    updated = PATTERN.sub(maybe_multiline, original)
    if not updated.endswith("\n"):
        updated += "\n"
    if updated != original:
        path.write_text(updated)

def main() -> int:
    if len(sys.argv) != 2:
        print("usage: fix-toml-multiline.py <path>", file=sys.stderr)
        return 1
    fix_file(pathlib.Path(sys.argv[1]))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
