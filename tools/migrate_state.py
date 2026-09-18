#!/usr/bin/env python3
"""Execute the documented cheat-on-content state migration chain safely."""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
import tempfile
import time
from pathlib import Path
from typing import Any


FORM_DEFAULTS = {
    "video": {"content_form": "opinion-video", "artifact_dir": "videos", "shoots": []},
    "article": {"content_form": "wechat-article", "artifact_dir": "articles"},
    "xhs": {"content_form": "xhs-post", "artifact_dir": "xhs"},
}
FORMAT_DEFAULTS = {
    "rubric_version": "v0", "rubric_form_mismatch": False, "baseline_plays": None,
    "calibration_samples": 0, "calibration_samples_at_last_bump": 0,
    "consecutive_directional_errors": [], "pending_retros": [], "last_bump_at": None,
    "last_bump_self_audited": False, "last_published_at": None,
    "last_published_file": None, "last_retro_at": None,
    "last_prediction_self_scored": False, "last_self_scored_at": None,
}
VIDEO_FIELDS = set(FORMAT_DEFAULTS) | {"content_form", "rubric_form_mismatch", "shoots"}


class MigrationError(RuntimeError):
    pass


def version_key(value: str) -> tuple[int, ...]:
    try:
        return tuple(int(part) for part in value.split("."))
    except ValueError as exc:
        raise MigrationError(f"invalid schema version: {value!r}") from exc


