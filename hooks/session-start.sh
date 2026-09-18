#!/usr/bin/env bash
#
# cheat-on-content SessionStart hook
#
# Renders a 4-6 line status report at the start of every Claude Code session.
# Output is added to Claude's system context — Claude sees it before first reply.
#
# Silently exits if:
#   - Not in a cheat-on-content project (no .cheat-state.json)
#   - jq not available (status is markdown-readable; Claude can read state.json directly)
#
# Format:
#   📦 Buffer: N (color)
#   ⏰ 待复盘: N
#   🎯 候选 top 3: ...
#   📅 上次抓热点: N 天前
#   ⚠️ 待办: ...

set -uo pipefail

# Portable ISO-8601 timestamp → epoch converter (works on both GNU/Linux and BSD/macOS)
parse_iso_epoch() {
  local input="${1%%+*}"  # strip timezone suffix like +08:00
  input="${input%%Z}"     # strip Z suffix
  date -d "$input" "+%s" 2>/dev/null \
    || date -j -f "%Y-%m-%dT%H:%M:%S" "$input" "+%s" 2>/dev/null \
    || echo 0
}

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
STATE_FILE="$PROJECT_DIR/.cheat-state.json"
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Channel discovery: repo-level projects keep the channel under examples/<name>/
CHANNEL_REL="."
if [[ ! -f "$STATE_FILE" ]]; then
  found_state=$(find "$PROJECT_DIR/examples" -maxdepth 2 -name ".cheat-state.json" 2>/dev/null | head -1)
  if [[ -n "$found_state" ]]; then
    CHANNEL_DIR="$(dirname "$found_state")"
    CHANNEL_REL="${CHANNEL_DIR#$PROJECT_DIR/}"
    PROJECT_DIR="$CHANNEL_DIR"
    STATE_FILE="$found_state"
  fi
fi

# Silently skip if not a cheat-on-content project
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# Skip if jq missing (Claude can still read state.json himself in conversation)
if ! command -v jq >/dev/null 2>&1; then
  cat <<'EOF'
[cheat-on-content] SessionStart: jq not installed — skipping auto status report.
Claude can still read .cheat-state.json directly. Say "状态" for full status.
EOF
  exit 0
fi

now_epoch=$(date +%s)
today_iso=$(date +%Y-%m-%d)

# --- Read state ---
state=$(cat "$STATE_FILE")
schema_version=$(echo "$state" | jq -r '.schema_version // "unknown"')
default_format=$(echo "$state" | jq -r '.default_format // "video"')
content_guard_relevant=false
if [[ "$default_format" == "article" || "$default_format" == "xhs" ]]; then
  content_guard_relevant=true
elif echo "$state" | jq -e '(.enabled_trend_sources // []) | index("aihot") != null' >/dev/null 2>&1; then
  content_guard_relevant=true
elif echo "$state" | jq -e '(.enabled_perf_adapters // []) | index("xhs-explore") != null' >/dev/null 2>&1; then
  content_guard_relevant=true
fi

# Compatibility: if formats object doesn't exist (old schema), fall back to flat fields
has_formats=$(echo "$state" | jq -r '.formats // null')
if [[ "$has_formats" == "null" ]]; then
  # Old schema - read flat fields and map to video
  rubric_version=$(echo "$state" | jq -r '.rubric_version // "v0"')
  calibration_samples=$(echo "$state" | jq -r '.calibration_samples // 0')
  pending_retros_count=$(echo "$state" | jq -r '.pending_retros // [] | length')
  buffer_count=$(echo "$state" | jq -r '.shoots // [] | length')
else
  # New multi-format schema - read from default format
  rubric_version=$(echo "$state" | jq -r --arg fmt "$default_format" '.formats[$fmt].rubric_version // "v0"')
  calibration_samples=$(echo "$state" | jq -r --arg fmt "$default_format" '.formats[$fmt].calibration_samples // 0')
  pending_retros_count=$(echo "$state" | jq -r --arg fmt "$default_format" '.formats[$fmt].pending_retros // [] | length')
  buffer_count=$(echo "$state" | jq -r '.formats.video.shoots // [] | length')
