# 工作流速查（cheat-on-content）

> 这是 `/cheat-init` 在你的项目根创建的速查文档。完整规范在 cheat-on-content 的 `SKILL.md` 和 `shared-references/`。
> 本文件给"忘了下次该说什么"的时候用——不需要从头读完。

---

## 一句话流程

> **格式分叉**：以下主流程链按 video 格式描述（含 cheat-shoot → videos/ → buffer 环节）。article / xhs 无 shoot 环节、无 buffer，流程为 选题 → 写稿（cheat-seed 或自己写）→ 预测 → 排版（自建排版 skill）→ 发布 → 复盘——两个图文格式各有一个专用小节，见下文。

```
找选题
  ├─ 没发过历史的 → /cheat-seed brainstorm（兴趣 × 热点）
  └─ 发过历史的    → /cheat-seed brainstorm（兴趣 × 热点 × 你过去做过什么）
                    （都跑 cheat-seed，区别是发过的 brainstorm 时多一份历史 context）
  ↓
cheat-seed 写 5 个草稿到 → scripts/<日期>_<id>_<short>.md
  ↓
用户改写 scripts/<日期>_<id>_<short>.md（同一文件覆盖）
  ↓
/cheat-score scripts/<日期>_<id>_<short>.md → 看 rubric 评分（探索）
  ↓
/cheat-predict scripts/<日期>_<id>_<short>.md → 写 immutable 预测 v1 到 predictions/
  ↓
拍摄完（仅 video）→ /cheat-shoot scripts/<日期>_<id>_<short>.md
   ├─ 建 videos/<日期>_<id>_<short>/ 目录
   ├─ 询问用户："拍时实际用的稿子和 scripts/<id>.md 一致吗？"
   │   ├─ 一致 → cp → videos/<id>/script.md，沿用 v1 预测
   │   ├─ 改了 → 要最终稿 → 算 diff
   │   │   ├─ diff ≥30% → 自动 /cheat-predict — mode: v2 → predictions/<id>.md append `## 预测 v2` 段
   │   │   └─ diff <30% → 询问是否 v2，默认沿用 v1
   │   └─ 大改 → 走 _redo 流程（新 scripts/<id>_redo.md + 重 cheat-predict）
   └─ buffer +1
  ↓
发布 → /cheat-publish + URL → buffer -1（仅 video；article / xhs 无 buffer，登记发布即可）
  ↓
T+3 天 → /cheat-retro videos/<日期>_<id>_<short>/（article / xhs 同理，产物目录换成 articles/ 或 xhs/）
   ├─ 抓数据 / 用户粘 → 写 videos/<id>/report.md
   ├─ 追加 ## 复盘 段到 predictions/<id>.md
   ├─ diff scripts/<id>.md vs videos/<id>/script.md → 学用户改稿 pattern
   └─ 把新观察写入 rubric-memo.md / script_patterns.md（实绩只进 rubric-memo，不进 rubric_notes）
  ↓
累计 ≥3 同向偏差 → /cheat-bump（升级 rubric）
```

---

## 公众号文章专用前置流程

当格式是 `article`，不要直接从「找资料」跳到「写正文」。先跑编辑准备度：

```
事实源核对
  ↓
如有对标文章 → layout-audit.md
  ↓
视觉方案 → visual/sources.md + visual/captions.md + cover-prompt.md
  ↓
HTML 版式方案 → 首屏 / H2 / 引用 / 图片节奏
  ↓
写 draft.wechat-article.md
  ↓
渲染正常 HTML + copy HTML
  ↓
用户确认后才发布草稿箱
```

硬性要求：
- 对标公众号只用于排版和表达拆解，不作为事实源；
- 封面是横版编辑封面，要有冲突、场景或数字，不做 UI 卡片；
- 截图要裁掉无用区域并放大重点；
- 图注写给读者看，不写素材备注；
- HTML 正文不是普通段落流，要有 H2、引用、图片、分割线等节奏点；
- 给用户复制前必须有 `draft.wechat-article-copy.html`。

完整规范见 `cheat-on-content/shared-references/wechat-editorial-workflow.md`。

---

## 小红书笔记专用流程

当格式是 `xhs`：

```
说 "AI 热点" / "今天 AI 圈有什么" → aihot 选题
  ↓
