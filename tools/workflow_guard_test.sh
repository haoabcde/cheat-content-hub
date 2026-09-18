#!/usr/bin/env bash
# Executable regression checks for immutable predictions and a complete lifecycle.
set -euo pipefail
ROOT="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/cheat-guards.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
PROJECT="$TMP/project"
mkdir -p "$PROJECT/predictions" "$PROJECT/articles/2026-07-12_demo" "$PROJECT/.claude"
cat > "$PROJECT/.cheat-state.json" <<'EOF'
{"schema_version":"1.5","default_format":"article","hooks_installed":true,"formats":{"video":{"pending_retros":[],"shoots":[]},"article":{"pending_retros":[]},"xhs":{"pending_retros":[]}}}
EOF
printf '%s\n' '{"hooks":{"PreToolUse":["prediction-immutability","content-guard"],"SessionStart":["session-start"]}}' > "$PROJECT/.claude/settings.json"
cat > "$PROJECT/predictions/2026-07-12_demo.md" <<'EOF'
**Published at**: 2026-07-01T00:00:00+08:00
**Format**: article
## 预测
locked range
## 复盘
真实数据已经写入，包含复盘结论。
EOF
cat > "$PROJECT/articles/2026-07-12_demo/draft.md" <<'EOF'
> **格式**: 公众号长文
> **选题 ID**: 2026-07-12_demo
> **状态**: final
> **字数**: 800
正文。
EOF
blocked=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s","old_string":"locked range","new_string":"changed"}}' "$PROJECT/predictions/2026-07-12_demo.md")
if printf '%s' "$blocked" | bash "$ROOT/hooks/prediction-immutability.sh" >/dev/null 2>&1; then
  echo "prediction immutability allowed a protected edit" >&2; exit 1
fi
allowed=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s","old_string":"真实数据已经写入，包含复盘结论。","new_string":"updated retrospective"}}' "$PROJECT/predictions/2026-07-12_demo.md")
printf '%s' "$allowed" | bash "$ROOT/hooks/prediction-immutability.sh" >/dev/null
missing=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"missing headers"}}' "$PROJECT/articles/2026-07-12_demo/draft.md")
if printf '%s' "$missing" | CLAUDE_PROJECT_DIR="$PROJECT" bash "$ROOT/hooks/content-guard.sh" >/dev/null 2>&1; then
  echo "content guard allowed an article without required metadata" >&2; exit 1
fi
python3 "$ROOT/tools/workflow_audit.py" "$PROJECT" >/dev/null
echo "workflow guard regression checks passed"
