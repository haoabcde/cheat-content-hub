# State Management（状态文件读写约定）

被所有子 skill 引用。`.cheat-state.json` 是各子 skill 共享上下文的**单一来源**——任何运行时状态、累计指标、模式标记都从这里读、写回这里。

---

## 文件位置

```
<user-content-project>/.cheat-state.json
```

**绝不**放到全局 `~/.claude/` 或 cheat-on-content 自己的目录——一个用户可能维护多个内容项目，每个项目独立状态。

---

## 完整 schema（v1.5 正本）

```json
{
  "schema_version": "1.5",
  "skill_version": "1.0.0",
  "default_format": "video",
  "typical_duration_seconds": 240,
  "target_publish_cadence_days": 2,
  "benchmark_status": "none",
  "benchmark_name": null,
  "benchmark_sample_count": 0,
  "data_collection": "manual",
  "pool_status": "none",
  "data_layer": "markdown",
  "hooks_installed": false,
  "enabled_trend_sources": ["manual-paste"],
  "enabled_perf_adapters": [],
  "last_trends_run_at": null,
  "last_trends_added_count": 0,
  "in_progress_session": null,
  "initialized_at": "2026-05-04T15:00:00+08:00",
  "formats": {
    "video": {
      "rubric_version": "v0",
      "content_form": "opinion-video",
      "rubric_form_mismatch": false,
      "artifact_dir": "videos",
      "baseline_plays": null,
      "calibration_samples": 0,
      "calibration_samples_at_last_bump": 0,
      "consecutive_directional_errors": [],
      "pending_retros": [],
      "shoots": [],
      "last_bump_at": null,
      "last_bump_self_audited": false,
      "last_published_at": null,
      "last_published_file": null,
      "last_retro_at": null,
      "last_prediction_self_scored": false,
      "last_self_scored_at": null
    },
    "article": {
      "rubric_version": "v0",
      "content_form": "wechat-article",
      "rubric_form_mismatch": false,
      "artifact_dir": "articles",
      "baseline_plays": null,
      "calibration_samples": 0,
      "calibration_samples_at_last_bump": 0,
      "consecutive_directional_errors": [],
      "pending_retros": [],
      "last_bump_at": null,
      "last_bump_self_audited": false,
      "last_published_at": null,
      "last_published_file": null,
      "last_retro_at": null,
      "last_prediction_self_scored": false,
      "last_self_scored_at": null
    },
    "xhs": {
      "rubric_version": "v0",
      "content_form": "xhs-post",
      "rubric_form_mismatch": false,
      "artifact_dir": "xhs",
      "baseline_plays": null,
      "calibration_samples": 0,
      "calibration_samples_at_last_bump": 0,
      "consecutive_directional_errors": [],
      "pending_retros": [],
      "last_bump_at": null,
      "last_bump_self_audited": false,
      "last_published_at": null,
      "last_published_file": null,
      "last_retro_at": null,
      "last_prediction_self_scored": false,
      "last_self_scored_at": null
    }
  }
}
```

> **legacy fallback**：`formats` 不存在时，老用户的顶层字段（`rubric_version`、`calibration_samples`、`pending_retros`、`shoots` 等）按旧版 video 逻辑读取。新 init 和新写入一律使用 `formats.<format>`。详见 [migrations/1.4-to-1.5.md](../migrations/1.4-to-1.5.md)。

### 格式映射

| `format` | 默认产物目录 | 默认 `content_form` | 适用场景 |
|---|---|---|---|
| `video` | `videos/` | `opinion-video` | 抖音 / B 站 / YouTube / 视频号等视频内容 |
| `article` | `articles/` | `wechat-article` | 公众号 / Substack / Medium 长文 |
| `xhs` | `xhs/` | `xhs-post` | 小红书图文 / 笔记 |

`content_form` 是更细的内容形态，`format` 是文件布局与 rubric 路由。用户不知道该选时，先选 `default_format`，后续可在单次命令里用 `--format=<video|article|xhs>` 覆盖。

### 实绩指标映射（按格式）

复盘、预测、bump、状态报告里所有"实绩数据"措辞，一律按此表解释——任何文件不再单独硬编码指标口径，需要时引用本节：

