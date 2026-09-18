#!/usr/bin/env bash
# Regression checks for hooks/content-guard.sh — the only enforcement hook
# without coverage. Fixture-based: builds a minimal project in a temp dir and
# feeds Claude Code payloads to the hook's stdin.
set -euo pipefail
ROOT="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )"
GUARD="$ROOT/hooks/content-guard.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/cheat-content-guard.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

PROJECT="$TMP/project"
mkdir -p "$PROJECT/articles/2026-09-18_demo/drafts" "$PROJECT/.cheat-cache" "$PROJECT/notes"
cat > "$PROJECT/.cheat-state.json" <<'EOF'
{"schema_version":"1.5","default_format":"article","hooks_installed":true,"formats":{"video":{},"article":{},"xhs":{}}}
EOF

PASS=0
FAIL=0

ok() {
  PASS=$((PASS + 1))
  echo "  ✓ $1"
}

bad() {
  FAIL=$((FAIL + 1))
  echo "  ✗ $1" >&2
}

# expect_block <label> <payload> [env...]
expect_block() {
  local label="$1" payload="$2"
  shift 2
  if env "$@" CLAUDE_PROJECT_DIR="$PROJECT" bash "$GUARD" <<<"$payload" >/dev/null 2>&1; then
    bad "$label — expected block, hook allowed it"
  else
    ok "$label"
  fi
}

# expect_allow <label> <payload> [env...]
expect_allow() {
  local label="$1" payload="$2"
  shift 2
  if env "$@" CLAUDE_PROJECT_DIR="$PROJECT" bash "$GUARD" <<<"$payload" >/dev/null 2>&1; then
    ok "$label"
  else
    bad "$label — expected allow, hook blocked it"
  fi
}

write_payload() {
  jq -nc --arg path "$1" --arg content "$2" \
    '{tool_name:"Write",tool_input:{file_path:$path,content:$content}}'
}

VALID_ARTICLE='> **格式**: 公众号长文
> **选题 ID**: 2026-09-18_demo
> **状态**: draft
> **字数**: 5000
正文。'

AI_ARTICLE='> **格式**: 公众号长文
> **选题 ID**: 2026-09-18_demo
> **状态**: draft
> **字数**: 5000
DeepSeek 今天发布了新模型，大模型格局再变。'

echo "content-guard regression checks"

# 1. Non-content path passes through untouched
expect_allow "非内容文件（notes/）放行" \
  "$(write_payload "$PROJECT/notes/foo.md" 'anything')"

# 2. Article without required metadata headers is blocked (Rule 2)
expect_block "缺 metadata 的 article 拦截" \
  "$(write_payload "$PROJECT/articles/2026-09-18_demo/drafts/draft.md" 'missing headers')"

# 3. AI-keyword article without today's aihot call is blocked (Rule 3)
expect_block "AI 内容未跑 aihot 拦截" \
  "$(write_payload "$PROJECT/articles/2026-09-18_demo/drafts/draft.md" "$AI_ARTICLE")"

# 4. Same article allowed once aihot was called today
date +%Y-%m-%d > "$PROJECT/.cheat-cache/aihot-called.log"
expect_allow "aihot 当日已调用后放行" \
  "$(write_payload "$PROJECT/articles/2026-09-18_demo/drafts/draft.md" "$AI_ARTICLE")"
rm -f "$PROJECT/.cheat-cache/aihot-called.log"

# 5. Single-shot bypass env lets a bad article through (with stderr warning)
expect_allow "CHEAT_BYPASS_CONTENT_GUARD=1 放行" \
  "$(write_payload "$PROJECT/articles/2026-09-18_demo/drafts/draft.md" 'missing headers')" \
  CHEAT_BYPASS_CONTENT_GUARD=1

# 6. Valid non-AI article passes Rule 2 without needing aihot
expect_allow "合规非 AI article 放行" \
  "$(write_payload "$PROJECT/articles/2026-09-18_demo/drafts/draft.md" "$VALID_ARTICLE")"

echo
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]]