fi

target_cadence=$(echo "$state" | jq -r '.target_publish_cadence_days // null')
last_trends_at=$(echo "$state" | jq -r '.last_trends_run_at // ""')
last_published_at=$(echo "$state" | jq -r --arg fmt "$default_format" '.formats[$fmt].last_published_at // .last_published_at // ""')
hooks_installed=$(echo "$state" | jq -r '.hooks_installed // false')
form_severe_mismatch=$(echo "$state" | jq -r --arg fmt "$default_format" '.formats[$fmt].rubric_form_mismatch // .rubric_form_severe_mismatch // false')
last_prediction_self_scored=$(echo "$state" | jq -r --arg fmt "$default_format" '.formats[$fmt].last_prediction_self_scored // .last_prediction_self_scored // false')
last_self_scored_at=$(echo "$state" | jq -r --arg fmt "$default_format" '.formats[$fmt].last_self_scored_at // .last_self_scored_at // ""')

# --- Detect schema mismatch (read LATEST_SCHEMA from migrations/registry.md if reachable) ---
# If copied into a user project, registry usually is not present; use fallback.
REGISTRY_PATH="${CHEAT_ON_CONTENT_ROOT:-$SCRIPT_DIR/..}/migrations/registry.md"
LATEST_SCHEMA=$(grep -E '^LATEST_SCHEMA = "' "$REGISTRY_PATH" 2>/dev/null | sed -E 's/.*"([^"]+)".*/\1/' | head -1)
LATEST_SCHEMA="${LATEST_SCHEMA:-1.5}"
if [[ -n "${CHEAT_LATEST_SCHEMA:-}" ]]; then
  LATEST_SCHEMA="$CHEAT_LATEST_SCHEMA"
fi
schema_mismatch=""
if [[ "$schema_version" != "$LATEST_SCHEMA" && "$schema_version" != "unknown" ]]; then
  schema_mismatch="⚠️  schema 版本不一致：state=${schema_version}, skill 期望=${LATEST_SCHEMA}。建议跑 /cheat-migrate（非阻塞，部分新功能可能在迁移前异常）。"
elif [[ "$schema_version" == "unknown" ]]; then
  schema_mismatch="⚠️  state.schema_version 字段缺失或损坏。建议跑 /cheat-status 检查文件，或备份后重 init。"
fi

# --- Detect blind-skip contamination (cheat-predict --skip-blind 或 Phase 2.5 选 b 触发) ---
self_scored_warning=""
if [[ "$last_prediction_self_scored" == "true" && -n "$last_self_scored_at" ]]; then
  self_scored_epoch=$(parse_iso_epoch "$last_self_scored_at")
  if [[ $self_scored_epoch -gt 0 ]]; then
    days_since=$(( (now_epoch - self_scored_epoch) / 86400 ))
    if [[ $days_since -ge 7 ]]; then
      self_scored_warning="🚨 距上次 \`--skip-blind\` 自评预测已 ${days_since} 天——校准池累计的 contamination 风险在叠加。下次 /cheat-predict 走 sub-agent 即可清除此提示。"
    else
      self_scored_warning="⚠️  上次预测走了 \`--skip-blind\`（${days_since} 天前自评，未经 channel B 隔离）。下次 /cheat-predict 走默认即可清除。"
    fi
  fi
fi

# --- Derive confidence label (single source: state-management.md confidence 表) ---
if   [[ $calibration_samples -eq 0 ]]; then
  confidence="🔴 极低 (占星级别，纯纪律训练)"
elif [[ $calibration_samples -le 2 ]]; then
  confidence="🟠 低 (中枢 ±50%，方向感优于绝对数字)"
elif [[ $calibration_samples -le 5 ]]; then
  confidence="🟡 偏低 (中枢 ±40%，可作为参考之一)"
