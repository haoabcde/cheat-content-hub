#!/usr/bin/env python3
"""Check package-owned Markdown links without mistaking generated user files for package files."""
from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LINK = re.compile(r"(?<!!)\[[^\]]*\]\(([^)]+)\)")
EXTERNAL = ("#", "http:", "https:", "mailto:", "data:")
EMAIL = re.compile(r"^[^@\s<>]+@[^@\s<>]+\.[^@\s<>]+$")


def is_archive(source: Path, root: Path) -> bool:
    """True for verbatim copies of upstream docs (raw scrapes, vendored deps).

    Their links point at the ORIGINAL repo's files (docs/, LICENSE, ...), not
    package files — flagging them is a false positive by design."""
    rel = source.relative_to(root)
    return "node_modules" in rel.parts or "raw" in rel.parts


def main() -> int:
    broken: list[str] = []
    for source in ROOT.rglob("*.md"):
        # These files are copied into a user's project root, where their links
        # can legitimately target user artifacts rather than package files.
        if source.is_relative_to(ROOT / "templates"):
            continue
        if is_archive(source, ROOT):
            continue
        for raw in LINK.findall(source.read_text(encoding="utf-8")):
            stripped = raw.strip()
            # Angle-bracket URL form `](<...>)` — spaces are legal inside <>
            if stripped.startswith("<") and ">" in stripped:
                target = stripped[1:stripped.index(">")].split("#", 1)[0]
            else:
                target = stripped.split(maxsplit=1)[0].split("#", 1)[0]
            if not target or target.startswith(EXTERNAL) or EMAIL.match(target):
                continue
            if not (source.parent / target).exists():
                broken.append(f"{source.relative_to(ROOT)} -> {raw}")
    if broken:
        print("Broken package-local Markdown links:", file=sys.stderr)
        print("\n".join(f"  {item}" for item in broken), file=sys.stderr)
        return 1
    print("Markdown package-local link check passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