cheat-seed --format=xhs 写稿
  ↓
配图（自建配图 skill）
  ↓
/cheat-predict --format=xhs <稿子> → 写 immutable 预测到 predictions/
  ↓
排版 skill 格式化成小红书卡片
  ↓
发布（手动——小红书禁自动化）→ /cheat-publish + URL 登记
  ↓
T+3 天 → /cheat-retro xhs/<日期>_<id>_<short>/
```

无 buffer、无 shoot 环节；`--format=xhs` 贯穿 predict / publish / retro。

---

## 五个阶段对应触发词

### ① 选题阶段

| 想做什么 | 触发词 |
|---|---|
| 看 candidates.md 排序后的推荐 | "推荐选题" / "下一篇做什么" |
| 抓今天的热点拓展 candidates | "抓热点" / "今天有什么可做的" |
| 看当前状态 | "状态" |

> Cold-start 期没 candidates.md 是默认状态——不要因为这个就觉得工具坏了。

### ② 打分 + 预测

| 想做什么 | 触发词 | 写文件吗 |
|---|---|---|
| 看一份稿子的 rubric 分（探索） | "打分这篇 path/to/draft.md" | 否 |
| 给最终稿写正式 immutable 预测日志 | "启动预测" 或 "给这稿子启动预测 path/to/draft.md" | 是（`predictions/...md`） |

> **score 与 predict 的核心区别**：
> - score 是探索，无副作用，可反复跑
> - predict 是承诺，写完文件 `## 预测 v1`（或 `## 预测 v2`）段被 hook 锁死

> **v2 重判触发**：cheat-shoot 检测拍摄稿与原 scripts 的 line-diff ≥30% 时自动调用 cheat-predict 写 `## 预测 v2` 段（append，不覆盖 v1）。详见 [shared-references/prediction-anatomy.md](../shared-references/prediction-anatomy.md) 的 v1/v2 段约定。

### ③ 发布登记

发完后立刻：

```
"已发布 https://..."
```

或：

```
"已发布 predictions/2026-05-04_xxx.md 链接是 https://..."
```

会更新预测文件 header 的 `published_at` / `Platform` / `URL`，并把文件加入 `pending_retros` 队列。

### ④ 复盘

T+3 天后（默认）：

```
"复盘 predictions/2026-05-04_xxx.md"
```

或干脆：

```
"复盘"
```

后者会从 `pending_retros` 取最早的一条。

> 复盘需要你提供数据。默认是手动粘——粘该格式的主指标 + 互动指标（口径见 skill 包内 `shared-references/state-management.md` 的"实绩指标映射（按格式）"表）和 top 20 评论到对话里。
> 配了 adapter 的可以让 cheat-retro 自动抓。

### ⑤ Rubric 升级（罕见）

**满足条件才提议**：
- 校准池 ≥ 5 篇
- 上次 bump 后又有 ≥ 3 篇新校准
- 检测到连续 ≥ 3 次同向偏差

满足就跑：

```
"升级 rubric --propose 'ER 权重 1.5→2.0，加 MS 维度'"
```

bump 是高风险操作——会做 5 步验证（含跨模型独立审）。详见 `cheat-on-content/shared-references/bump-validation-protocol.md`。

---

## 三条不可妥协的原则

> 这三条违反任一条 → 整个校准循环退化为占星。

1. **盲预测**：预测段写在看到任何数据之前，写完不可改。hook 在 harness 层强制。
2. **升级 = 全量重打**：bump 必须校准池全量重打分 + 跨模型独立审。
3. **rubric 是工作台不是博物馆**：被吸收 / 被推翻的观察都删掉。git history 是档案。

---

## 默认配置

`/cheat-init` 创建的项目默认值：

| 设置 | 默认 | 何时改 |
|---|---|---|
| `RETRO_WINDOW_DAYS` | 3 | 长文 / 慢平台改 7 |
| `BLIND_CHECK` | strict | 演练 / 测试时临时改 lenient |
| `MIN_SAMPLES_FOR_BUMP` | 5 | 不要降 |
| `CROSS_MODEL_AUDIT` | true（如 mcp__llm-chat__chat 已配） | 仅离线时 false |
| `TREND_SOURCES` | ["manual-paste"] | 用 `enabled_trend_sources` 字段加新源 |
| `POOL_PATH` | candidates.md | 用 Notion 时改字段 |