| `format` | 主指标（排序 / baseline 用） | 辅助指标 | 核心派生比率 |
|---|---|---|---|
| `video` | 播放（actual_plays） | 点赞 / 评论 / 转发 / 收藏 / 完播 | 赞播比、评播比、分播比 |
| `article` | 阅读（actual_reads） | 在看 / 点赞 / 转发 / 收藏 | 赞阅比、在看率 |
| `xhs` | 点赞 + 收藏（actual_likes / actual_collects） | 曝光 / 评论 | 收藏率、赞藏比 |

约定：
- `baseline_plays` 字段名保留不变（不改 schema），但对 article 语义是"基线阅读量"、对 xhs 是"基线赞藏量级"——字段名是历史遗留，语义按格式映射
- bucket 桶的单位按格式解释：video=播放数、article=阅读数、xhs=赞藏量级
- 跨格式比较 composite 分或 bucket 不直接可比（rubric 维度与单位都不同），排序与 rank 一致性校验只允许在同格式样本内进行

### 关键变更（v1.5）

相比 v1.4（**MAJOR — 老用户必须跑 /cheat-migrate**）：

- **多格式扩展**：新增 `default_format` 字段（顶层）和 `formats` 对象，包含 `video`、`article`、`xhs` 三个子对象
- 每个格式独立维护 `rubric_version`、`calibration_samples`、`pending_retros`、`shoots`、时间戳等字段
- 老用户的顶层字段（`rubric_version`、`calibration_samples` 等）迁移到 `formats.video` 下
- 新增 `formats.article` 和 `formats.xhs`（使用默认值）
- 新增公众号和小红书 starter rubric（`starter-rubrics/wechat-article*.md`、`xhs-post*.md`）
- 新增 `content-guard` hook 强制模板合规
- 不跑 migrate 的后果：所有格式的校准进度从 0 开始，老数据丢失

### 关键变更（v1.4）

相比 v1.3（**MINOR but BREAKING for blind channel integrity**——老用户必须跑 migrate）：

- **rubric 文件拆分**：`rubric_notes.md` → `rubric_notes.md`（公式 + 通用维度定义；blind 白名单）+ `rubric-memo.md`（升级 Memo 含证据 + 派生证据；blind 硬禁读）
- **state 字段不变**——仅 `schema_version` bump 标识老用户须跑迁移把现有 rubric_notes.md 拆成两份文件
- 配合 [skills/cheat-score-blind/SKILL.md](../skills/cheat-score-blind/SKILL.md) 的 `blocked_rubric_memo` refusal_code + cheat-bump Phase 5 leak guard 自检
- **不跑 migrate 的后果**：blind sub-agent 仍会读到 rubric_notes.md 里的实绩，sub-agent 会自报 `non_blind_warning` 并降所有 confidence 到 medium——可用但不再是"真盲"
- 详见 [migrations/1.3-to-1.4.md](../migrations/1.3-to-1.4.md)

### 关键变更（v1.3）

相比 v1.2（MINOR，兼容）：

- **新增 `last_prediction_self_scored: bool`**——`true` 仅当上一次 `/cheat-predict` 走了 `--skip-blind` flag 或 Phase 2.5 用户选 b（信主 Claude 自估）。cheat-status / SessionStart hook 据此 nag："上次预测没走 blind sub-agent，已 N 天"
- **新增 `last_self_scored_at: ISO 8601 / null`**——`last_prediction_self_scored` 触发时的时间戳；走 sub-agent 时一起清回 null
- 配合 [skills/cheat-score-blind](../skills/cheat-score-blind/SKILL.md) 的 channel B 隔离协议——把 contamination 跟踪从"靠 git history"升级为"靠 state 字段"
- 老 state 缺这两字段 → 兜底 `false` / `null`，**MINOR 兼容**

### 关键变更（v1.2）

相比 v1.1（MINOR，兼容）：

- **`shoots[]` 项 schema 扩展**——新增 `scripts_path`、`script_consistency`、`script_diff_pct`、`v2_prediction_written`、`script_hash_at_shoot` 字段。语义见 cheat-shoot Phase 4。这些字段记录"拍后改稿是否触发 v2 预测重判"，cheat-retro 据此决定读 `## 预测 v1` 还是 `## 预测 v2`
- 老 state 缺这些字段 → skills 用 `state.get(field, default)` 兜底（`script_consistency` 默认 `"consistent"`，`v2_prediction_written` 默认 `false`，`script_diff_pct` 默认 `null`）。**不强制跑 migrate**——但跑了让 state 字段对齐 schema 文档

