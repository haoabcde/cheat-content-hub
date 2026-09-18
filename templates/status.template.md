# 状态

> 本文件由 `/cheat-status` 维护——每次跑 status 都会更新。手改无意义。

---

**最近更新**: [INIT-DATE]
**📦 默认格式**: video
**📈 校准样本**: 0 | **Confidence**: 🔴 极低（占星级别，纯纪律训练）
**📅 上次抓热点**: [从未 / N 天前]

---

## 分格式总览

| 格式 | rubric 版本 | 校准样本 | 待复盘 |
|---|---|---|---|
| 🎬 视频 | v0 | 0 | 0 |
| 📝 公众号 | v0 | 0 | 0 |
| 📱 小红书 | v0 | 0 | 0 |

Confidence 按默认格式（video）的校准样本派生，换算表见 skill 包内 `shared-references/state-management.md` 的"Confidence label 派生表"。

---

## 🎬 视频（video）

- **当前 rubric**: v0
- **校准样本**: 0 / 5（解锁第一次 bump 的门槛）
- **Buffer**: 0 篇（颜色按 `target_publish_cadence_days` 派生；仅 video 使用拍摄队列，article / xhs 无 buffer）

## 📝 公众号（article）

- **当前 rubric**: v0
- **校准样本**: 0 / 5
- **断更兜底**: 距上次发布 [从未 / N 天]——超过 `target_publish_cadence_days × 2` 未发会提示断更风险

## 📱 小红书（xhs）

- **当前 rubric**: v0
- **校准样本**: 0 / 5
- **断更兜底**: 距上次发布 [从未 / N 天]——超过 `target_publish_cadence_days × 2` 未发会提示断更风险

---

## 进度条

```
[░░░░░░░░░░░░░░░░░░░░] 0 / 30 → SQLite 升级建议门槛
[░░░░░░░░░░░░░░░░░░░░] 0 / 5  → 脱离 cold-start 门槛
```

## 🎬 待办

无——你刚初始化，先写第一篇稿子吧。

## 🔥 候选池

无（cold-start 期默认状态）。
- 想试试热点抓取 → 说 `抓热点`
- 想手动建池 → 编辑 `candidates.md`

## 📈 健康度

- `rubric_notes.md`: [X 行]（健康，<600 警戒线）
- `hooks_installed`: [✅ / ❌]
- external audit configured: [✅ / ❌]

## 下一步建议

1. **写一份稿子**（默认格式对应的内容形态即可）
2. 跑 `打分这篇 path/to/draft.md` 看 rubric 给的初始评分
3. 准备发布前跑 `启动预测`
4. 发布后说 `已发布 https://...`
5. T+3 天跑 `复盘 predictions/<file>.md`

第 5 篇之后会解锁 `/cheat-bump`，rubric 才真正开始校准。

完整工作流见 `WORKFLOW.md`。
