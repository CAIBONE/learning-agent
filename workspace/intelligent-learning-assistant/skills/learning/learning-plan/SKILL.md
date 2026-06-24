---
name: learning-plan
description: "Generate and dynamically adjust learning plans from knowledge trees and goals. Supports interval scheduling, cron management, quantitative adjustment algorithms, and plan YAML schema."
---

# Learning Plan — 学习计划管理（含动态调整）

## 触发条件

- 知识树确认后
- 用户要求生成学习计划
- 自适应调整触发（测验后重新排程）
- 用户反馈学习难度变化

## 数据路径约定

- 知识树：`knowledge-trees/<studentId>/<subjectId>.yaml`
- 目标：`learning-profiles/<studentId>/goals.yaml`
- 计划输出：`learning-profiles/<studentId>/plans/<subjectId>.yaml`
- 计划 Schema 示例：`templates/plan-schema.yaml`
- 掌握度：`progress/<studentId>/mastery.json`

---

## 计划文件 YAML Schema

> 完整示例见 `templates/plan-schema.yaml`，以下为关键字段说明。

```yaml
# 顶层字段
subjectId, studentId, version, generatedAt, updatedAt, goalId, knowledgeTreeRef

# schedule — 总体设置
schedule:
  dailyMinutes: 60          # 每日学习时长（分钟）
  weekendMinutes: 90        # 周末学习时长
  pushTime: "09:00"         # 推送时间
  reviewTime: "20:00"       # 复习提醒时间
  bufferRatio: 0.2          # 缓冲时间比例（20%）
  startDate, deadline, workdayPattern, weekendPattern

# sessions — 学习会话列表（每个节点一个 learn + 多个 review）
sessions:
  - sessionId, nodeId, nodeTitle, type(learn/review/quiz/milestone)
    scheduledDate, scheduledTime, estimatedMinutes
    status(scheduled/delivered/completed/skipped/overdue)
    priority, prerequisites, reviewCount
    completedAt, actualMinutes, selfRating, notes

# milestones — 里程碑
milestones:
  - milestoneId, name, afterSessionId, type(quiz/assessment/checkpoint)

# adjustments — 调整日志
adjustments:
  - adjustmentId, date, reason, triggerType, changes[], newDeadline, notifiedAt
```

---

## 计划生成流程

### 0. 工时估算（先于排程）

**核心原则：先估工作量，再映射到日历。不基于 deadline 反推填充。**

```
总工时 = Σ(各节点 estimatedMinutes)

# 基础折减（从 goals.yaml 读取 baseline）
if baseline 显示有相关基础:
  总工时 ×= 折减系数（0.3-0.6，见 learning-goals 排程约束）

实际日历天数 = 总工时 / 每日平均学习时长（分钟）

# 上限保护：不超过 deadline
if startDate + 实际日历天数 > deadline:
  压缩每日时长或调整内容深度，使总时长 ≤ deadline

# 下限提醒：如果实际远短于 deadline
if 实际日历天数 < (deadline - startDate) × 0.3:
  主动告知用户：
  「按你的基础和每日学习时长，核心内容约 X 周可完成。
   剩余时间可以：① 增加进阶内容 ② 做更深入的实战项目 ③ 提前完成后自由安排」
  → 在计划中标注 recommendedDeadline（基于工时的实际完成日）
  → 不人为拉长里程碑间隔来填满 deadline
```

### 1. 路径排序

- 基于知识树的前置依赖关系确定学习顺序（拓扑排序）
- 同级知识点按难度递增排列
- 相关知识点相邻安排（促进关联学习）

### 2. 时间分配

**可用天数计算：**
```
availableDays = (deadline - startDate) 的天数
workDays = availableDays 中符合 workdayPattern 的天数
weekendDays = availableDays 中符合 weekendPattern 的天数
totalAvailableMinutes = workDays × dailyMinutes + weekendDays × weekendMinutes
bufferMinutes = totalAvailableMinutes × bufferRatio
usableMinutes = totalAvailableMinutes - bufferMinutes
```

**排程算法（伪代码）：**
```
sessions = topologicalSort(knowledgeTree.nodes)
currentDate = startDate
dailyUsed = 0

for session in sessions:
  if dailyUsed + session.estimatedMinutes > dailyLimit(currentDate):
    currentDate = nextAvailableDay(currentDate)
    dailyUsed = 0

  session.scheduledDate = currentDate
  session.scheduledTime = pushTime
  dailyUsed += session.estimatedMinutes

  # 插入间隔复习
  for interval in [1, 3, 7, 14, 30]:
    reviewSession = createReview(session, interval)
    insertIntoPlan(reviewSession)
```

### 3. 间隔复习安排

基于艾宾浩斯遗忘曲线：
- 学习后第 1 天：第一次复习
- 第 3 天：第二次复习
- 第 7 天：第三次复习
- 第 14 天：第四次复习
- 第 30 天：巩固复习

复习时长 = 原学习时长 × 0.3（复习比新学快）

### 4. 里程碑设置

根据目标类型采用不同的里程碑策略：

