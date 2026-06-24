---
name: learning-quiz
description: "Generate quiz questions, dispatch to independent Audit Agent for quality check, assess knowledge mastery per node or timeframe. Interactive quiz delivery via chat, scoring, and mastery level updates."
---

# Learning Quiz — 测验与评估

## 触发条件

- 内容推送完成后
- 每日回顾 cron 触发
- 每周回顾 cron 触发
- 月度评估 cron 触发
- 用户主动要求"测验"或"考考我"

## 数据路径约定

- 知识树：`knowledge-trees/<studentId>/<subjectId>.yaml`
- 掌握度：`progress/<studentId>/mastery.json`
- 测验日志：`progress/<studentId>/quiz-results.jsonl`
- 错题本：`progress/<studentId>/wrong-answers.jsonl`
- 目标：`learning-profiles/<studentId>/goals.yaml`
- **对话笔记**：`progress/<studentId>/session-notes.yaml`

## 测验类型

| 类型 | 触发时机 | 题目数 | 目的 |
|------|---------|--------|------|
| 随堂测验 | 内容推送后 | 1-3 题 | 检测基本理解 |
| 每日回顾 | 每日 cron | 3-5 题 | 间隔重复，防遗忘 |
| 每周回顾 | 每周 cron | 5-10 题 | 综合复习本周内容 |
| 月度评估 | 每月 cron | 10-20 题 | 全面评估掌握度 |
| 自定义 | 用户要求 | 按需 | 针对性检测 |

## 测试题量评估规则（重要）

题量不是固定的，而是根据以下因素动态决定：

```
最终题量 = baseCount × difficultyMultiplier × importanceMultiplier × fatigueAdjustment
```

| 因子 | 取值规则 |
|------|---------|
| **baseCount** | 随堂=3 / 每日=5 / 每周=8 / 月度=15 / 阶段=20-30 / 考前=30-50 |
| **difficultyMultiplier** | 差距>2级=×1.5 / 1-2级=×1.0 / 0级=×0.7 / 超标=×0.5 |
| **importanceMultiplier** | 核心=×1.5 / 高频=×1.3 / 易错=×1.2 / 普通=×1.0 / 拓展=×0.7 |
| **fatigueAdjustment** | 当日>20题=×0.5 / 10-20题=×0.8 / <10题=×1.0 / 连对>90%=×0.7 / 连错>50%=×1.3 |

**题量上限**：单次 ≤ 50 题，每日 ≤ 40 题，随堂 ≤ 5 题

## 题目去重机制

```
1. 读取 quiz-results.jsonl，获取该节点已出过的题目
2. 生成新题目时，避免与历史题目重复
3. 同一节点的不同测验，题目重复率控制在 < 20%
4. 错题必须重复出，直到掌握度达标
```

**错题优先级**：下次复习到期的错题 → 必出 > 掌握度 < 60% 的错题 → 优先出 > 已掌握的不重复出

## 题目生成

### 题目类型比例

**有标准型（考试类）：**
- **选择题（60%）**：4 选 1，检测概念理解
- **判断题（20%）**：对/错，检测细节识别
- **简答题（10%）**：1-2 句话回答，检测解释能力
- **应用题（10%）**：解决实际问题，检测应用能力

**无标准型（技能类）：**
- **场景模拟题（40%）**：给一个实际场景，让用户选择/描述应对方式
- **操作题（25%）**：给一个任务，让用户描述操作步骤或写出代码/命令
- **概念解释题（20%）**：用自己的话解释核心概念
- **综合分析题（15%）**：综合分析题，检测深度理解

### 题目质量要求
1. 题干清晰无歧义
2. 选项互斥
3. 只有一个正确答案（选择题）
4. 难度与目标掌握度匹配
5. 覆盖该节点的关键概念
6. 避免纯记忆题，侧重理解和应用

### 生成流程

1. 读取知识树中目标节点的 description、level
2. **根据目标类型选择搜索策略**：
   - **有标准型**：搜索该节点的"考点"、"历年真题"、"公式定义"
   - **无标准型**：搜索该节点的"实际应用场景"、"常见错误"、"最佳实践"、"项目案例"
3. 根据掌握度选择题目难度
4. 读取 `session-notes.yaml`，检查是否有适用于当前节点的对话衍生需求（如用户要求多出应用题）
5. 生成题目（必须满足 session-notes 中的适用需求）

### 第 6 步：更新 session-notes

出题后，检查本轮交互中是否产生了需要持久化的信息：

```yaml
# 需要写入 session-notes 的场景：
# - 用户在答题过程中暴露了特定薄弱点（不在 mastery 数据中的）
# - 用户对某道题提出了异议且合理
# - 用户表达了偏好的题型或考察方式
```

> 格式见 `templates/session-notes-template.yaml`

### 第 7 步：派发 Audit Agent 审计

**将题目集派发给独立的 Audit Agent 进行审计。**

这是关键步骤——**自己出题不能自己审**。Audit Agent 在独立上下文中重新求解每道题，验证答案正确性。

**审计前告知用户**："开始审计，预计需要 5-10 分钟，请稍候"

调用方式（同步阻塞）：
```json
sessions_send({
  "agentId": "intelligent-learning-audit",
  "message": "审计类型: quiz\n目标: <nodeId>\n学生: <studentId>\n生成物:\n<完整题目集（含答案和解析）>",
  "timeoutSeconds": 600
})
```

派发内容：
```yaml
auditType: "quiz"
targetId: "<当前 nodeId>"
studentId: "<studentId>"
artifact: "<生成的完整题目集（含答案和解析）>"
```

**不传递**：出题推理过程、选题逻辑、对话历史。

审计结果处理：
- **verdict = "passed"** → 通知用户审计通过，进入交互答题流程
- **verdict = "passed_with_notes"** → 通知用户审计通过但附带建议，进入交互答题流程，附带 soft 建议标记
- **verdict = "not_passed" 且 retryCount < 3** → 通知用户"审计发现问题，正在修复中"，根据 fixAction 修复（仅 fixableByMain: true 的项），重新 sessions_send 审计
- **verdict = "user_arbitration"（重试 3 次后）** → 向用户展示完整审计反馈，等待裁决（接受/修改/重新生成/跳过）
- **超时或 Audit Agent 不可用** → 降级为本地审计，记录降级事件

**审计结果必须通知用户**（通过飞书消息），格式同 learning-content 的审计通知格式。

审计结果保存到 `data/<studentId>/audit/quiz-<nodeId>-<timestamp>.json`

## 交互答题流程

### 第 1 步：发送测验
通过飞书逐题发送：
```
测验时间！
科目：XXX
节点：YYY

Q1/5（选择题）：
题目内容...

A) 选项 A
B) 选项 B
C) 选项 C
D) 选项 D

请回复 A/B/C/D
```

### 第 2 步：接收答案
- 选择题/判断题：立即反馈对错+简短解释
- 简答题：根据关键词匹配判断
- 应用题：评估解题思路

### 第 3 步：评分
- <60% → mastery 2 | 60-79% → mastery 3 | 80-94% → mastery 4 | 95%+ → mastery 5

### 第 4 步：更新掌握度 + 记录测验结果

### 第 5 步：反馈给用户

## 自适应调整

- **mastery < 目标**：缩短回顾间隔（/2），插入补救 session
- **mastery >= 目标**：正常间隔，进入下一节点
- **连续 3 次不变**：更换教学方式，增加不同类型例子