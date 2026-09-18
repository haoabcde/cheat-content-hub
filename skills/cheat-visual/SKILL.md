---
name: cheat-visual
description: Research and capture source-backed visuals for chinese wechat public-account articles about ai, technology products, developer tools, model releases, technical debates, and hands-on product reviews. Use when the user asks to find illustrations, screenshots, x/twitter posts, official announcements, github issues, product pages, pricing pages, papers, community reactions, or evidence images for a tech article, especially when Playwright MCP or browser automation can open pages and take screenshots.
---

# /cheat-visual — 视觉证据研究

## Goal

Find and capture article-ready visual evidence for AI / technology WeChat public-account articles. Prioritize visuals that make the article feel researched, used, and grounded: official announcements, product UI, X/Twitter posts, GitHub issues, pricing pages, benchmark tables, paper figures, community reactions, and simple self-made explanation diagrams.

Do not merely find attractive images. Each visual must serve a narrative role in the article.

## Default assumptions

If the user does not specify otherwise:
- Input is a title, topic, outline, or draft article.
- Output should be a screenshot package, a visual-source report, reader-facing captions, and a contact sheet.
- Use Playwright MCP for browser opening, page inspection, and screenshots when available.
- Use X/Twitter mainly for first-person reactions, founder/researcher comments, and community sentiment; do not treat ordinary tweets as factual proof.
- Prefer recent sources for current product or AI news topics.

## Required workflow

0. **Load editorial workflow**
   Read `../../shared-references/wechat-editorial-workflow.md` when the output format is article or xhs. Apply its crop, caption, image density, and cover rules.
   写生图提示词时（封面 / 配图生成），规则以 wechat-cover skill 为唯一权威：先按 `.agents/skills/wechat-cover/SKILL.md` 的强制分流表定路线（真素材够不够），涉及生图再读 `.agents/skills/wechat-cover/references/prompt-workflow.md`（五原则 + 大字排版细节 + 模板）。**不再默认走大字氛围图，也不预设场景隐喻**——风格按「情绪 -> 风格」映射确定。

1. **Parse article intent**
   - Identify the article type: product release, hands-on review, technical explainer, controversy, company/person update, tool recommendation, or pitfall guide.
   - Extract 3-6 core claims or narrative beats that need visual support.

2. **Plan visual roles**
   Use the visual roles in `references/visual-roles.md`. Aim for a balanced set:
   - at least one anchor visual from an official or primary source;
   - at least one friction visual showing limitation, bug, user complaint, pricing wall, issue, or failed workflow;
   - at least one explanation or comparison visual when the article explains a mechanism.
   - for long WeChat articles, plan enough visual pauses: usually 6-8 images for 2500-4500 Chinese characters.

3. **Search by source priority**
   Follow `references/source-priority.md`:
   - P0: official blogs, docs, release notes, product pages, papers, model cards, GitHub releases;
   - P1: X/Twitter posts by official accounts, founders, researchers, core developers;
   - P2: GitHub issues, Hacker News, Reddit, high-quality developer discussions;
   - P3: reputable media;
   - P4: ordinary user posts, used only as sentiment or anecdotal evidence.

4. **Validate screenshot candidates**
   Score each candidate with `references/screenshot-rubric.md`. Reject visuals that are decorative, misleading, stale, unsourced, or not directly tied to an article claim.

5. **Capture screenshots with Playwright MCP**
   When browser automation is available:
   - Open the original URL, not a repost or image mirror.
   - Dismiss cookie banners, login popups, or overlays only when doing so does not alter the content being cited.
   - Capture the smallest useful region that preserves source context, then crop away browser chrome, empty sidebars, repeated navigation, unrelated comments, and blank space.
   - Enlarge the key claim, table row, chart area, or post body so it remains readable on mobile.
   - For X/Twitter posts, preserve author display name, handle, post body, date/time when visible, and media if central.
   - For official pages, preserve page title, source brand, key claim, and URL context when possible.
   - For GitHub issues/PRs, preserve repository name, issue title/number, author or status when visible, and the relevant comment/body.
   - For tables/benchmarks/pricing, preserve column headers and row labels.
   - Save files using the naming rules in `references/output-template.md`.
   - Do not create decorative UI cards around screenshots. The screenshot itself should be the evidence.

6. **Generate the visual-source report**
   Use the report structure in `references/output-template.md`. Include:
   - screenshot filename;
   - original URL;
   - source type and priority;
   - article placement;
   - visual role;
   - what to crop/capture;
   - what claim it supports;
   - suggested reader-facing caption in Chinese;
   - risk note.
   Also create a contact sheet when images were saved, so the user can review the whole visual rhythm at once.

7. **If screenshots cannot be completed**
   Return the candidate list and precise Playwright/browser instructions instead of pretending screenshots were taken. State which URLs failed and why: login wall, unavailable page, dynamic rendering problem, paywall, rate limit, or tool not available.

## X/Twitter search strategy

Use X/Twitter for live reactions and original remarks. Search patterns:

- official account + product name + release keyword;
- founder/researcher/core developer handle + product keyword;
- product keyword + "bug", "broken", "not working", "failed", "pricing", "rate limit";
- product keyword + "insane", "wild", "finally", "disappointed", "why";
- exact feature name + since date if the event is recent.

Classify every X/Twitter screenshot as one of:
- official announcement;
- founder/researcher viewpoint;
- developer reaction;
- user complaint;
- community sentiment;
- controversy material.

Never present an ordinary user post as conclusive evidence. Phrase it as: "这只能说明有人遇到了类似体验，不等于事实结论。"

## Screenshot quality rules

A good screenshot must have at least two of these:
- clear source identity;
- timestamp or version context;
- visible claim, UI state, limitation, table, or error;
- direct connection to one article paragraph;
- enough surrounding context to avoid misquotation.
- cropped tightly enough that a phone reader can understand it without zooming.

Avoid:
- cropped quotes without speaker/source;
- low-resolution images;
- reposted screenshots of screenshots;
- generic stock images;
- screenshots that only say what the article already says;
- community drama with no explanatory value.
- UI-card wrappers made by the agent instead of real evidence.

## Output language and style

Return the final report in Chinese. Use practical editorial language suitable for a tech WeChat creator: direct, concrete, and skeptical. Do not use corporate filler such as "赋能", "深度剖析", "未来已来", or "重塑格局".

## Output deliverables

When screenshots are successfully created, provide:
- a list of generated image files or paths;
- a visual-source report;
- suggested article placement and reader-facing captions;
- a contact sheet path when possible;
- risk notes and attribution reminders.

## 输出路径

根据当前格式，输出到不同的产物目录：

| 格式 | 输出路径 |
|---|---|
| article | `articles/<DATE>_<ID>_<SHORT>/visual/` |
| xhs | `xhs/<DATE>_<ID>_<SHORT>/images/` |
| video | 不适用（视频不需要配图研究）|

> 路径相对**当前内容通道目录**（含 `.cheat-state.json` 的目录）。若工作目录是仓库根、通道在 `examples/<name>/`（多通道布局），先按 `hooks/session-start.sh` 的 channel discovery 定位通道目录，产物写到通道目录下，不要写到仓库根（根级 `articles/` 被 gitignore 排除，写入即丢失）。

> 格式检测与 cheat-score 相同。如果格式是 video，提示"视频格式不需要配图研究"。

When working in an environment that supports file output, create a folder like:

```text
visual-research-output/
├── images/
├── sources.md
├── captions.md
└── risk-notes.md
```