elif [[ $calibration_samples -le 10 ]]; then
  confidence="🟢 中 (中枢 ±25%，可参与决策)"
elif [[ $calibration_samples -le 20 ]]; then
  confidence="🟢 较高 (中枢 ±15%，rubric 形态稳定)"
else
  confidence="🔵 高 (中枢 ±10%，可数据驱动)"
fi

# --- Compute buffer color (video only; article/xhs do not use shoot buffer) ---
buffer_label=""
buffer_warning=""
if [[ "$default_format" != "video" ]]; then
  buffer_label="📦 Buffer: 非视频格式不使用拍摄队列（当前 ${default_format}）"
elif [[ "$target_cadence" == "null" ]] || [[ -z "$target_cadence" ]]; then
  # Flexible cadence: no color, just count
  buffer_label="📦 Buffer: ${buffer_count} 篇 (灵活节奏，无警戒)"
else
  buffer_days=$(( buffer_count * target_cadence ))
  if   [[ $buffer_days -lt 1 ]]; then
    buffer_label="📦 Buffer: ${buffer_count} 篇 🔴 红 (按 cadence ${target_cadence}d = <1 天预备)"
    buffer_warning="🚨 buffer 警戒：下个发布日可能断更。今天必须拍 ≥1 条稳分。"
  elif [[ $buffer_days -le 2 ]]; then
    buffer_label="📦 Buffer: ${buffer_count} 篇 🟠 橙 (按 cadence ${target_cadence}d = ${buffer_days} 天预备)"
  elif [[ $buffer_days -le 5 ]]; then
    buffer_label="📦 Buffer: ${buffer_count} 篇 🟢 绿 (按 cadence ${target_cadence}d = ${buffer_days} 天预备)"
  else
    buffer_label="📦 Buffer: ${buffer_count} 篇 🔵 蓝 (按 cadence ${target_cadence}d = ${buffer_days} 天，积压)"
    buffer_warning="📦 buffer 积压：建议暂停拍摄，先发存货 + 复盘。"
  fi
fi

# --- Compute pending retros that are actually due ---
retro_window=3   # default RETRO_WINDOW_DAYS, hardcoded fallback (TODO: read from rubric_notes if present)
due_count=0
earliest_due=""
if [[ "$pending_retros_count" -gt 0 ]]; then
  # Walk pending_retros, check each prediction file's published_at
  while IFS= read -r pred_file; do
    pred_path="$PROJECT_DIR/$pred_file"
    if [[ -f "$pred_path" ]]; then
      pub_iso=$(grep -E '^\*\*Published at\*\*:' "$pred_path" 2>/dev/null | head -1 | sed -E 's/.*: *//')
      if [[ -n "$pub_iso" ]]; then
        pub_epoch=$(parse_iso_epoch "$pub_iso")
        if [[ $pub_epoch -gt 0 ]]; then
          age_days=$(( (now_epoch - pub_epoch) / 86400 ))
          if [[ $age_days -ge $retro_window ]]; then
            due_count=$((due_count + 1))
            if [[ -z "$earliest_due" ]] || [[ "$pub_iso" < "$earliest_due" ]]; then
              earliest_due="$pub_iso"
            fi
          fi
        fi
      fi
    fi
  done < <(echo "$state" | jq -r --arg fmt "$default_format" '.formats[$fmt].pending_retros // .pending_retros // [] | .[]')
fi

retro_label=""
if [[ $due_count -gt 0 ]]; then
  retro_label="⏰ 待复盘: ${due_count} 篇 (最早: ${earliest_due%%T*})"
elif [[ "$pending_retros_count" -gt 0 ]]; then
  retro_label="⏰ 待复盘: ${pending_retros_count} 篇 (未到 T+${retro_window}d)"
else
  retro_label="⏰ 待复盘: 无"
fi