### 关键变更（v1.1）

相比 v1.0：

- **删除 `mode`**（"cold-start" / "calibration" 二元）→ 用 `calibration_samples` 整数判断状态
- **删除 `prediction_complexity`**（"cold-start-simple" / "complete" 二元）→ 所有预测都用统一完整 7 组件结构，**confidence 等级派生自 calibration_samples**
- **删除 `bucket_scheme`**（"ratio" / "absolute" / "absolute_with_ratio" / "percentile" 四档）→ bucket 边界由单一算法**自动派生**：有 `baseline_plays` → 按倍数；无 → 平台通用默认；样本 ≥10 → 重算 baseline

理由：硬模式切换是设计者的猜测，不是用户体验该有的样子。统一流程 + 渐进信心标注更符合"频道是不断进化的连续光谱，不是离散阶段"的事实。

---

## 字段说明（每个字段的语义 + 谁写谁读）

### 元数据

| 字段 | 类型 | 写入者 | 读取者 | 说明 |
|---|---|---|---|---|
| `schema_version` | string | cheat-init / cheat-migrate | 所有 skill | 当前为 "1.5"。schema 升级时 bump；老用户由 [/cheat-migrate](../skills/cheat-migrate/SKILL.md) 升级。详见 [migration-protocol.md](migration-protocol.md) |
| `skill_version` | string | cheat-init | 所有 skill | cheat-on-content 当前版本 |
| `initialized_at` | ISO 8601 | cheat-init | cheat-status | 首次初始化时间，永不变 |

### 模式与配置

| 字段 | 类型 | 取值 | 写入者 | 读取者 |
|---|---|---|---|---|
| `default_format` | enum | "video" / "article" / "xhs" | cheat-init / 用户手动配置 | 所有格式感知 skill |
| `typical_duration_seconds` | int | 用户视频典型时长。决定 cheat-seed 写 draft 的字数 + cheat-predict 锚点优先同时长 | cheat-init | cheat-seed / cheat-predict |
| `target_publish_cadence_days` | int / null | 用户目标发布频率（1=日更 / 2=隔日 / 7=周更 / null=灵活）。决定 buffer 警戒颜色阈值 | cheat-init | cheat-status / cheat-recommend / cheat-shoot / cheat-publish / SessionStart hook |
| `benchmark_status` | enum | "none" / "imported" / "pending"（用户答应等下找）| cheat-init / cheat-learn-from | cheat-seed（brainstorm 时读 benchmark.md）/ cheat-status（pending 时持续提醒） |
| `benchmark_name` | string / null | 对标账号名（如"蜗牛学长留学"）；none 时为 null | cheat-learn-from | cheat-status / cheat-seed |
| `benchmark_sample_count` | int | 已导入的对标视频条数 | cheat-learn-from（写入 / append） | cheat-status（N≥10 时提示 benchmark 影响淡出） |
| `data_collection` | enum | "manual" / "adapter" | cheat-init | cheat-retro（决定 DATA_SOURCE 默认值） |
| `pool_status` | enum | "none" / "markdown" / "notion" / "sqlite" | cheat-init / cheat-recommend | cheat-recommend / cheat-status |
| `data_layer` | enum | "markdown" / "sqlite" | cheat-init / md-to-sqlite.py | 所有读 predictions 的 skill |
| `hooks_installed` | bool | true / false | cheat-init | cheat-status（持续提示） |
| `enabled_trend_sources` | array of string | trend-source adapter 名列表（如 `["weibo-hot", "zhihu-hot"]`） | cheat-init / 用户手动 | cheat-trends |
| `enabled_perf_adapters` | array of string | perf-data adapter 名列表（如 `["douyin-session"]`）。空 → cheat-retro 走 manual paste | cheat-init / 用户手动配置后 | cheat-retro |

### 格式状态（`formats.<format>`）