---

## 看板（status 命令）

任何时候说 "状态"，会输出：
- 默认格式 + 各格式的 rubric 版本 / 校准样本数（按格式分列）
- 待办（pending retros + 同向偏差警告 + 陈旧 in-progress）
- 候选池规模 + 上次抓热点的天数
- 健康度（rubric_notes.md 行数 / hooks 是否安装 / 是否配跨模型审）
- 下一步建议（按推荐优先级）

---

## 文件结构（你的项目根）

```
<your-content-project>/
├── rubric_notes.md          # 评分规则真实来源
├── script_patterns.md       # 写作 pattern 沉淀
├── WORKFLOW.md              # 本文件
├── STATUS.md                # 看板（cheat-status 维护）
├── candidates.md            # 候选池（可选；cheat-seed / cheat-trends 写）
├── .cheat-state.json        # 状态文件（git track）
├── .cheat-cache/            # 本地缓存（gitignore）
│   ├── usage.jsonl
│   └── trends-history.jsonl
├── .cheat-secrets.json      # API key / cookie（gitignore）
├── .cheat-hooks/            # hook 脚本副本
│   ├── prediction-immutability.sh
│   ├── session-start.sh
│   └── log-event.sh
├── .claude/settings.json    # 含 cheat-on-content hooks
│
├── scripts/                 # **拍前的所有草稿**
│   └── YYYY-MM-DD_<id>_<short>.md   # cheat-seed 写或用户写
│
├── predictions/             # **immutable 预测日志**（hook 保护）
│   └── YYYY-MM-DD_<id>_<short>.md   # cheat-predict 写
│
├── videos/                  # **拍后才建**（cheat-shoot 创建，仅 video）
│   └── YYYY-MM-DD_<id>_<short>/
│       ├── script.md        # 你提供的最终拍摄稿
│       └── report.md        # T+3d 数据（cheat-retro 写）
│
├── articles/                # **公众号产物**（article 格式）
│   └── YYYY-MM-DD_<id>_<short>/
│       ├── draft.md         # 长文终稿
│       ├── visual/          # 自建配图 skill 产出
│       └── report.md        # T+3d 复盘数据（cheat-retro 写）
│
└── xhs/                     # **小红书产物**（xhs 格式）
    └── YYYY-MM-DD_<id>_<short>/
        ├── post.md          # 小红书图文终稿
        ├── images/          # 配图
        └── report.md        # T+3d 复盘数据（cheat-retro 写）
```

### 三个目录的关系

| 目录 | 阶段 | 内容 | 谁写 |
|---|---|---|---|
| `scripts/` | 拍前草稿 | Claude AI 草稿或用户原创 | cheat-seed 写初版；用户改写也在原文件 |
| `predictions/` | 预测锁定 | 7 组件 immutable 日志 | cheat-predict 写 |
| `videos/<id>/` | 拍后产物 | 最终拍摄稿 + T+3d 数据 | cheat-shoot 建目录；cheat-retro 写 report.md |
| `articles/<id>/` | 发布后产物 | 长文终稿 + 配图 + T+3d 数据 | 写稿 skill 建目录；配图 skill 写 visual/；cheat-retro 写 report.md |
| `xhs/<id>/` | 发布后产物 | 图文终稿 + 配图 + T+3d 数据 | 写稿 skill 建目录；cheat-retro 写 report.md |

三处用同一组 `<date>_<id>_<short>` 命名，`<id>` 是 `scripts/<id>.md` 首次落盘内容的 sha256 前 12 位，**草稿改写不变**。

`/cheat-init` 自动创建以上骨架（不覆盖已存在的）。

---

## 卡住了？

- 看 `cheat-on-content/SKILL.md` 的"必须拒绝的请求"段——你想做的事可能正好是被设计拒绝的
- 看对应子 skill 的 `cheat-on-content/skills/cheat-X/SKILL.md`
- 跑 "状态" 看 cheat-status 的"下一步建议"
