#!/usr/bin/env python3
"""Regression tests for the executable state migration chain."""
from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools" / "migrate_state.py"


class MigrationStateTests(unittest.TestCase):
    def run_tool(self, project: Path, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["python3", str(TOOL), str(project), "--package-root", str(ROOT), *args],
            text=True, capture_output=True, check=False,
        )

    def test_full_chain_dry_run_apply_and_idempotency(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            project = Path(raw)
            original = {
                "schema_version": "1.0", "content_form": "opinion-video",
                "mode": "cold-start", "prediction_complexity": "simple",
                "bucket_scheme": "ratio", "shoots": [],
            }
            (project / ".cheat-state.json").write_text(json.dumps(original), encoding="utf-8")
            (project / "rubric_notes.md").write_text(
                "# Rubric\n\n## v0 → v1 升级 Memo\n\n播放：30w\n\n## 维度\n\n通用规则\n", encoding="utf-8"
            )
            dry_run = self.run_tool(project)
            self.assertEqual(dry_run.returncode, 0, dry_run.stderr)
            self.assertEqual(json.loads((project / ".cheat-state.json").read_text()), original)

            applied = self.run_tool(project, "--apply")
            self.assertEqual(applied.returncode, 0, applied.stderr)
            state = json.loads((project / ".cheat-state.json").read_text())
            self.assertEqual(state["schema_version"], "1.5")
            self.assertEqual(state["default_format"], "video")
            self.assertEqual(set(state["formats"]), {"video", "article", "xhs"})
            self.assertNotIn("mode", state)
            self.assertNotIn("shoots", state)
            self.assertIn("播放：30w", (project / "rubric-memo.md").read_text(encoding="utf-8"))
            self.assertNotIn("升级 Memo", (project / "rubric_notes.md").read_text(encoding="utf-8"))
            self.assertTrue(list(project.glob(".cheat-state.json.backup-*")))
            self.assertTrue(list(project.glob("rubric_notes.md.backup-*")))

            repeated = self.run_tool(project, "--apply")
            self.assertEqual(repeated.returncode, 0, repeated.stderr)
            self.assertIn("no migration needed", repeated.stdout)

    def test_ambiguous_legacy_form_requires_explicit_choice(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            project = Path(raw)
            (project / ".cheat-state.json").write_text(
                json.dumps({"schema_version": "1.4", "content_form": "long-essay"}), encoding="utf-8"
            )
            blocked = self.run_tool(project, "--apply")
            self.assertNotEqual(blocked.returncode, 0)
            self.assertIn("--default-format", blocked.stderr)
            applied = self.run_tool(project, "--apply", "--default-format", "article")
            self.assertEqual(applied.returncode, 0, applied.stderr)
            state = json.loads((project / ".cheat-state.json").read_text())
            self.assertEqual(state["default_format"], "article")

    def test_existing_memo_requires_opt_in_without_duplicate_append(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            project = Path(raw)
            (project / ".cheat-state.json").write_text(json.dumps({"schema_version": "1.3"}), encoding="utf-8")
            (project / "rubric_notes.md").write_text("# Rubric\n", encoding="utf-8")
            (project / "rubric-memo.md").write_text("# Existing memo\n", encoding="utf-8")
            blocked = self.run_tool(project, "--to", "1.4", "--apply")
            self.assertNotEqual(blocked.returncode, 0)
            applied = self.run_tool(project, "--to", "1.4", "--apply", "--allow-existing-memo")
            self.assertEqual(applied.returncode, 0, applied.stderr)
            self.assertEqual((project / "rubric-memo.md").read_text(encoding="utf-8"), "# Existing memo\n")


if __name__ == "__main__":
    unittest.main()