def load_json(path: Path) -> dict[str, Any]:
    try:
        state = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise MigrationError(f"state file not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise MigrationError(f"invalid JSON in {path}: {exc}") from exc
    if not isinstance(state, dict):
        raise MigrationError(f"state file must contain a JSON object: {path}")
    return state


def atomic_write(path: Path, state: dict[str, Any]) -> None:
    fd, temp_path = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(state, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_path, path)
    except BaseException:
        try:
            os.unlink(temp_path)
        except FileNotFoundError:
            pass
        raise


def backup(path: Path) -> Path:
    stamp = int(time.time())
    target = path.with_name(f"{path.name}.backup-{stamp}")
    counter = 1
    while target.exists():
        counter += 1
        target = path.with_name(f"{path.name}.backup-{stamp}-{counter}")
    shutil.copy2(path, target)
    return target


def chain_from_registry(path: Path) -> tuple[str, list[tuple[str, str, str]]]:
    text = path.read_text(encoding="utf-8")
    latest = re.search(r'^LATEST_SCHEMA = "([^"]+)"', text, re.M)
    if not latest:
        raise MigrationError(f"LATEST_SCHEMA missing from {path}")
    chain = re.findall(r"^\|\s*([0-9.]+)\s*\|\s*([0-9.]+)\s*\|[^|]*\|\s*\[([^]]+)\]", text, re.M)
    if not chain:
        raise MigrationError(f"migration chain missing from {path}")
    return latest.group(1), chain


def select_chain(chain: list[tuple[str, str, str]], current: str, target: str) -> list[tuple[str, str, str]]:
    if version_key(current) > version_key(target):
        raise MigrationError(f"downgrade is not supported: {current} -> {target}")
    result = []
    while current != target:
        step = next((item for item in chain if item[0] == current), None)
        if step is None:
            known = ", ".join(sorted({version for item in chain for version in item[:2]}, key=version_key))
            raise MigrationError(f"no migration from {current}; known versions: {known}")
        result.append(step)
        current = step[1]
    return result


def format_state(name: str, values: dict[str, Any]) -> dict[str, Any]:
    result = {**FORMAT_DEFAULTS, **FORM_DEFAULTS[name], **values}
    for field in ("consecutive_directional_errors", "pending_retros", "shoots"):
        if field in result:
            result[field] = list(result[field] or [])
    return result


def migrate_10_11(state: dict[str, Any], _: Path, __: argparse.Namespace) -> None:
    defaults = {
        "typical_duration_seconds": 240, "target_publish_cadence_days": None,
        "rubric_form_mismatch": state.get("content_form") not in (None, "opinion-video"),
        "benchmark_status": "none", "benchmark_name": None, "benchmark_sample_count": 0,
        "baseline_plays": None, "enabled_perf_adapters": [], "last_published_file": None,
        "last_retro_at": None, "pending_retros": [], "shoots": [],
    }
    for field, value in defaults.items():
        state.setdefault(field, value)
    for field in ("mode", "prediction_complexity", "bucket_scheme"):
        state.pop(field, None)


def migrate_11_12(state: dict[str, Any], project: Path, _: argparse.Namespace) -> None:
    shoots = state.get("shoots", [])
    if not isinstance(shoots, list):
        raise MigrationError("schema 1.1 shoots must be a list")
    for shoot in shoots:
        if not isinstance(shoot, dict):
            raise MigrationError("schema 1.1 shoots contains a non-object item")
        prediction_file = shoot.get("prediction_file", "")
        shoot.setdefault("scripts_path", str(prediction_file).replace("predictions/", "scripts/", 1))
        shoot.setdefault("script_consistency", "consistent")
        shoot.setdefault("script_diff_pct", None)
        candidate = Path(prediction_file) if isinstance(prediction_file, str) else Path()
        candidate = candidate if candidate.is_absolute() else project / candidate
        has_v2 = candidate.exists() and bool(re.search(r"^## 预测 v2", candidate.read_text(encoding="utf-8"), re.M))
        shoot.setdefault("v2_prediction_written", has_v2)
        shoot.setdefault("script_hash_at_shoot", None)


def migrate_12_13(state: dict[str, Any], _: Path, __: argparse.Namespace) -> None:
    state.setdefault("last_prediction_self_scored", False)
    state.setdefault("last_self_scored_at", None)


def migrate_13_14(state: dict[str, Any], project: Path, args: argparse.Namespace) -> None:
    notes = project / "rubric_notes.md"
    memo = project / "rubric-memo.md"
    if not notes.exists():
        raise MigrationError("schema 1.3 requires rubric_notes.md for blind-channel migration")
    if memo.exists() and not args.allow_existing_memo:
        raise MigrationError("rubric-memo.md already exists; review it, then rerun with --allow-existing-memo")
    if memo.exists():
        # The documented recovery path is deliberately non-destructive: an
        # existing memo means a previous split may already have happened. Do
        # not append duplicate history or rewrite rubric_notes automatically.
        return
    text = notes.read_text(encoding="utf-8")
    memo_sections = re.findall(r"(?ms)^## .*升级 Memo.*?(?=^## |\Z)", text)
    cleaned = re.sub(r"(?ms)^## .*升级 Memo.*?(?=^## |\Z)", "", text).rstrip() + "\n"
    pointer = "**Upgrade memos**: 见 [rubric-memo.md](rubric-memo.md)"
    if pointer not in cleaned:
        lines = cleaned.splitlines()
        at = next((index + 1 for index, line in enumerate(lines) if line.startswith("# ")), 0)
        lines[at:at] = ["", pointer, ""]
        cleaned = "\n".join(lines).rstrip() + "\n"
    if not memo.exists():
        template = Path(args.package_root) / "templates" / "rubric-memo.template.md"
        if not template.exists():
            raise MigrationError(f"missing rubric memo template: {template}")
        memo.write_text(template.read_text(encoding="utf-8").rstrip() + "\n", encoding="utf-8")
    if memo_sections:
        with memo.open("a", encoding="utf-8") as handle:
            handle.write("\n<!-- Migrated from rubric_notes.md during schema 1.3 -> 1.4 -->\n\n")
            handle.write("\n\n".join(section.rstrip() for section in memo_sections) + "\n")
    backup(notes)
    notes.write_text(cleaned, encoding="utf-8")


def migrate_14_15(state: dict[str, Any], _: Path, args: argparse.Namespace) -> None:
    inferred = "video" if state.get("content_form") in (None, "opinion-video") else None
    selected = args.default_format or inferred
    if selected not in FORM_DEFAULTS:
        raise MigrationError("schema 1.4 cannot infer default_format; rerun with --default-format video|article|xhs")
    existing = state.get("formats", {})
    if not isinstance(existing, dict):
        raise MigrationError("schema 1.4 formats must be an object when present")
    video_values = {field: state[field] for field in VIDEO_FIELDS if field in state}
    state["formats"] = {
        "video": format_state("video", {**video_values, **dict(existing.get("video", {}))}),
        "article": format_state("article", dict(existing.get("article", {}))),
        "xhs": format_state("xhs", dict(existing.get("xhs", {}))),
    }
    state["default_format"] = selected
    for field in VIDEO_FIELDS:
        state.pop(field, None)


STEPS = {
    ("1.0", "1.1"): migrate_10_11, ("1.1", "1.2"): migrate_11_12,
    ("1.2", "1.3"): migrate_12_13, ("1.3", "1.4"): migrate_13_14,
    ("1.4", "1.5"): migrate_14_15,
}


def validate(state: dict[str, Any], target: str) -> None:
    if state.get("schema_version") != target:
        raise MigrationError(f"migration stopped at {state.get('schema_version')!r}, expected {target}")
    if target == "1.5":
        if state.get("default_format") not in FORM_DEFAULTS:
            raise MigrationError("schema 1.5 requires a valid default_format")
        formats = state.get("formats")
        if not isinstance(formats, dict) or set(FORM_DEFAULTS) - set(formats):
            raise MigrationError("schema 1.5 requires video/article/xhs format states")
        for name in FORM_DEFAULTS:
            if not isinstance(formats[name].get("pending_retros"), list):
                raise MigrationError(f"formats.{name}.pending_retros must be a list")


def main() -> int:
    parser = argparse.ArgumentParser(description="Apply the cheat-on-content state migration chain safely.")
    parser.add_argument("project_root", nargs="?", default=".")
    parser.add_argument("--package-root", default=str(Path(__file__).resolve().parents[1]))
    parser.add_argument("--to", help="target schema (defaults to LATEST_SCHEMA)")
    parser.add_argument("--from", dest="from_version", help="only for a known missing/wrong schema_version")
    parser.add_argument("--default-format", choices=sorted(FORM_DEFAULTS))
    parser.add_argument("--allow-existing-memo", action="store_true")
    parser.add_argument("--apply", action="store_true", help="write changes; default is dry run")
    args = parser.parse_args()
    args.package_root = str(Path(args.package_root).resolve())
    project = Path(args.project_root).resolve()
    state_path = project / ".cheat-state.json"
    try:
        state = load_json(state_path)
        latest, chain = chain_from_registry(Path(args.package_root) / "migrations" / "registry.md")
        current = args.from_version or state.get("schema_version")
        if not isinstance(current, str):
            raise MigrationError("state.schema_version is missing; pass --from only after confirming its original version")
        target = args.to or latest
        plan = select_chain(chain, current, target)
        if not plan:
            validate(state, target)
            print(f"OK: state already uses schema {target}; no migration needed.")
            return 0
        print(f"Migration plan: {current} -> {target}")
        for number, (source, destination, name) in enumerate(plan, 1):
            print(f"  [{number}/{len(plan)}] {source} -> {destination}: {name}")
        if not args.apply:
            print("Dry run only. Re-run with --apply after reviewing this plan.")
            return 0
        print(f"Backup: {backup(state_path)}")
        for source, destination, _ in plan:
            if state.get("schema_version") != source:
                raise MigrationError(f"expected schema {source}, found {state.get('schema_version')!r}")
            handler = STEPS.get((source, destination))
            if handler is None:
                raise MigrationError(f"no executable implementation for {source} -> {destination}")
            handler(state, project, args)
            state["schema_version"] = destination
            atomic_write(state_path, state)
            print(f"Applied: {source} -> {destination}")
        validate(load_json(state_path), target)
        print(f"OK: migrated to schema {target}.")
        return 0
    except MigrationError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
