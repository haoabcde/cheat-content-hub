# Cheat Content Hub

**把每一条内容变成可校准的实验——视频、公众号、小红书三格式通用。**

大部分创作者活在同一个赌局里：发布 → 数据出来 → 学不到东西 → 下一次继续赌。跑过 200 条的博主跟跑过 1 条的差距不到 10%，因为他们没在每次赌局后**记账**。

Cheat Content Hub 是一个 Claude Code / Codex skill 套件，让每一次判断都被记录、被复盘、被吸收进下一次：

📊 打分 → 🎯 盲预测 → 🚀 发布 → 📈 T+3 天复盘 → 🧬 进化你的评分公式

跑一个月 = 你有了一份**只属于你的爆款公式**。跑三个月 = 你比刚开始的自己强 10 倍。

它是 [XBuilderLAB/cheat-on-content](https://github.com/XBuilderLAB/cheat-on-content) 的多格式扩展版：官方版聚焦视频，本版把**公众号长文**和**小红书图文**做成一等公民，并补上了写稿 → 排版 → 配图的完整创作链。

---

## 三种内容格式

| 格式 | 标识 | 产物目录 | 内置 rubric | 数据平台 |
|---|---|---|---|---|
| 视频 | `video` | `videos/` | 观点视频（参考博主 25+ 样本拟合） | 抖音 / B 站 / LinkedIn / 视频号 |
| 公众号长文 | `article` | `articles/` | 公众号文章（含 cold-start zero 版） | 微信公众号后台 |
| 小红书图文 | `xhs` | `xhs/` | 小红书笔记（含 cold-start zero 版） | 小红书创作者中心 |

每种格式独立追踪 rubric 版本、校准样本数、待复盘队列（schema 1.5 的 `formats.<format>` 命名空间），rubric 各自进化互不干扰。校准池按格式过滤，跨格式的数据永远不进同一次验证。

## 工作流闭环

**选题** → **调研** → **写稿** → **打分** → **盲预测** → **发布** → **复盘** → **升级 rubric**

| 阶段 | video | article | xhs |
|---|---|---|---|
| 选题 | cheat-seed + cheat-trends | cheat-seed + aihot | cheat-seed + aihot |
| 写稿 | 自己写脚本 | 按模板 + 编辑工作流 | cheat-seed 短版 |
| 配图/排版 | — | 自建（[引导流程](shared-references/custom-format-skills.md)） | 自建（同左） |
| 打分预测 | cheat-score + cheat-predict | 同左（article rubric） | 同左（xhs rubric） |
| 发布登记 | cheat-shoot → cheat-publish | cheat-publish | cheat-publish |
| 复盘 | cheat-retro（T+3d） | cheat-retro（T+7d） | cheat-retro（T+3d） |

### 三条不可妥协的原则

1. **盲预测**：预测必须在看到任何实际数据**之前**写完。写完即 immutable——hook 在工具层物理强制，不是君子协定
2. **升级 = 全量重打**：rubric 升级时，同格式校准池全部用新公式重打分；新排序与实绩排序 ≥4/5 不一致则拒绝升级；必须经跨模型独立审核
3. **rubric 是工作台不是博物馆**：被推翻或被吸收的观察**删掉**，不留考古层

### 打分通道隔离（3-channel 模型）

- **A** = 主对话：决策、写复盘、交互
- **B** = blind sub-agent：上下文隔离打分，硬拒绝读任何实绩数据
- **C** = 跨模型 audit：bump 终局由外部 LLM 独立 sanity check

### 内容守护 hook（article/xhs）

content-guard 在 Write 之前强制：项目已 init → 草稿必须带模板 metadata 头 → AI/科技资讯内容必须先走 aihot 拿数据（不允许用训练数据当新闻写）。

## 安装

```bash
git clone https://github.com/haoabcde/cheat-content-hub.git
cd cheat-content-hub
bash install.sh          # symlink 18 个子 skill 到 Claude Code 和/或 Codex
```

然后在你的内容项目目录里对 Claude 说：**「初始化」**（等价于 `/cheat-init`）。init 会问你主攻格式（video / article / xhs）、创建目录结构、装 hook、写 state。

常用触发词（自然语言即可）：

| 说 | 做什么 |
|---|---|
| 「抓热点」 | 拉取热点进选题池（aihot / 微博 / 知乎） |
| 「打分这篇 xxx」 | 按当前格式 rubric 给草稿打分 |
| 「启动预测」 | 写 immutable 盲预测日志 |
| 「已发布 [链接]」 | 登记发布，进入待复盘队列 |
| 「复盘」 | 实绩对账，沉淀观察到 rubric-memo |
| 「升级 rubric」 | 5 步验证的公式进化（含跨模型审核） |
| 「状态」 | 看板：rubric 版本 / 校准样本 / 待复盘 / 候选池 |

## 数据来源 adapters

`adapters/perf-data/` 下是各平台的数据抓取器（Playwright 登录态只读自己的创作者后台，不抓公开内容、不自动发布）：

- **douyin-session**（抖音）、**bilibili-stat**（B 站）、**linkedin-session**、**wechat-channels**（视频号，⚠️ 上游作者声明未做真机验证）、**xhs-explore**（小红书，含公开页兜底/归档/账号汇总）
- `adapters/trend-sources/`：aihot（AI 资讯）、微博热搜、知乎热榜
- `adapters/script-extraction/whisper/`：视频文案提取

公众号文章没有官方数据 API，复盘走手动粘贴（阅读/在看/点赞）或截图转录。

## 与官方版的关系

本仓库基于 [XBuilderLAB/cheat-on-content](https://github.com/XBuilderLAB/cheat-on-content) 扩展，官方代码基线持续同步合并。主要差异：

- 多格式路由与 schema 1.5（`default_format` + `formats.<format>` 命名空间）
- 公众号 / 小红书 rubric、模板与编辑工作流
- aihot（AI 热点）等创作链 skill；配图/排版刻意留白——发截图或描述即可走[引导流程](shared-references/custom-format-skills.md)自建
- content-guard 内容守护 hook
- 更完整的迁移系统与回归测试（state 迁移 / hook / 工作流审计）

## License

MIT
