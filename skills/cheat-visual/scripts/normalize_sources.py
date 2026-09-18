#!/usr/bin/env python3
"""Normalize visual source records into a simple markdown table.

This helper is optional. It expects a JSON list of source records and writes a
Markdown table for quick review.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def esc(value: Any) -> str:
    text = "" if value is None else str(value)
    return text.replace("|", "\\|").replace("\n", " ").strip()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", help="Path to JSON source records")
    parser.add_argument("output", help="Path to write Markdown table")
    args = parser.parse_args()

    data = json.loads(Path(args.input).read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise SystemExit("input must be a JSON list")

    headers = ["index", "role", "source", "priority", "url", "claim", "risk"]
    lines = ["| " + " | ".join(headers) + " |", "|" + "---|" * len(headers)]
    for idx, item in enumerate(data, 1):
        if not isinstance(item, dict):
            continue
        row = [
            str(idx),
            esc(item.get("role")),
            esc(item.get("source")),
            esc(item.get("priority")),
            esc(item.get("url")),
            esc(item.get("claim")),
            esc(item.get("risk")),
        ]
        lines.append("| " + " | ".join(row) + " |")

    Path(args.output).write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
