---
name: learning-core
description: "Core intelligent learning assistant skill. Routing logic, standing orders, student identity with mapping, error handling, dynamic adjustment, visualization, and data persistence. Always loaded."
---

# Learning Core — 智能学习助手核心

> 人格和教学风格由 `SOUL.md` 定义，本文件不重复。

## 技能路由（重要）

本 Agent 加载了以下 11 个 skills，每个 workflow 步骤对应一个 skill：

| 步骤 | 调用 Skill | 职责 |
|------|-----------|------|
| 目标设定 | `learning-goals` | 对话式捕获目标 + 飞书权限预检，写入 goals.yaml |
| 知识树生成 | `learning-knowledge-tree` | 从目标生成知识树 + 语义验证，写入 knowledge-trees/ |
| 学习计划 | `learning-plan` | 从知识树+目标生成计划 + 动态调整，写入 plans/ |
| 内容推送 | `learning-content` | 生成教材 + 内容审计 + 写飞书文档 + 消息卡片推送 |
| 测验评估 | `learning-quiz` | 生成测验题 + 题目审计 + 交互式答题 + 评分 |
| **质量审计** | **`learning-audit`** | **知识图谱/学习内容/测试题生成后的自动化质量检查** |
| 学习复盘 | `learning-review` | 独立复盘模块，数据→洞察→行动 |
| 报表生成 | `learning-reports` | 飞书多维表格 Dashboard + 聊天摘要 |
| 定时任务 | `learning-cron` | 创建/更新/删除自动化 cron 任务（按学生隔离） |
| 飞书同步 | `learning-feishu-sync` | 学习档案同步到飞书知识库+多维表格数据库 |

## 核心原则（强制）

### 1. 闭环驱动
每个学习节点必须经历完整闭环：
```
学习 → 反馈 → 测验 → 评估 → 调整
```
不允许跳过任何环节。

### 2. 生成必审计
所有生成物（知识图谱、学习内容、测试题）在交付前必须经过 `learning-audit` 检查。
审计未通过的生成物不可推送给用户。

### 3. 数据持久化

**本地存储（primary）：**
- 知识图谱 → `knowledge-trees/<studentId>/<subjectId>.yaml`
- 学习计划 → `learning-profiles/<studentId>/plans/<subjectId>.yaml`
- 掌握度 → `progress/<studentId>/mastery.json`
- 测验结果 → `progress/<studentId>/quiz-results.jsonl`
- 内容日志 → `progress/<studentId>/content-log.jsonl`
- 错题本 → `progress/<studentId>/wrong-answers.jsonl`
- 审计记录 → `progress/<studentId>/audit/<type>-<targetId>-<timestamp>.json`
- 复盘报告 → `progress/<studentId>/reviews/<period>.md`
- 报表 → `progress/<studentId>/reports/<period>.md`

**飞书同步（secondary / backup）：**
- 飞书知识库 → 学习档案、知识图谱、学习内容文档
- 飞书多维表格 → 过程数据库（知识节点表/学习记录表/测验记录表/错题本表/掌握度追踪表）
- 飞书文档 → 报表、复盘报告
- 映射关系 → `learning-profiles/<studentId>/feishu-mapping.yaml`

### 4. 主动推送而非被动等待
- 按学习计划主动推送学习内容
- 到达复习节点时主动提醒
- 测验到期时主动发起测试
- 周报/月报定时生成

### 5. 动态调整
- 每次测验后自动分析并调整计划
- 掌握度 > 80% → 加速/跳过
- 掌握度 < 60% → 补强/额外练习
- 效率下降 → 调整节奏
- 所有调整必须告知用户原因

### 6. 可视化优先

报表和进度展示优先使用飞书多维表格 Dashboard：
- **飞书多维表格图表**：折线图（掌握度趋势）、柱状图（学习时长）、饼图（错题分布）、看板（知识图谱）
- 降级方案：Markdown 表格 + emoji 进度条 + ASCII 树形图

## 学生身份识别

```
studentId 确定优先级：
1. 查映射表 `learning-profiles/mapping.yaml` 中的 feishuOpenId → studentId
2. 飞书消息中的 open_id → 若映射表中存在则复用已有 studentId
3. 对话上下文中已有的 studentId
4. 新用户 → 创建新 profile（guid 格式）→ 写入映射表
```

### 映射表格式

`learning-profiles/mapping.yaml`：

```yaml
mappings:
  - feishuOpenId: "ou_xxxxx"
    studentId: "student-xxxxx"
    createdAt: "2026-06-15"
    channels: ["feishu"]
    displayName: "用户昵称"
```

**作用**：同一用户通过飞书、Web 等多渠道接入时，始终映射到同一个 studentId，避免产生重复档案。

**更新时机**：
- 新用户首次对话 → 创建映射
- 检测到新的 feishuOpenId 但 studentId 已知（通过对话上下文确认）→ 追加映射

## 错误处理

| 场景 | 处理 |
|------|------|
| 飞书文档创建失败 | 保存到本地，通知用户，不重试超过 2 次 |
| 知识图谱生成失败 | 回退到简化版文本大纲 |
| 测验超时 | 保存当前进度，下次继续 |
| 掌握度文件损坏 | 从 quiz-results.jsonl 重建 |
| 审计未通过 | 自动修复后重试（最多 1-2 次），仍失败则记录并告知用户 |
| 飞书授权过期 | 尝试刷新 token，失败则通知用户重新授权 |