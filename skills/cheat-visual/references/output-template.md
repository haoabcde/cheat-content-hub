# Output Template

## Folder structure

Use this default structure when file output is possible:

```text
visual-research-output/
├── images/
│   ├── 01-anchor-official-[slug].png
│   ├── 02-friction-x-[slug].png
│   └── 03-explainer-[slug].png
├── sources.md
├── captions.md
├── risk-notes.md
└── contact-sheet.jpg
```

## File naming

Use lowercase English slugs.

Pattern:

```text
[number]-[role]-[source]-[short-topic].png
```

Examples:

```text
01-anchor-official-openai-release.png
02-friction-x-agent-complaint.png
03-friction-github-timeout-issue.png
04-comparison-pricing-table.png
05-explainer-mcp-flow.png
```

## Final report structure

```markdown
# 配图与截图报告

## 文章主题
[topic]

## 截图文件
- images/01-anchor-official-xxx.png
- images/02-friction-x-xxx.png

## 推荐配图总览

| 序号 | 文件名 | 放置位置 | 角色 | 来源优先级 | 支撑观点 | 风险 |
|---|---|---|---|---|---|---|
| 1 | ... | 开头/第二段 | 锚点图 | P0 | ... | 低 |

## 版式节奏

- 正文预估字数：...
- 推荐图片数：...
- 第一张图放置：...
- 图片之间的最大文字间隔：...
- 封面图方向：...

## 单图说明

### 图 1：[filename]

- 原始链接：...
- 来源类型：官方公告 / X / GitHub / 论文 / 产品页 / 社区讨论
- 来源优先级：P0/P1/P2/P3/P4
- 适合放在：...
- 截图内容：...
- 裁切要求：裁掉哪些无关区域，重点放大到什么位置
- 支撑观点：...
- 中文配文建议：...
- 风险提示：...
- 替代来源：...
```

## Caption style

Captions should be direct and concrete.

Good:
- "官方文档里已经把这个限制写得很清楚，只是很多人试用前不会看。"
- "这类吐槽只能说明一部分用户踩过坑，不能当成产品整体结论。"
- "价格页比发布会更诚实。真正影响普通用户的，往往就藏在这里。"
- "先看虚线，100 万美元起跑线。下面掉到底的曲线，就是破产。"

Avoid:
- "该功能展现出强大的赋能潜力。"
- "这一变化将重塑行业格局。"
- "来源截图。"
- "如图所示。"