**考试型目标（benchmarked）：**
- 每个模块结束设阶段测试
- 每两周设一次综合评估
- 关键节点设检查点
- 里程碑 type = `quiz` / `assessment` / `checkpoint`

**无标准型目标（unbenchmarked）：**
- 以 goals.yaml 中的 milestones 为锚点排程
- 每个 milestone 的 targetDate 作为该阶段内容的截止节点
- 知识树的节点按里程碑分组：里程碑 M1 覆盖 level-0 模块 A，M2 覆盖模块 B，以此类推
- 每个 milestone 到期时触发**验收**（口头讲解/实操演示/角色扮演/作品提交等，见 learning-goals）
- 里程碑 type = `milestone_check`（验收型）+ `quiz`（测验型）混合

### 4.1 两种目标的排程差异

| 维度 | 考试型 | 无标准型 |
|------|--------|---------|
| 锚点 | 考试日期（deadline） | 各里程碑 targetDate |
| 节奏 | 均匀分配到考试日 | 按里程碑分组，里程碑间可变速 |
| 缓冲 | 考前留 14 天冲刺 | 每个里程碑前留 3 天验收缓冲 |
| 验收 | 模拟考试/真题 | 自定义验收方式（见 learning-goals） |

---

## 动态调整规则（量化版）

### 触发条件

每次以下事件发生时自动触发调整：
1. 阶段测验完成
2. 用户反馈学习状态（太难/太简单/进度变化）
3. 每周复盘时
4. 用户主动要求调整

### 量化指标

**效率比（efficiencyRatio）：**
```
efficiencyRatio = estimatedMinutes / actualMinutes
> 1.2 → 学得快 | 0.8 - 1.2 → 正常 | < 0.8 → 学得慢
```

**掌握度提升率（masteryGainRate）：**
```
masteryGainRate = (currentMastery - previousMastery) / sessionsSinceLastAssessment
> 0.3 → 提升快 | 0.1 - 0.3 → 正常 | < 0.1 → 提升慢
```

**进度偏差（scheduleVariance）：**
```
scheduleVariance = completedSessions / plannedSessions
> 1.1 → 超前 | 0.9 - 1.1 → 正常 | < 0.9 → 落后
```

### 调整策略

| 掌握度 | 策略 |
|--------|------|
| ≥ 80% | 跳过复习，后续加速（×0.8），增加进阶深度 |
| 60%-79% | 按原计划继续，正常复习 |
| 40%-59% | +1 次专项 session，后续减速（×1.3） |
| < 40% | 暂停新内容，重新讲解，+2 次专项，必要时拆解子节点 |

### 效率趋势量化调整

```
连续 3 天效率比 > 1.3 → dailyMinutes × 1.2, estimatedMinutes × 0.85
连续 3 天效率比 < 0.7 → dailyMinutes × 0.8, 复习 session +20%
scheduleVariance < 0.7 持续 1 周 → 重新计算 deadline（延长 10-20%）
```

### 调整通知格式

调整时必须告知用户：
1. **调整了什么**（具体变化）
2. **为什么调整**（数据依据）
3. **新计划的预期效果**

---

## Cron 任务管理

**学习计划生成后，调用 `learning-cron` 模块创建定时任务。**

| 任务 | Cron 表达式 | 说明 |
|------|------------|------|
| 每日学习推送 | `0 9 * * 1-5` | 工作日 9:00 推送新内容 |
| 每日复习提醒 | `0 20 * * 1-5` | 工作日 20:00 提醒复习 |
| 周末学习推送 | `0 9 * * 6` | 周六 9:00 推送 |
| 每周测验 | `0 14 * * 5` | 周五 14:00 阶段测验 |
| 每周复盘 | `0 18 * * 5` | 周五 18:00 生成周报 |
| 每月复盘 | `0 10 1 * *` | 每月 1 号 10:00 月报 |

调整计划时同步更新相关 cron 任务。

---

## 冲刺模式

根据目标类型采用不同的冲刺触发策略：

### 考试型冲刺（deadline ≤ 14 天）

```
1. 暂停非核心内容的学习
2. 聚焦高频考点和易错点（按 importanceMultiplier 排序）
3. 每日推送量增加到 1.5 倍
4. 测验频率增加到每日 1 次
5. 每次测验前生成"必复习清单"
6. 调整 cron 为每日 3 次推送（7:00 / 12:00 / 19:00）
```

### 里程碑冲刺（无标准型，最近里程碑到期 ≤ 7 天）

```
1. 聚焦当前里程碑覆盖的知识点
2. 推送量适度增加（×1.3，不像考试型那么激进）
3. 增加验收模拟练习（按 milestone 的 assessmentMethod 模拟）
4. 测验频率增加到每日 1 次，题目围绕验收标准
5. 里程碑验收前生成"必复习清单"
6. cron 推送频率不变（避免给技能型学习者太大压力）
```

### 冲刺结束

- **考试型**：考试结束后进入复盘阶段，根据成绩决定是否重开学习计划
- **无标准型**：里程碑验收完成后自动恢复正常节奏，进入下一个里程碑的学习