| 字段 | 类型 | 写入者 | 读取者 | 说明 |
|---|---|---|---|---|
| `rubric_version` | string | cheat-init / cheat-bump | cheat-score / cheat-predict / cheat-retro | 该格式当前 rubric 版本 |
| `content_form` | enum | cheat-init / 用户手动 | cheat-predict / cheat-recommend | 该格式的具体内容形态 |
| `rubric_form_mismatch` | bool | cheat-init / cheat-bump | cheat-status | true 表示当前 starter rubric 与内容形态不完全匹配，bump 时优先调权重 |
| `artifact_dir` | string | cheat-init | cheat-publish / cheat-retro / adapters | 该格式产物目录，默认 `videos` / `articles` / `xhs` |
| `baseline_plays` | int / null | cheat-init / cheat-retro / cheat-bump (--bucket-only) | cheat-predict | 该格式的基准表现中位数；article/xhs 语义是阅读/浏览量 |

### 累计计数

| 字段 | 类型 | 写入者 | 用途 |
|---|---|---|---|
| `formats.<format>.calibration_samples` | int | cheat-retro（每次复盘 +1） | cheat-status 进度条 / cheat-bump 门槛 |
| `formats.<format>.calibration_samples_at_last_bump` | int | cheat-bump | "距上次 bump 多少新样本" |

### 时间戳（last_X_at）

| 字段 | 类型 | 写入者 |
|---|---|---|
| `formats.<format>.last_bump_at` | ISO 8601 / null | cheat-bump |
| `formats.<format>.last_bump_self_audited` | bool | cheat-bump（CROSS_MODEL_AUDIT=false 时 true） |
| `formats.<format>.last_published_at` | ISO 8601 / null | cheat-publish |
| `formats.<format>.last_published_file` | string / null | cheat-publish |
| `formats.<format>.last_retro_at` | ISO 8601 / null | cheat-retro |
| `last_trends_run_at` | ISO 8601 / null | cheat-trends |
| `last_trends_added_count` | int | cheat-trends |
| `formats.<format>.last_prediction_self_scored` | bool | cheat-predict（`--skip-blind` 或 Phase 2.5 选 b 时 true；下次走 sub-agent 时清回 false） |
| `formats.<format>.last_self_scored_at` | ISO 8601 / null | cheat-predict（跟随 `last_prediction_self_scored` 同步） |

### 列表队列

| 字段 | 类型 | 写入者 | 读取者 | 协议 |
|---|---|---|---|---|
| `formats.<format>.consecutive_directional_errors` | array of "high"/"low" | cheat-retro（push） / cheat-bump（清空） | cheat-status / cheat-retro 自检 | 最近 N 次复盘的偏差方向；连续 3 同向触发 bump 提议 |
| `formats.<format>.pending_retros` | array of file path | cheat-publish（push） / cheat-retro（remove） | cheat-status | 等待复盘的预测文件路径 |
| `formats.video.shoots` | array of {video_folder, prediction_file, shot_at, ad_hoc} | cheat-shoot（push） / cheat-publish（remove） | cheat-status / cheat-recommend / SessionStart hook | 仅 video 使用。已拍未发队列。`len(shoots) = buffer count`，`buffer_days = buffer × target_publish_cadence_days` 决定颜色 |

### 会话状态

| 字段 | 类型 | 写入者 | 读取者 | 协议 |
|---|---|---|---|---|
| `in_progress_session` | object / null | cheat-predict（创建） / cheat-publish（清除） | cheat-publish / cheat-status | 见下方"in_progress_session 子结构" |

#### `in_progress_session` 子结构

```json
{
  "type": "prediction",
  "file": "predictions/2026-05-04_a3f2c1d4e5b6_停止期待.md",
  "started_at": "2026-05-04T14:00:00+08:00",
  "rubric_version": "v2"
}
```

`type`：当前只有 `"prediction"`。未来可能加 `"bump"` 表示长流程 bump 在进行中。

---

## 读写协议

### 读（任何 skill）

```python
# 伪代码
import json, os

state_path = os.path.join(os.getcwd(), ".cheat-state.json")
if not os.path.exists(state_path):
    # 不存在 = 用户没初始化，路由到 /cheat-init
    raise NeedsInitError()

with open(state_path) as f:
    state = json.load(f)

# 检查 schema_version 兼容
LATEST_SCHEMA = "1.5"  # see migrations/registry.md
if state.get("schema_version") != LATEST_SCHEMA:
    # 不直接 raise — 提示用户跑 /cheat-migrate（非阻塞）
    log_warning(f"schema 版本不匹配：state={state.get('schema_version')}, 期望={LATEST_SCHEMA}。建议跑 /cheat-migrate")
    # MINOR mismatch 通常仍能继续；MAJOR 时部分字段读取可能 KeyError → 用 .get(field, default) 兜底

fmt = requested_format or state.get("default_format") or "video"
format_state = state.get("formats", {}).get(fmt)
if format_state is None:
    # legacy fallback：老 state 没有 formats 时，把顶层字段当 video 读
    format_state = state
```

