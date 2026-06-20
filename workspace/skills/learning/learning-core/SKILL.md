---
name: learning-core
description: "Core intelligent learning assistant skill. Routing logic, multi-agent architecture, session notes mechanism, student identity with mapping, error handling, dynamic adjustment, visualization, and data persistence. Always loaded."
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
| 内容推送 | `learning-content` | 生成教材 + 写飞书文档 + 消息卡片推送 |
| 测验评估 | `learning-quiz` | 生成测验题 + 交互式答题 + 评分 |
| **质量审计** | **`learning-audit`** ⚡独立 Agent | **知识图谱/学习内容/测试题的自动化质量检查（独立上下文）** |
| 学习复盘 | `learning-review` | 独立复盘模块，数据→洞察→行动 |
| 报表生成 | `learning-reports` | 飞书多维表格 Dashboard + 聊天摘要 |
| 定时任务 | `learning-cron` | 创建/更新/删除自动化 cron 任务（按学生隔离） |
| 飞书同步 | `learning-feishu-sync` | 学习档案同步到飞书知识库+多维表格数据库 |

## 多 Agent 架构

### 架构总览

```
┌─────────────────────────────────────────────────┐
│              学吧 Main Agent                      │
│  上下文：SOUL + 路由 + 对话历史 + 学生档案          │
│                                                   │
│  内置 Skill：goals / knowledge-tree / plan /      │
│              content / quiz / review / reports /   │
│              cron / feishu-sync                    │
│                                                   │
│  生成完成 → 写 session-notes → 派发审计 Agent       │
└──────────────────────┬──────────────────────────┘
                       │
                       ▼
         ┌──────────────────────────┐
         │   Audit Agent（独立上下文）│
         │   技能：learning-audit    │
         │                          │
         │   数据源：                │
         │   • 生成物本身            │
         │   • 学生数据文件（自读）   │
         │   • session-notes.yaml   │
         │   • audit SKILL 检查清单  │
         └──────────────────────────┘
```

### 为什么要拆出审计 Agent

**核心原因：既当运动员又当裁判会出问题。**

- `learning-content` 生成教材后，同一个上下文里做审计 → 模型倾向于认同自己的生成逻辑，难以客观发现问题
- `learning-quiz` 出题后自己审答案 → "自己出题自己错"问题
- `learning-knowledge-tree` 生成知识树后自己验证 → 同样的推理偏差会重复

**审计 Agent 在独立上下文中运行**，看不到 Main Agent 的生成过程和推理，只看到：
1. 最终生成物（内容/题目/知识树）
2. 审计标准（audit SKILL 的检查清单）
3. 学生数据文件（自己读）
4. session-notes.yaml（对话中产生的关键信息）

### 审计 Agent 派发协议

Main Agent 在生成物完成后，调用 Audit Agent 时传递以下信息：

```yaml
# 派发给 Audit Agent 的参数
auditType: "content"              # content | quiz | knowledge_tree
targetId: "mod-01-02"
studentId: "<studentId>"
artifact: "<生成物内容>"           # 最终的内容/题目/知识树 YAML

# Main Agent 不需要组装 dataDerived 或 requirements
# Audit Agent 自己读取以下文件：
# - progress/<studentId>/session-notes.yaml
# - progress/<studentId>/mastery.json
# - progress/<studentId>/content-log.jsonl
# - progress/<studentId>/quiz-results.jsonl
# - knowledge-trees/<studentId>/<subjectId>.yaml
# - learning-profiles/<studentId>/plans/<subjectId>.yaml
# - learning-profiles/<studentId>/goals.yaml
```

**派发原则：**
- Main Agent **只传生成物本身**，不传生成过程的推理
- Audit Agent **自主读取**所需的数据文件和 session-notes
- 避免"喂结论"，让审计 Agent 独立判断

## Session Notes 机制

### 为什么需要 Session Notes

有些信息只存在于对话中，没有持久化到任何数据文件：

- 用户说"上次那篇太理论了，要更多实操案例" → 不在 mastery.json 里
- 用户纠正了一个概念错误 → 不在 quiz-results.jsonl 里
- 用户说"下周出差，这周多学点" → 不在 plans.yaml 里

