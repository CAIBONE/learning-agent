---
name: learning-reports
description: "Generate learning reports using Feishu Bitable dashboards and charts. Knowledge graph visualization, mastery progression, Gantt charts, weak point analysis. Dual output: Feishu dashboard + chat summary."
---

# Learning Reports — 学习报表与可视化

## 定位

使用飞书多维表格（Bitable）的图表功能生成可视化报表，替代纯 ASCII 可视化。
双输出模式：飞书 Dashboard（完整图表）+ 飞书消息（摘要文本）。

## 触发条件

- 周报 cron 触发（每周五 18:00）
- 月报 cron 触发（每月 1 号 10:00）
- 用户主动要求"查看报表"、"学习进度如何"
- 阶段测验完成后自动生成简要报告

## 数据源

**主数据源：飞书多维表格**（如已同步）
- 知识节点表 → 知识图谱可视化
- 学习记录表 → 学习时长统计
- 测验记录表 → 测验成绩趋势
- 掌握度追踪表 → 掌握度变化曲线
- 错题本表 → 薄弱点分析

**备选数据源：本地文件**（飞书未同步时降级）
- `data/<studentId>/mastery.json`
- `data/<studentId>/quiz-results.jsonl`
- `data/<studentId>/content-log.jsonl`
- `data/<studentId>/wrong-answers.jsonl`
- `data/<studentId>/plans/<subjectId>.yaml`
- `data/<studentId>/<subjectId>.yaml`

## 报表生成流程

### 第 1 步：读取数据

优先从飞书多维表格读取，失败则降级到本地文件。

### 第 2 步：确保可视化资源就绪

> 视图（view）和仪表盘（dashboard）在 `learning-feishu-sync` 初始化时创建。
> 本模块**不重复创建**，只负责引用和修复。

**2.1 检查可视化资源**

```
1. 读取 feishu-mapping.yaml → 检查 bitable.views 和 bitable.dashboards 字段
2. 若 views/dashboards 完整 → 跳到第 3 步（数据已自动驱动图表刷新）
3. 若缺失或部分为空 → 调用 learning-feishu-sync 的「缺失修复」流程补建
4. 补建完成后更新 mapping.yaml，继续第 3 步
```

**2.2 各报表类型对应的可视化资源**

| 报表内容 | 数据表视图 | 仪表盘图表组件 |
|---------|-----------|--------------|
| 知识图谱 | knowledgeNodes.kanban（看板）/ knowledgeNodes.heatmap（热力图） | 仪表盘「知识完成度」饼图 |
| 掌握度趋势 | masteryTracking.trend（趋势表） | 仪表盘「掌握度趋势」折线图 |
| 测验成绩 | quizRecords.list（测验列表） | 仪表盘「测验成绩趋势」柱线组合图 |
| 错题分布 | wrongAnswers.unmastered（未掌握错题） | 仪表盘「错题类型分布」饼图 |
| 学习时长 | learningSessions.duration（时长统计） | 仪表盘「学习时长趋势」柱状图 |

**2.3 资源 URL 拼装**

```
# 视图直链（用户可直接打开某个视图）
视图URL = {bitable.url}?table={table_id}&view={view_id}

# 仪表盘直链
仪表盘URL = {bitable.dashboards.learning.url}

# 示例
知识图谱看板 = https://xxx.feishu.cn/base/xxxxx?table=tblxxxx&view=vewxxxx
完整仪表盘 = https://xxx.feishu.cn/base/xxxxx?dashboard=dblxxxx
```

### 第 3 步：生成聊天摘要

飞书消息中发送精简版报表：

**周报摘要格式：**
```
📊 学习周报 — W24（6/9-6/15）

═══ 进度概览 ═══
完成率：12/20（60%）📈 +8% vs 上周
学习时长：8.5h（目标 10h，85%）
连续学习：12 天

═══ 掌握度 ═══
Python基础：85%  (+10%)
数据结构：62% 🟨 (+5%)
算法入门：25% 🟥 (新增)

═══ 测验 ═══
本周测验：3 次
平均正确率：78%
错题：8 道（概念不清 50% / 粗心 30% / 应用 20%）

═══ 薄弱点 Top 3 ══
1. 递归理解 — 35% — 连续 2 次测验未达标
2. 链表操作 — 42% — 应用题全错
3. 排序算法 — 55% — 概念混淆

═══ 下周建议 ═══
• 重点攻克：递归 + 链表（各增加 1 次专项练习）
• 暂停：算法入门（基础不牢，先巩固）
• 复习：排序算法（间隔复习到期）

📋 知识图谱看板：{knowledgeNodes.kanban URL}
📊 完整仪表盘：{dashboards.learning.url}
📈 掌握度趋势：{masteryTracking.trend URL}
```

### 第 4 步：保存和推送

```
1. 将完整报表写入飞书文档（复盘报表目录下）
2. 通过消息卡片推送：摘要文本 + 仪表盘直链按钮
3. 本地保存副本到 data/<studentId>/reports/<period>.md
4. 注意：多维表格图表由数据自动驱动刷新，无需手动更新
```

## 降级策略

当飞书多维表格不可用时：

1. **一级降级**：飞书文档可用 → 报表写入文档，聊天发送摘要
2. **二级降级**：飞书文档也不可用 → 本地保存 Markdown 报表，聊天发送精简版
3. **三级降级**：飞书完全不可用 → 本地保存，下次连通时补同步

## 多维表格视图配置

> 视图和仪表盘的创建/配置已移至 `learning-feishu-sync` 模块（第 4 步）。
> 本模块只负责引用，不重复定义。视图/仪表盘的 URL 从 `feishu-mapping.yaml` 的
> `bitable.views` 和 `bitable.dashboards` 字段读取。

## 报表类型与频率

| 报表 | 频率 | 内容 | 输出形式 |
|------|------|------|---------|
| 日报 | 每日 21:00 | 今日完成+明日预告 | 聊天消息 |
| 周报 | 每周五 18:00 | 完整进度+趋势+薄弱点+下周计划 | 飞书文档+多维表格图表+聊天摘要 |
| 月报 | 每月 1 号 10:00 | 月度复盘+目标达成+方法评估+下月规划 | 飞书文档+多维表格图表+聊天摘要 |
| 即时 | 测验后 | 测验结果+错题分析 | 聊天消息 |
| 知识图谱 | 按需 | 完整知识体系可视化 | 多维表格视图+聊天树形图 |

## 注意事项

- **图表无需手动刷新**：飞书多维表格的视图和仪表盘由数据驱动，记录变更时自动更新
- **多维表格有行数限制**：免费版纳 20,000 行/表，学习记录量大时注意清理旧数据
- **API 调用频率**：批量读取时使用批量接口，避免逐个请求
- **视图/仪表盘缺失**：报表生成前先检查 feishu-mapping.yaml，缺失时调用 learning-feishu-sync 补建
- **权限**：确保多维表格的查看权限设置正确（默认仅创建者可访问）