#!/usr/bin/env bash
#
# cheat-on-content / content-guard hook
#
# Wires PreToolUse(Write) → enforces three rules before content files can be written:
#
#   Rule 1: Project must be initialized (.cheat-state.json exists)
#   Rule 2: Content files must have required metadata headers (template compliance)
#   Rule 3: AI/tech news content must go through aihot skill first
#
# Allows:
#   - Writing to any directory outside articles/, xhs/, scripts/
#   - Writing new files that don't match content patterns
#   - Writing when all rules pass
#
# Blocks:
#   - Writing content files without project initialization
#   - Writing content files without proper template headers
#   - Writing AI news content without calling aihot first
#
# Bypass (for testing):
#   CHEAT_BYPASS_CONTENT_GUARD=1 — single-shot bypass; logs a warning to stderr
#
# Requirements: bash 3+, jq. Mac default install has both.
#
# Exit codes:
#   0 = allow tool call to proceed
#   1 = block tool call (Claude Code will surface stderr to the model)

set -uo pipefail

# Single-shot bypass — opt-in, logs prominently
if [[ "${CHEAT_BYPASS_CONTENT_GUARD:-0}" == "1" ]]; then
  echo "[cheat-on-content] ⚠️  CONTENT GUARD BYPASS active (CHEAT_BYPASS_CONTENT_GUARD=1)" >&2
  echo "[cheat-on-content] ⚠️  This should only be used for testing." >&2
  echo "[cheat-on-content] ⚠️  Bypass will be visible in git history." >&2
  exit 0
fi

# Read tool call payload from stdin (Claude Code passes JSON)
input=$(cat)
if [[ -z "$input" ]]; then
  # No input — let it through (defensive default; nothing to check)
  exit 0
fi

# Extract tool name and file path
tool_name=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")
content=$(printf '%s' "$input" | jq -r '.tool_input.content // empty' 2>/dev/null || echo "")

# Only intercept Write
if [[ "$tool_name" != "Write" ]]; then
  exit 0
fi

# Only intercept content files
if [[ -z "$file_path" ]]; then
  exit 0
fi