# --- Top candidates (read first 3 H3 from candidates.md) ---
candidates_file="$PROJECT_DIR/candidates.md"
top_candidates=""
if [[ -f "$candidates_file" ]]; then
  # Extract first 3 H3 titles, format compactly
  top_candidates=$(grep -E '^### ' "$candidates_file" 2>/dev/null \
    | head -3 \
    | sed -E 's/^### \[[^]]+\] *//' \
    | tr '\n' '/' \
    | sed 's:/$::' \
    | sed 's:/: / :g')
fi
if [[ -z "$top_candidates" ]]; then
  candidates_label="🎯 候选: (空——说 '抓热点' 或 '找选题')"
else
  candidates_label="🎯 候选 top 3: ${top_candidates}"
fi

# --- Last trends run ---
trends_label=""
if [[ -n "$last_trends_at" ]]; then
  trends_epoch=$(parse_iso_epoch "$last_trends_at")
  if [[ $trends_epoch -gt 0 ]]; then
    days_ago=$(( (now_epoch - trends_epoch) / 86400 ))
    trends_label="📅 上次抓热点: ${days_ago} 天前"
  fi
fi

# --- Build the report ---
echo ""
echo "[cheat-on-content / SessionStart 状态报告]"
echo ""
echo "📂 Channel: $CHANNEL_REL"
echo ""
echo "📦 默认格式: $default_format"
echo ""

# Per-format status (if formats object exists)
if [[ "$has_formats" != "null" ]]; then
  for fmt in video article xhs; do
    fmt_rubric=$(echo "$state" | jq -r ".formats.${fmt}.rubric_version // \"v0\"")
    fmt_cal=$(echo "$state" | jq -r ".formats.${fmt}.calibration_samples // 0")
    fmt_pending=$(echo "$state" | jq -r ".formats.${fmt}.pending_retros // [] | length")
    case "$fmt" in
      video)   echo "🎬 视频: rubric ${fmt_rubric} | 校准 ${fmt_cal} | 待复盘 ${fmt_pending} | Buffer ${buffer_count}" ;;
      article) echo "📝 公众号: rubric ${fmt_rubric} | 校准 ${fmt_cal} | 待复盘 ${fmt_pending}" ;;
      xhs)     echo "📱 小红书: rubric ${fmt_rubric} | 校准 ${fmt_cal} | 待复盘 ${fmt_pending}" ;;
    esac
  done
  echo ""
fi

echo "$buffer_label"
echo "$retro_label"
echo "$candidates_label"
[[ -n "$trends_label" ]] && echo "$trends_label"

# Confidence indicator
echo "📈 校准样本: ${calibration_samples} | Confidence: ${confidence}"

# Warnings (high priority)
[[ -n "$buffer_warning" ]] && echo "" && echo "$buffer_warning"
[[ -n "$schema_mismatch" ]] && echo "" && echo "$schema_mismatch"
[[ -n "$self_scored_warning" ]] && echo "" && echo "$self_scored_warning"
if [[ "$form_severe_mismatch" == "true" ]]; then
  echo "❌ rubric 与你的内容形态严重不匹配——预测几乎无意义。"
fi
if [[ "$hooks_installed" != "true" ]]; then
  echo "⚠️  immutability hook 未装——你的盲预测保护是君子协定，不是物理强制。"
fi

# Check content-guard hook only for projects that use article/xhs/aihot routes.
if [[ "$content_guard_relevant" == "true" ]]; then
  settings_dir="${CLAUDE_PROJECT_DIR:-$PROJECT_DIR}"
  if [[ ! -f "$settings_dir/.claude/settings.json" ]] || ! grep -q "content-guard" "$settings_dir/.claude/settings.json" 2>/dev/null; then
    echo "⚠️  content-guard hook 未注册——文章/小红书模板与 AI HOT 路由不会被物理强制。"
  fi
fi