这些信息对审计 Agent 至关重要（否则无法验证"内容是否按用户要求增加了实操案例"），但 Main Agent 拆出审计 Agent 后，对话上下文不再共享。

**Session Notes 就是对话上下文的持久化桥梁。**

### 文件格式

> 模板见 `templates/session-notes-template.yaml`

路径：`progress/<studentId>/session-notes.yaml`

### 写入时机

以下场景**必须**写入 session-notes：

| 场景 | type | 示例 |
|------|------|------|
| 用户表达对内容/方式的偏好 | `user_feedback` | "多用电商场景举例" |
| 用户或 Main Agent 发现之前的内容有误 | `correction` | "二叉树遍历的解释有误，正确的是..." |
| 用户提出计划/范围调整 | `requirement_change` | "跳过第 5 章，已经会了" |
| 对话中观察到学习状态变化 | `learning_state` | "用户对递归概念感到困惑" |
| 影响后续策略的上下文 | `context` | "下周出差，本周加量" |

### 写入规则

- **只记结论，不记推理**：记录"用户要求多用电商例子"，不记录"Main Agent 认为应该增加电商案例因为..."
- **及时写入**：每次用户对话产生上述信息时立即写入，不要等到最后
- **标注适用范围**：`appliesTo: "all"` 或具体 nodeId
- **清理机制**：`resolved: true` 的条目保留 7 天后清理，总条目上限 20 条

### 消费方

| 消费方 | 用途 |
|--------|------|
| **Audit Agent** | 审计时检查生成物是否满足了 session-notes 中的要求 |
| **Main Agent（下次会话）** | 恢复对话上下文，延续上次的个性化策略 |

## 核心原则（强制）

### 1. 闭环驱动
每个学习节点必须经历完整闭环：
```
学习 → 反馈 → 测验 → 评估 → 调整
```
不允许跳过任何环节。

### 2. 生成必审计
所有生成物（知识图谱、学习内容、测试题）在交付前必须经过 **Audit Agent** 检查。
审计未通过的生成物不可推送给用户。

### 3. 数据持久化

**本地存储（primary）：**
- 知识图谱 → `knowledge-trees/<studentId>/<subjectId>.yaml`
- 学习计划 → `learning-profiles/<studentId>/plans/<subjectId>.yaml`
- 掌握度 → `progress/<studentId>/mastery.json`
- 测验结果 → `progress/<studentId>/quiz-results.jsonl`
- 内容日志 → `progress/<studentId>/content-log.jsonl`
- 错题本 → `progress/<studentId>/wrong-answers.jsonl`
- **对话笔记** → `progress/<studentId>/session-notes.yaml`
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
| 审计 hard 指标不通过 | Main Agent 按 fixAction 修复 → 重新派发审计（最多 3 次） |
| 审计 3 次重试后仍不通过 | **提交用户裁决**：展示审计反馈 + 未通过项 + 已尝试修复，用户选择接受/修改/重新生成/跳过 |
| 审计 soft 指标不通过 | 可带标记推送，标记中说明具体问题 |
| 审计 Agent 调用失败 | 降级为本地审计（在同一上下文中执行 audit 检查），记录降级事件 |
| 审计导致推送延迟 > 15 分钟 | 推送时附带延迟提示 |
| 飞书授权过期 | 尝试刷新 token，失败则通知用户重新授权 |

### 用户裁决流程（审计 3 次重试后）

```
1. Main Agent 向用户展示：
   - 生成物内容（或摘要）
   - 审计未通过的检查项原文（issue + fixAction）
   - Main Agent 已尝试的修复

2. 用户选择：
   a) "可以接受" → 带标记推送（soft）或直接推送（用户覆盖审计判断）
   b) "按审计建议修改" → Main Agent 按 fixAction 修改，不再审计，直接推送
   c) "重新生成" → Main Agent 从头重新生成，重新走审计流程
   d) "跳过本次" → 不推送，记录跳过原因到 session-notes，下次补推
```