#!/usr/bin/env python3
"""Audit a cheat-on-content project for broken prediction/retro loops."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


SUPPORT_NAMES = {
    "cover-prompt.md",
    "layout-audit.md",
    "publish-notes.md",
    "captions.md",
    "risk-notes.md",
    "sources.md",
    "report.md",
}

IMAGE_RE = re.compile(r"!\[[^\]]*\]\(([^)]+)\)")


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text()


def load_json(path: Path) -> dict:
    try:
        return json.loads(read_text(path))
    except Exception:
        return {}


def latest_schema(package_root: Path) -> str:
    registry = package_root / "migrations" / "registry.md"
    if not registry.exists():
        return "1.5"
    match = re.search(r'^LATEST_SCHEMA = "([^"]+)"', read_text(registry), re.M)
    return match.group(1) if match else "1.5"


def rel(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def artifact_id_for(path: Path, root: Path, base_name: str) -> str:
    relative = path.relative_to(root)
    parts = relative.parts
    if len(parts) >= 3 and parts[0] == base_name:
        return parts[1]
    stem = path.stem
    for suffix in (".wechat-article", "-wechat-article", "_wechat"):
        stem = stem.replace(suffix, "")
    return stem


def iter_drafts(root: Path, base_name: str) -> list[Path]:
    base = root / base_name
    if not base.exists():
        return []
    drafts_by_id: dict[str, list[Path]] = {}
    for path in sorted(base.rglob("*.md")):
        relative_parts = path.relative_to(base).parts
        if any(part in {"visual", "images", "assets"} for part in relative_parts):
            continue
        if path.name in SUPPORT_NAMES:
            continue
        if path.name.endswith("-prompt.md"):
            continue
        if len(relative_parts) == 1 or path.name.startswith(("draft", "post")):
            artifact_id = artifact_id_for(path, root, base_name)
            drafts_by_id.setdefault(artifact_id, []).append(path)

    preferred: list[Path] = []
    for paths in drafts_by_id.values():
        paths.sort(key=draft_preference)
        preferred.append(paths[0])
    return sorted(preferred)


def draft_preference(path: Path) -> tuple[int, str]:
    order = {
        "draft.wechat-article.md": 0,
        "draft.md": 1,
        "post.md": 0,
    }
    return (order.get(path.name, 5), path.as_posix())


def prediction_matches(
    prediction_paths: list[Path], prediction_text: dict[Path, str], draft: Path, root: Path, artifact_id: str
) -> bool:
    draft_rel = rel(draft, root)
    tokens = {
        artifact_id,
        artifact_id.replace("-", "_"),
        artifact_id.replace("_", "-"),
        draft.stem,
    }
    tokens = {token for token in tokens if len(token) >= 6}
    for pred in prediction_paths:
        pred_name = pred.name
        text = prediction_text[pred]
        if any(token in pred_name or token in text for token in tokens):
            return True
        if draft_rel in text:
            return True
    return False


def retro_body(text: str) -> str | None:
    match = re.search(r"^##\s*复盘\s*$([\s\S]*)", text, re.M)
    return match.group(1).strip() if match else None


def retro_is_empty(body: str | None) -> bool:
    if body is None:
        return True
    compact = re.sub(r"[\s\-—_()（）]+", "", body)
    if not compact:
        return True
    placeholders = ("待填", "T+3", "cheatretro", "跑/cheatretro")
    return any(marker.lower() in compact.lower() for marker in placeholders) and len(compact) < 80


def add(issues: list[tuple[str, str, str]], severity: str, code: str, message: str) -> None:
    issues.append((severity, code, message))


def article_dir_for(draft: Path, root: Path) -> Path | None:
    try:
        relative = draft.relative_to(root)
    except ValueError:
        return None
    if len(relative.parts) >= 3 and relative.parts[0] == "articles":
        return root / "articles" / relative.parts[1]
    return None


def is_local_image(src: str) -> bool:
    return not re.match(r"^(https?:|data:|file:|blob:|cid:)", src)


def expected_image_count(text: str) -> int:
    body = IMAGE_RE.sub("", text)
    body = re.sub(r"\[[^\]]+\]\([^)]+\)", "", body)
    chars = len(re.sub(r"\s+", "", body))
    if chars < 1000:
        return 0
    if chars < 2500:
        return 4
    if chars < 4500:
        return 6
    return max(8, chars // 500)


def normalized_body_length(text: str) -> int:
    body = IMAGE_RE.sub("", text)
    body = re.sub(r"\[[^\]]+\]\([^)]+\)", "", body)
    return len(re.sub(r"\s+", "", body))


def has_layout_rhythm(text: str) -> bool:
    return bool(
        re.search(r"^##\s+", text, re.M)
        or re.search(r"^>\s+", text, re.M)
        or re.search(r"^\s*([-*_])\s*(\1\s*){2,}$", text, re.M)
    )


def has_any(base: Path, names: tuple[str, ...]) -> bool:
    return any((base / name).exists() for name in names)


def audit_editorial_readiness(root: Path, issues: list[tuple[str, str, str]]) -> None:
    articles = root / "articles"
    if not articles.exists():
        return

    for draft in iter_drafts(root, "articles"):
        article_dir = article_dir_for(draft, root)
        if article_dir is None:
            continue
        draft_rel = rel(draft, root)
        text = read_text(draft)
        images = IMAGE_RE.findall(text)
        expected = expected_image_count(text)
        if normalized_body_length(text) >= 2500 and not has_layout_rhythm(text):
            add(
                issues,
                "WARN",
                "article-html-rhythm-missing",
                f"{draft_rel} is long but has no H2, blockquote, or divider rhythm for WeChat HTML.",
            )
        if expected and len(images) < expected:
            add(
                issues,
                "WARN",
                "article-image-density",
                f"{draft_rel} has {len(images)} image(s); expected at least {expected} for WeChat readability.",
            )

        for src in images:
            if not is_local_image(src):
                continue
            image_path = (article_dir / src).resolve()
            if not image_path.exists():
                add(
                    issues,
                    "BLOCKER",
                    "article-image-missing",
                    f"{draft_rel} references missing image {src}.",
                )

        if not (article_dir / "cover-prompt.md").exists():
            add(issues, "WARN", "article-cover-missing", f"{draft_rel} has no cover-prompt.md.")

        visual_dir = article_dir / "visual"
        if not has_any(visual_dir, ("sources.md", "visual-source-report.md")) and not (article_dir / "sources.md").exists():
            add(issues, "WARN", "article-visual-sources-missing", f"{draft_rel} has no visual/sources.md.")
        if not has_any(visual_dir, ("captions.md",)) and not (article_dir / "captions.md").exists():
            add(issues, "WARN", "article-captions-missing", f"{draft_rel} has no visual/captions.md.")

        reference_exists = any((article_dir / candidate).exists() for candidate in (
            "layout-reference.html",
            "reference-wechat.html",
            "visual/raw/reference_wechat_article.html",
        ))
        if reference_exists and not (article_dir / "layout-audit.md").exists():
            add(issues, "WARN", "article-layout-audit-missing", f"{draft_rel} has reference material but no layout-audit.md.")

        preview_html = article_dir / "draft.wechat-article.html"
        copy_html = article_dir / "draft.wechat-article-copy.html"
        if preview_html.exists() and not copy_html.exists():
            add(issues, "WARN", "article-copy-html-missing", f"{rel(preview_html, root)} exists but copy HTML is missing.")
        has_local_images = any(is_local_image(src) for src in images)
        if copy_html.exists() and has_local_images and "data:image/" not in read_text(copy_html):
            add(issues, "WARN", "article-copy-html-no-data-images", f"{rel(copy_html, root)} has no embedded data images.")


def audit(root: Path, package_root: Path, editorial: bool = False) -> list[tuple[str, str, str]]:
    issues: list[tuple[str, str, str]] = []
    state_path = root / ".cheat-state.json"
    settings_root = root
    if not state_path.exists():
        # Repo-level layout: the channel lives under examples/<name>/ (same
        # discovery rule as hooks/session-start.sh). Pick the first match.
        # Hook registration (.claude/settings.json) stays at the repo root —
        # that is CLAUDE_PROJECT_DIR when the user opens the repo.
        for candidate in sorted(root.glob("examples/*/.cheat-state.json")):
            state_path = candidate
            root = candidate.parent
            break
    state = load_json(state_path) if state_path.exists() else {}

    if not state:
        add(issues, "BLOCKER", "state-missing", "No .cheat-state.json found; run /cheat-init first.")
    else:
        target_schema = latest_schema(package_root)
        schema = str(state.get("schema_version", "unknown"))
        if schema != target_schema:
            add(issues, "BLOCKER", "state-schema", f"schema_version is {schema}; expected {target_schema}. Run /cheat-migrate.")
        if not state.get("default_format"):
            add(issues, "BLOCKER", "state-format", "default_format is missing; non-init actions can pick the wrong rubric.")
        if "formats" not in state:
            add(issues, "BLOCKER", "state-formats", "formats object is missing; article/xhs queues are not trackable.")
        if state.get("hooks_installed") is not True:
            add(issues, "WARN", "hooks-disabled", "hooks_installed is false; prediction and content guards are advisory only.")

    settings_candidates = [root / ".claude" / "settings.json"]
    if settings_root != root:
        settings_candidates.append(settings_root / ".claude" / "settings.json")
    settings = next((p for p in settings_candidates if p.exists()), None)
    if settings is not None:
        settings_text = read_text(settings)
        for hook_name in ("prediction-immutability", "content-guard", "session-start"):
            if hook_name not in settings_text:
                add(issues, "WARN", f"hook-{hook_name}", f"{hook_name} is not registered in .claude/settings.json.")
    elif (root / "articles").exists() or (root / "xhs").exists():
        add(issues, "WARN", "hook-settings-missing", ".claude/settings.json is missing; content workflow is not physically enforced.")

    predictions_dir = root / "predictions"
    prediction_paths = sorted(predictions_dir.glob("*.md")) if predictions_dir.exists() else []
    prediction_text = {path: read_text(path) for path in prediction_paths}

    for base_name, fmt in (("articles", "article"), ("xhs", "xhs")):
        for draft in iter_drafts(root, base_name):
            artifact_id = artifact_id_for(draft, root, base_name)
            if not prediction_matches(prediction_paths, prediction_text, draft, root, artifact_id):
                add(
                    issues,
                    "BLOCKER",
                    f"{fmt}-draft-no-prediction",
                    f"{rel(draft, root)} has no matching predictions/*.md. Run cheat-predict --format={fmt} before publishing.",
                )

    for pred, text in prediction_text.items():
        pred_rel = rel(pred, root)
        has_prediction = bool(re.search(r"^##\s*预测", text, re.M) or "Prediction Locked" in text)
        if not has_prediction:
            add(issues, "WARN", "prediction-shape", f"{pred_rel} does not use the standard ## 预测 section.")
        if "Published at" not in text and "Published At" not in text:
            add(issues, "WARN", "prediction-unpublished", f"{pred_rel} has no Published at metadata; it cannot enter T+N retro scheduling.")
        if retro_is_empty(retro_body(text)):
            add(issues, "WARN", "prediction-no-retro", f"{pred_rel} has no completed ## 复盘 section.")

    if editorial:
        audit_editorial_readiness(root, issues)

    return issues


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit cheat-on-content project workflow continuity.")
    parser.add_argument("project_root", nargs="?", default=".", help="Path to a user content project.")
    parser.add_argument(
        "--package-root",
        default=str(Path(__file__).resolve().parents[1]),
        help="Path to the cheat-on-content package root.",
    )
    parser.add_argument("--json", action="store_true", help="Emit machine-readable JSON.")
    parser.add_argument("--editorial", action="store_true", help="Also check WeChat article editorial readiness.")
    args = parser.parse_args()

    root = Path(args.project_root).resolve()
    package_root = Path(args.package_root).resolve()
    issues = audit(root, package_root, editorial=args.editorial)

    if args.json:
        payload = [{"severity": sev, "code": code, "message": msg} for sev, code, msg in issues]
        print(json.dumps({"project_root": str(root), "issues": payload}, ensure_ascii=False, indent=2))
    else:
        print(f"cheat-on-content workflow audit: {root}")
        if not issues:
            print("OK: no broken prediction/retro loop found.")
        else:
            for sev, code, msg in issues:
                print(f"{sev} [{code}] {msg}")
            print()
            print("Next action: clear BLOCKER items before creating more content; otherwise new drafts keep bypassing calibration.")

    return 1 if issues else 0


if __name__ == "__main__":
    sys.exit(main())