case "$file_path" in
  */articles/*.md|*/xhs/*.md|*/scripts/*.md|articles/*.md|xhs/*.md|scripts/*.md)
    : # match — continue checking
    ;;
  *)
    exit 0
    ;;
esac

# Determine project directory (parent of articles/xhs/scripts)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
# Try to find project root by looking for .cheat-state.json
if [[ ! -f "$PROJECT_DIR/.cheat-state.json" ]]; then
  # Try parent directories
  check_dir="$file_path"
  while [[ "$check_dir" != "/" && "$check_dir" != "." ]]; do
    check_dir=$(dirname "$check_dir")
    if [[ -f "$check_dir/.cheat-state.json" ]]; then
      PROJECT_DIR="$check_dir"
      break
    fi
  done
fi

# === Rule 1: Project must be initialized ===
if [[ ! -f "$PROJECT_DIR/.cheat-state.json" ]]; then
  cat >&2 <<EOF

[cheat-on-content] 🚫 BLOCKED: Project not initialized.

Cannot write content files without a initialized cheat-on-content project.
Missing: .cheat-state.json

What to do:
  • Run /cheat-init to initialize the project first
  • This creates the required project structure and state file

See: skills/cheat-init/SKILL.md
EOF
  exit 1
fi

# === Rule 2: Template compliance for articles/ and xhs/ ===
case "$file_path" in
  */articles/*.md|articles/*.md)
    # Check for required article metadata headers (with or without > prefix)
    has_format=$(echo "$content" | grep -cE '^>?\s*\*\*格式\*\*:' || true)
    has_id=$(echo "$content" | grep -cE '^>?\s*\*\*选题 ID\*\*:' || true)
    has_status=$(echo "$content" | grep -cE '^>?\s*\*\*状态\*\*:' || true)
    has_wordcount=$(echo "$content" | grep -cE '^>?\s*\*\*字数\*\*:' || true)

    if [[ $has_format -eq 0 || $has_id -eq 0 || $has_status -eq 0 || $has_wordcount -eq 0 ]]; then
      cat >&2 <<EOF

[cheat-on-content] 🚫 BLOCKED: Article missing required metadata headers.

Found:
  格式: $([ $has_format -gt 0 ] && echo "✅" || echo "❌ missing")
  选题 ID: $([ $has_id -gt 0 ] && echo "✅" || echo "❌ missing")
  状态: $([ $has_status -gt 0 ] && echo "✅" || echo "❌ missing")
  字数: $([ $has_wordcount -gt 0 ] && echo "✅" || echo "❌ missing")

Required template headers:
  > **格式**: 公众号长文
  > **选题 ID**: YYYY-MM-DD_<id>_<short>
  > **状态**: draft | final
  > **字数**: [WORD_COUNT]

What to do:
  • Use the article template: templates/draft.template.md
  • Ensure all four metadata fields are present before writing

See: templates/draft.template.md
EOF
      exit 1
    fi
    ;;

  */xhs/*.md|xhs/*.md)
    # Check for required xhs metadata headers (with or without > prefix)
    has_format=$(echo "$content" | grep -cE '^>?\s*\*\*格式\*\*:' || true)
    has_id=$(echo "$content" | grep -cE '^>?\s*\*\*选题 ID\*\*:' || true)
    has_status=$(echo "$content" | grep -cE '^>?\s*\*\*状态\*\*:' || true)
    has_title_limit=$(echo "$content" | grep -cE '^>?\s*\*\*标题限制\*\*:' || true)
    has_wordcount=$(echo "$content" | grep -cE '^>?\s*\*\*正文字数\*\*:' || true)
    has_structure=$(echo "$content" | grep -cE '^>?\s*\*\*结构选型\*\*:' || true)

    if [[ $has_format -eq 0 || $has_id -eq 0 || $has_status -eq 0 || $has_title_limit -eq 0 || $has_wordcount -eq 0 || $has_structure -eq 0 ]]; then
      cat >&2 <<EOF

[cheat-on-content] 🚫 BLOCKED: XHS post missing required metadata headers.

Found:
  格式: $([ $has_format -gt 0 ] && echo "✅" || echo "❌ missing")
  选题 ID: $([ $has_id -gt 0 ] && echo "✅" || echo "❌ missing")
  状态: $([ $has_status -gt 0 ] && echo "✅" || echo "❌ missing")
  标题限制: $([ $has_title_limit -gt 0 ] && echo "✅" || echo "❌ missing")
  正文字数: $([ $has_wordcount -gt 0 ] && echo "✅" || echo "❌ missing")
  结构选型: $([ $has_structure -gt 0 ] && echo "✅" || echo "❌ missing")

Required template headers:
  > **格式**: 小红书图文
  > **选题 ID**: [DATE]_[ID]_[SHORT]
  > **状态**: draft | final
  > **标题限制**: 最终标题 ≤20 个中文字符
  > **正文字数**: 600-900 字
  > **结构选型**: 清单体 | 教程体 | 故事体 | 对比体 | 测评体

What to do:
  • Use the xhs template: templates/xhs-post.template.md
  • Ensure all six metadata fields are present before writing

See: templates/xhs-post.template.md
EOF
      exit 1
    fi
    ;;
esac

# === Rule 3: AI/tech news content must go through aihot ===
# Check if content contains AI/tech news keywords
ai_keywords="ChatGPT|OpenAI|Anthropic|Claude|Gemini|DeepSeek|AI|人工智能|大模型|LLM|融资|独角兽|收购|IPO|机器人|自动驾驶|量子计算|芯片|GPU|Transformer"
has_ai_keywords=$(echo "$content" | grep -ciE "$ai_keywords" || true)

if [[ $has_ai_keywords -gt 0 ]]; then
  # Content has AI/tech keywords — check if aihot was called today
  aihot_log="$PROJECT_DIR/.cheat-cache/aihot-called.log"
  today=$(date +%Y-%m-%d)

  aihot_called_today=false
  if [[ -f "$aihot_log" ]]; then
    # Check if today's date appears in the log
    if grep -q "$today" "$aihot_log" 2>/dev/null; then
      aihot_called_today=true
    fi
  fi

  if [[ "$aihot_called_today" == "false" ]]; then
    cat >&2 <<EOF

[cheat-on-content] 🚫 BLOCKED: AI/tech news content detected without aihot data.

Your content contains AI/tech keywords (${has_ai_keywords} matches):
$(echo "$content" | grep -iE "$ai_keywords" | head -5 | sed 's/^/  > /')

But aihot skill was not called today ($today).

This violates the content creation workflow:
  AI/tech news → must come from aihot API (not web search or training data)

Why this matters:
  • Web search results are incomplete and unreliable for AI news
  • aihot provides curated, structured Chinese AI news with categories
  • Using stale training data as "news" is harmful to readers

What to do:
  • Call aihot skill first: ask "今天 AI 圈有什么" or "AI 热点"
  • Use aihot output as your data source
  • Then write content based on that data

See: skills/aihot/SKILL.md
EOF
    exit 1
  fi
fi

# All rules passed — allow the write
exit 0