# Check aihot routing compliance (if AI content was written recently)
aihot_log="$PROJECT_DIR/.cheat-cache/aihot-called.log"
today=$(date +%Y-%m-%d)
if [[ "$content_guard_relevant" == "true" && -f "$aihot_log" ]]; then
  last_aihot=$(tail -1 "$aihot_log" 2>/dev/null || echo "")
  if [[ "$last_aihot" != "$today" ]]; then
    # Check if there are recent AI content files written today
    recent_ai_content=$(find "$PROJECT_DIR/articles" "$PROJECT_DIR/xhs" "$PROJECT_DIR/scripts" -name "*.md" -newer "$aihot_log" 2>/dev/null | head -1)
    if [[ -n "$recent_ai_content" ]]; then
      echo "⚠️  检测到今日有 AI 内容写入但 aihot 未调用——下次写 AI 资讯前请先说 'AI 热点' 或 '今天 AI 圈有什么'。"
    fi
  fi
fi

# Adversarial lifecycle check: articles should not silently bypass predictions/.
# This warns instead of blocking because cheat-predict needs the final draft to
# exist before it can write an immutable prediction.
orphan_count=0
orphan_examples=""
note_orphan() {
  orphan_count=$((orphan_count + 1))
  if [[ -z "$orphan_examples" ]]; then
    orphan_examples="$1"
  elif [[ "$orphan_count" -le 3 ]]; then
    orphan_examples="${orphan_examples}, $1"
  fi
}
if [[ -d "$PROJECT_DIR/articles" && -d "$PROJECT_DIR/predictions" ]]; then
  while IFS= read -r article_file; do
    rel_article="${article_file#$PROJECT_DIR/}"
    article_name="$(basename "$article_file")"
    case "$article_name" in
      cover-prompt.md|publish-notes.md|captions.md|risk-notes.md|sources.md|report.md|*-prompt.md|meta.md|script.md)
        continue
        ;;
    esac
    if [[ "$article_name" == "draft.md" && -f "$(dirname "$article_file")/draft.wechat-article.md" ]]; then
      continue
    fi
    parent_name="$(basename "$(dirname "$article_file")")"
    if [[ "$(basename "$(dirname "$(dirname "$article_file")")")" == "articles" ]]; then
      article_id="$parent_name"
    else
      article_id="${article_name%.md}"
    fi
    if ! find "$PROJECT_DIR/predictions" -maxdepth 1 -type f -name "*${article_id}*.md" | grep -q . && \
       ! grep -R -q "$rel_article" "$PROJECT_DIR/predictions" 2>/dev/null; then
      note_orphan "$rel_article"
    fi
  done < <(find "$PROJECT_DIR/articles" -maxdepth 3 -type f -name "*.md" 2>/dev/null | sort)
fi

# Same check for xhs: every xhs/<id>/post.md needs a matching prediction
if [[ -d "$PROJECT_DIR/xhs" && -d "$PROJECT_DIR/predictions" ]]; then
  while IFS= read -r post_file; do
    rel_post="${post_file#$PROJECT_DIR/}"
    post_id="$(basename "$(dirname "$post_file")")"
    if ! find "$PROJECT_DIR/predictions" -maxdepth 1 -type f -name "*${post_id}*.md" | grep -q . && \
       ! grep -R -q "xhs/${post_id}" "$PROJECT_DIR/predictions" 2>/dev/null; then
      note_orphan "$rel_post"
    fi
  done < <(find "$PROJECT_DIR/xhs" -maxdepth 2 -type f -name "post.md" 2>/dev/null | sort)
fi

if [[ "$orphan_count" -gt 0 ]]; then
  echo "🚧  检测到 ${orphan_count} 篇公众号/小红书草稿没有对应 prediction：${orphan_examples}"
  echo "   先跑 \`cheat-predict --format=<article|xhs> <draft>\`，再发布；已发布的只能标 reconstructed，不能补盲预测。"
fi

echo ""
echo "（不要主动开始任何动作——等用户决定。说 \"状态\" 看完整看板。）"
echo ""

exit 0