**关键纪律**：
- 读完不立刻关心字段缺失——用 `state.get(field, default)` 容错。新版 skill 引入新字段时旧 state file 会缺该字段，应优雅默认而非崩溃
- **绝不**在内存里 mutate state 后忘记写回——下游 skill 读到的是磁盘版

### 写（任何 skill）

```python
# 伪代码 — read-modify-write 模式
state = read_state()
fmt = requested_format or state.get("default_format") or "video"
state.setdefault("formats", {}).setdefault(fmt, default_format_state(fmt))
state["formats"][fmt]["calibration_samples"] += 1
state["formats"][fmt]["last_retro_at"] = now_iso()
write_state(state)

def write_state(state):
    state_path = os.path.join(os.getcwd(), ".cheat-state.json")
    tmp_path = state_path + ".tmp"
    with open(tmp_path, "w") as f:
        json.dump(state, f, indent=2, ensure_ascii=False)
    os.replace(tmp_path, state_path)  # atomic rename
```

**关键纪律**：
- **原子写**：写到 .tmp → rename。避免半写损坏的 state file
- **永远 indent=2**：人类可读，便于用户手改 + git diff
- **ensure_ascii=False**：保留中文字符不转 \uXXXX
- **写完再继续后续操作**：避免下游 skill 读到旧值

### 并发模型

预期场景：**单用户 + 单 Claude Code 会话**。不做锁。

如果两个会话并行操作同一个项目（罕见且不推荐）：可能出现写覆盖。**未来需要时**可加文件锁（`fcntl.flock`）；当前不加，避免引入复杂度。

---

## 字段写入责任表（防止"谁该写这个字段"歧义）

| 字段 | 唯一写入者 | 何时写 |
|---|---|---|
| `formats.<format>.rubric_version` | cheat-init / cheat-bump | init 写初值；bump 升版 |
| `formats.<format>.baseline_plays` | cheat-init / cheat-retro / cheat-bump (--bucket-only) | init 时若有 adapter 抓回历史→中位数；无历史→null；retro 第 1 篇有实绩→回填；bump --bucket-only→重新计算 |
| `formats.<format>.calibration_samples` | cheat-retro | 每次复盘成功落盘 +1 |
| `formats.<format>.pending_retros` | cheat-publish（push）/ cheat-retro（remove） | publish 时 push 本次；retro 完成时 remove |
| `formats.<format>.consecutive_directional_errors` | cheat-retro（push）/ cheat-bump（清空） | retro 判定偏差方向时 push；bump 落地时清空 |
| `in_progress_session` | cheat-predict（创建）/ cheat-publish（清除） | predict 写完文件时创建；publish 登记时清除 |
| `formats.<format>.last_bump_at` | cheat-bump | bump 落地时 |

**绝不允许**多个 skill 写同一字段——会导致状态语义破碎。如果未来需要新字段，先想好"谁是唯一写者"。

---

## state file 损坏 / 不一致的处理

| 症状 | 处理 |
|---|---|
| 文件不存在 | 提示"未初始化，请跑 /cheat-init"，**不**自动创建 |
| JSON 解析失败 | 提示"state file 损坏：path/to/.cheat-state.json"，建议手动修复或备份 + 重新 init |
| schema_version 不识别 | 提示版本号 + 建议跑 [/cheat-migrate](../skills/cheat-migrate/SKILL.md)。SessionStart hook 会自动检测并提示 |
| `formats.<format>.pending_retros` 含已删除的文件 | cheat-status 检测时安静移除，不报错 |
| `in_progress_session` 文件已不存在 | cheat-status 检测到 → 询问用户是否清理 |
| `formats.<format>.calibration_samples` 与 `predictions/` 实际复盘数不一致 | cheat-status 报告差异。临时手改 state 即可；持续不一致是 bug，应在下个 minor 版本里加入 cheat-migrate 的 reconciliation step |

---

## 与 git 的关系

`.cheat-state.json` **应该**被纳入 git：
- ✅ 它是项目配置 + 累计指标的快照
- ✅ git history 提供状态演化的完整轨迹
- ✅ 多设备同步靠 git push/pull
- ❌ **不**含敏感信息（cookie / API key 应放 `.env` 或 `.cheat-secrets.json`，单独 gitignore）

`.cheat-cache/` 目录**不应该**被纳入 git：
- 含 `usage.jsonl`（meta-logging 钩子的本地日志）
- 含 `trends-history.jsonl`（trend 抓取的去重缓存）
- 也可能含 adapter 调试文件（如 `douyin-session-debug/`）
- 这些是设备本地状态，跨设备同步无意义

`/cheat-init` 应自动在用户项目根追加（不覆盖）`.gitignore`：

```
.cheat-cache/
.cheat-secrets.json
```

---

## 升级路径

完整哲学和 maintainer checklist 详见 [migration-protocol.md](migration-protocol.md)。简版：

未来 schema 变化时：
1. bump `schema_version`（如 "1.1" → "1.2"）
2. 写 `migrations/<old>-to-<new>.md`（4 段：WHAT/WHY/HOW/Manual fallback）
3. 改 `migrations/registry.md` 的 `LATEST_SCHEMA` 标记位 + 版本链表
4. SessionStart hook 检测到不一致时自动提示用户跑 `/cheat-migrate`
5. **绝不**让 skill 静默兼容旧版 schema 的删字段或重命名——那会让"哪个版本下哪个字段是什么含义"成谜

新增字段（MINOR，不破坏兼容）：
- 用 `state.get(field, default)` 读
- 老 state file 自动获得 default
- **仍需 bump schema_version + 写 migrations 文件**——保证状态文件最终一致；但用户可以延迟跑 migrate

删除 / 重命名 / 改语义（MAJOR，破坏兼容）：
- 必须 bump schema_version + 写迁移文件
- CHANGELOG 标 `BREAKING`

---

## 用户手改 state file 的边界

允许手改的字段：
- `enabled_trend_sources`（数组，决定 cheat-trends 用哪些源）
- `data_collection`（切换 manual ↔ adapter）

**不**建议手改的字段（会破坏不变量）：
- `calibration_samples` / `pending_retros` / `consecutive_directional_errors`（应通过 retro 流程更新）
- `rubric_version`（应通过 bump 流程更新）
- `in_progress_session`（应通过 predict/publish 流程更新）

如用户确实想重置：建议**删除整个 .cheat-state.json + 重跑 /cheat-init**——这比手改单字段安全。

---

## Confidence label 派生表（**单一真值**）

被 cheat-predict / cheat-status / cheat-recommend / SessionStart hook 等共同使用。从 `calibration_samples` 派生，所有 skill 用同一逻辑：

| `calibration_samples` | confidence emoji + 标签 | 数值含义 | 用户该如何用 |
|---|---|---|---|
| 0 | 🔴 极低 | "占星级别，纯纪律训练" | 不要基于 composite 决定要不要发；写 prediction 是为了**采集数据**，不是为了**做决策** |
| 1-2 | 🟠 低 | "中枢 ±50%，方向感优于绝对数字" | 信"A 比 B 流量好"的方向，不信具体数字 |
| 3-5 | 🟡 偏低 | "中枢 ±40%，可作为参考之一" | bucket 排序可用，中枢点估计仍是猜测 |
| 6-10 | 🟢 中 | "中枢 ±25%，可参与决策" | 可作为"要不要发"的依据之一 |
| 11-20 | 🟢 较高 | "中枢 ±15%，rubric 形态稳定" | 可信中枢估计 |
| 21+ | 🔵 高 | "中枢 ±10%，可数据驱动 bump" | 进入数据驱动阶段 — bump 用回归而非直觉 |

> 上表的 ±X% 是**经验值**（基于参考博主的真实校准曲线），不是数学严格保证。新人账号的真实 ±X% 要等自己跑出 score-curve.png 才能验证。

**不要用这个表来 gating 任何功能**——所有 skill 在所有 calibration_samples 下都跑相同流程，只是输出里**显示**当前 confidence 等级。这是新设计的核心原则。
