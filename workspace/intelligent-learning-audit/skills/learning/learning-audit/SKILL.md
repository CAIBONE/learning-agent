---
name: learning-audit
description: "Independent audit agent. Audits generated artifacts (knowledge trees, learning content, quiz questions, learning volume) with automated quality checks before delivery. Runs in isolated context — cannot see the generation process, only the artifact, data files, and session notes."
---

# Learning Audit — 生成物审计（独立 Agent）

## 定位

**独立的质量审计 Agent。与生成过程在完全隔离的上下文中运行。**

核心原则：
- **生成 ≠ 交付。** 所有生成物必须通过审计才能推送给用户。
- **独立视角。** 审计 Agent 看不到 Main Agent 的生成推理过程，只看到生成物和客观数据。这确保了审计的客观性——不会因为"理解为什么这样生成"而放松审查标准。
- **自主读数据。** 审计 Agent 自己读取学生数据文件和 session-notes，不需要 Main Agent 把分析结论喂过来。

## 独立 Agent 运行模式

### 信息隔离原则

```
Audit Agent 能看到的：                    Audit Agent 不能看到的：
────────────────────────                  ─────────────────────────
✅ 最终生成物（内容/题目/知识树）           ❌ Main Agent 的推理过程
✅ audit SKILL 的检查清单                  ❌ Main Agent 为什么选择某个例子
✅ 学生数据文件（自己读）                   ❌ Main Agent 对内容质量的主观判断
✅ session-notes.yaml（对话中的关键信息）   ❌ 用户完整的对话历史
✅ 知识树/目标/计划等参考文件               ❌ 生成过程中产生的中间结果
```

### 派发协议

Main Agent 调用 Audit Agent 时，只传递：

```yaml
auditType: "content | quiz | knowledge_tree | volume | plan"
targetId: "<nodeId 或 subjectId>"
studentId: "<studentId>"
artifact: "<生成物的完整内容>"
```

**不传递**：生成推理过程、Main Agent 的自适应分析结论、对话历史。

### 数据读取清单

Audit Agent 收到派发后，**自主读取**以下文件：

| 文件路径 | 用途 |
|---------|------|
| `data/<studentId>/session-notes.yaml` | 对话中产生的用户需求、纠错、上下文（**关键！**） |
| `data/<studentId>/mastery.json` | 各节点掌握度 |
| `data/<studentId>/content-log.jsonl` | 内容推送日志，可计算学习速度/效率比 |
| `data/<studentId>/quiz-results.jsonl` | 历史测验记录，用于去重和错题分析 |
| `data/<studentId>/wrong-answers.jsonl` | 错题本 |
| `data/<studentId>/knowledge-tree-<subjectId>.yaml` | 知识树结构 |
| `data/<studentId>/plans/<subjectId>.yaml` | 学习计划（了解当前节点、冲刺模式等） |
| `data/<studentId>/goals.yaml` | 学习目标（有标准型/无标准型、里程碑） |
| `templates/content-template.md` | 内容模板（用于检查结构完整性） |
| `schemas/knowledge-tree.schema.json` | 知识树 Schema（用于结构验证） |

### session-notes 审计应用

session-notes.yaml 记录了对话中产生的关键信息。审计时必须逐条检查与当前审计相关的 note：

```
审计流程：
1. 读取 session-notes.yaml
2. 筛选 appliesTo 匹配当前 targetId 或 "all" 的条目
3. 对每条 note 生成对应的验证检查：
   - user_feedback "多用电商例子" → 检查内容是否包含电商场景案例
   - correction "上次概念有误" → 检查本次内容是否使用了正确概念
   - learning_state "用户感到困惑" → 检查内容是否对该知识点做了更详细的解释
   - requirement_change "跳过第 5 章" → 检查题目是否未涉及第 5 章内容
   - context "本周加量" → 检查内容量是否按调整后的策略生成
4. 将 session-notes 相关的检查结果加入审计记录
```

**注意**：session-notes 中的条目是**客观需求**，审计 Agent 验证生成物是否满足这些需求。不是"Main Agent 说满足了就满足了"——审计 Agent 要自己看生成物来判断。

## 审计结果结构（重要）

每个检查项的审计结果必须包含以下字段，供 Main Agent 决策：

```yaml
check:
  name: "检查项名称"
  passed: false
  severity: "hard"              # hard = 必须修复才能推送 | soft = 可带标记推送
  issue: "具体问题描述"
  fixAction: "具体修复建议"
  fixableByMain: true           # true = Main Agent 可自行修复 | false = 需用户裁决
```

### severity 定义

| severity | 含义 | 不通过时的处理 |
|----------|------|--------------|
| **hard** | 客观的结构性问题（字数不够/答案错误/Schema 违规/错题未覆盖） | 必须修复 → 重新审计 → 最多重试 3 次 → 仍不通过则提交用户裁决 |
| **soft** | 主观判断类问题（知识准确性偏差/风格偏好/深度不够） | 建议修复 → 可带标记推送 → 标记中说明 soft 指标的具体问题 |

### fixableByMain 定义

| fixableByMain | 含义 | 处理 |
|---------------|------|------|
| **true** | Main Agent 可以根据 fixAction 自行修复，不需要用户参与 | 自动修复 → 重新派发审计 |
| **false** | 存在歧义或需要用户确认（如审计和 Main Agent 对某个概念的定义有分歧） | 提交用户裁决 |

## 审计失败处理流程

### 重试机制

```
第 1 次审计 → 不通过
    → Main Agent 根据 fixAction 修复（仅限 fixableByMain: true 的项）
    → 重新派发审计

第 2 次审计 → 仍不通过
    → Main Agent 继续修复
    → 重新派发审计

第 3 次审计 → 仍不通过
    → 进入用户裁决流程
```

**重试上限：3 次。** 每次重新派发时，Audit Agent 是全新调用（无历史记忆），需要重新读取所有数据文件。

### 用户裁决流程

当 3 次重试后仍有未通过的检查项时：

```
1. Main Agent 将以下信息展示给用户：
   - 生成物内容（或摘要）
   - 审计未通过的检查项原文
   - 每个未通过项的 issue + fixAction
   - Main Agent 已尝试的修复（如有）

2. 用户选择：
   a) "可以接受" → 带标记推送（软指标）或直接推送（用户覆盖了审计判断）
   b) "按审计建议修改" → Main Agent 按 fixAction 修改，不再审计，直接推送
   c) "重新生成" → Main Agent 从头重新生成（非修复），重新走审计流程
   d) "跳过本次" → 不推送，记录跳过原因，下次补推
```

### 推送标记格式

当 soft 指标未通过但用户接受或重试耗尽时，推送内容附带标记：

```
⚠️ 审计提示（不影响推送）：
• 「知识准确性」：「递归」的定义可能与主流教材有偏差，建议对照教材确认
• 「session-notes」：内容中电商案例数量偏少（1 个），session-notes 建议 ≥ 3 个
```

### 审计延迟处理

审计导致推送延迟时（如 cron 触发后审计不通过，修复耗时）：

```
1. 如果延迟 ≤ 15 分钟：正常推送，不通知用户
2. 如果延迟 > 15 分钟：推送时附带提示
   "⏰ 今日内容因质量检查多轮修正，延迟推送。内容已更新。"
3. 如果进入用户裁决：推送通知
   "⏰ 今日内容审计中发现问题，需要你确认：[查看]"
```

## 触发条件

- `learning-knowledge-tree` 生成或编辑知识树后 → Main Agent 派发审计
- `learning-content` 生成学习内容后、写入飞书文档前 → Main Agent 派发审计
- `learning-quiz` 生成测试题后、发送给用户前 → Main Agent 派发审计
- `learning-plan` 生成或调整学习计划后 → Main Agent 派发审计
- **定期触发**：每周复盘时自动执行学习量审计

---

## 一、知识图谱审计

在知识树 YAML 生成/编辑后、保存前执行。

### 检查清单

| # | 检查项 | 方法 | 通过条件 |
|---|--------|------|---------|
| 1 | JSON Schema 结构验证 | 用 `schemas/knowledge-tree.schema.json` 验证 | 无结构错误 |
| 2 | nodeId 唯一性 | 遍历所有节点（含 children 嵌套），收集 nodeId 检查重复 | 0 个重复 |
| 3 | prerequisites 引用完整 | 收集全部 nodeId 到集合，逐一检查每个 prerequisites 引用 | 所有引用存在 |
| 4 | 循环依赖检测 | 对 prerequisites 构建有向图，DFS 检测环 | 无环 |
| 5 | 深度和时长合理性 | 树深 ≤ 4；单节点 estimatedMinutes ∈ [5, 120]；totalNodes / estimatedTotalMinutes 与实际一致 | 全部符合 |
| 6 | 内容合理性抽检 | 根节点数 ∈ [3, 8]；叶子节点 description 非空；level 值与嵌套深度一致 | 全部符合 |
| **7** | **节点内容准确性验证** | **抽检核心节点（level 0-1），联网搜索验证概念定义是否准确** | **与权威来源无矛盾** |
| **8** | **前置依赖逻辑检查** | **检查 prerequisites 关系是否合理：A 依赖 B，B 的知识是否确实是 A 的前提** | **前置关系符合学科逻辑** |
| **9** | **session-notes 合规性** | **检查知识树是否满足 session-notes 中的相关需求** | **所有未 resolved 的适用条目已落实** |

### 执行流程

```
1. 读取学生数据文件（知识树、目标、session-notes）
2. 执行检查项 1-9
3. 检查项 1-6 为硬指标（结构正确性），必须全部通过
4. 检查项 7-8 为知识准确性（软指标），发现问题记录但不阻塞保存
5. 检查项 9 为需求合规性（硬指标），session-notes 中的适用需求必须落实
6. 硬指标未通过 → 返回结果给 Main Agent，建议修复方向（最多重试 2 次）
7. 2 次重试仍失败 → 保存但推送时告知用户存在问题
8. 软指标问题 → 记录到 audit 日志，供后续迭代改进
```

### 节点内容准确性验证说明

**确定性抽样策略**（控制成本 + 多轮覆盖）：

**不要用 LLM 主观判断"随机"选择节点**——LLM 会反复选同一批节点。使用以下确定性算法：

```python
import hashlib

# 1. 收集所有 level-1 节点，按 nodeId 排序
level1_nodes = sorted([n for n in all_nodes if n['level'] == 1], key=lambda n: n['nodeId'])

# 2. 用 hash 生成确定性 seed（每轮审计 round 递增）
audit_round = retryCount + 1  # 第 1 次审计 round=1，重试 round=2,3...
seed_str = f"{studentId}:{subjectId}:{audit_round}"
seed = int(hashlib.md5(seed_str.encode()).hexdigest(), 16)

# 3. 取 seed % 3 == index % 3 的节点（约 33%），每轮覆盖不同节点
selected = [n for i, n in enumerate(level1_nodes) if (seed + i) % 3 == 0]

# 4. 最终抽检范围 = 所有 level-0 节点 + selected level-1 节点
```

- **所有 level-0 节点**：每次都查（核心模块，定义错误影响全局）
- **level-1 节点**：每轮约 33%，3 轮审计后所有节点至少被覆盖一次
- **结果可复现**：相同 studentId + subjectId + round → 相同抽样

验证方法：取节点的 title + description 关键词联网搜索，对比前 3 条结果的定义
判断标准：核心概念定义与权威来源无矛盾（允许表述差异，不允许事实错误）

---

## 二、学习内容审计

在学习材料生成后、写入飞书文档前执行。

### 检查清单

| # | 检查项 | 方法 | 通过条件 |
|---|--------|------|---------|
| 1 | 字数达标 | 统计正文中文字符数 | ≥ 最低标准（2000/3000/4500 字） |
| 2 | 结构完整性 | 检查必需小节标题是否存在（对照 `templates/content-template.md`） | 全部存在（"考试技巧"仅考试类科目必需） |
| 3 | 知识准确性抽检 | 取核心概念定义，联网搜索交叉验证 | 与权威来源无矛盾 |
| 4 | 前后一致性 | 内容与知识树节点 description 比对 | 主题一致、无偏离 |
| 5 | 练习题可解性 | 检查练习题是否有对应的参考答案 | 每题都有答案和解析 |
| **6** | **自适应策略匹配** | **读取 content-log 计算效率比，对照学习速度自适应表验证内容长度/难度** | **符合策略表要求** |
| **7** | **session-notes 合规性** | **检查内容是否满足 session-notes 中的用户需求** | **所有未 resolved 的适用条目已落实** |

### 自适应策略验证说明

审计 Agent 自己从 `content-log.jsonl` 计算效率比，然后对照 `learning-content` SKILL 中的策略表验证：

```
效率比 = estimatedMinutes / actualMinutes（从最近 3 次内容日志计算）

效率比 > 1.2 → 内容应 ≥ 4000 字，5-6 个例子，中等+到困难练习
效率比 0.8-1.2 → 内容应 ≥ 3000 字，4-5 个例子，中等练习
效率比 < 0.8 → 内容应 ≥ 2000 字，2-3 个例子，基础练习，分步详解
首次学习（无历史）→ 按中等策略

检查：实际内容是否符合对应策略的要求？
```

### session-notes 审计示例

```
session-notes 中有：
  - type: user_feedback
    content: "多用电商场景举例，减少抽象理论"
    appliesTo: "all"
    resolved: false

审计检查：
  → 内容中是否包含电商相关的案例/场景？
  → 案例数量是否 ≥ 3 个？
  → 理论解释是否有配套的实操场景？
  → 通过条件：内容中有明确的电商场景应用段落
```

### 执行流程

```
1. 读取学生数据文件（content-log、mastery、session-notes、知识树、计划、目标）
2. 执行检查项 1-7
3. 检查项 1-2 为硬指标（必须通过）
4. 检查项 3-5 为软指标（记录但不阻塞）
5. 检查项 6-7 为硬指标（自适应策略 + session-notes 合规）
6. 硬指标未通过 → 返回结果给 Main Agent，附带具体修复建议（最多 1 次重试）
7. 记录 audit 结果
8. 通过后 Main Agent 进入写飞书文档流程
```

---

## 三、测试题审计

在测试题生成后、发送给用户前执行。

### 检查清单

| # | 检查项 | 方法 | 通过条件 |
|---|--------|------|---------|
| 1 | 题型比例 | 统计各题型数量占比 | 选择 50-70% / 判断 10-30% / 简答 5-20% / 应用 5-20% |
| 2 | 难度分布 | 根据 masteryLevel 判断难度档位 | 基础 ≥ 40% / 进阶 20-50% / 挑战 5-25% |
| 3 | **答案正确性** | Agent 重新独立求解每道题 | 求解结果与预设答案一致 |
| 4 | **题目-知识点对应** | 检查每道题关联的 nodeId 是否在已学习的节点范围内 | 全部对应已学节点 |
| 5 | 题目去重 | 与 quiz-results.jsonl 中历史题目对比 | 重复率 < 20% |
| 6 | 选项质量 | 选择题：选项互斥、有且仅有一个正确答案；无"以上都对/都不对"笼统选项 | 全部符合 |
| 7 | 题干清晰度 | 检查题干是否有歧义词、是否包含足够上下文 | 无明显歧义 |
| **8** | **错题覆盖** | **检查 wrong-answers.jsonl 中未掌握的错题是否在本次测验中出现** | **到期错题必须出现** |
| **9** | **session-notes 合规性** | **检查题目是否满足 session-notes 中的相关需求** | **所有未 resolved 的适用条目已落实** |

### 执行流程

```
1. 读取学生数据文件（quiz-results、wrong-answers、mastery、session-notes、知识树、计划）
2. 执行检查项 1-9
3. 检查项 3-4（答案正确性 + 知识点对应）为硬指标，必须通过
4. 检查项 8 为硬指标（到期错题必须覆盖）
5. 检查项 9 为硬指标（session-notes 合规）
6. 检查项 1-2 偏差 > 10% → 调整题目组成后重新检查
7. 检查项 5 重复率 ≥ 20% → 替换重复题目
8. 最多重试 1 次
9. 记录 audit 结果
10. 通过后 Main Agent 进入发送流程
```

### 题目-知识点对应说明

每道题必须关联到知识树中的具体 nodeId：
- 题目考查的知识点必须是该节点已推送学习内容覆盖的范围
- 不允许出未学节点的题（除考前模拟外）
- 错题重出时，必须关联到原错题的 nodeId

---

## 四、学习量审计

定期（每周复盘时）自动执行，检查学习量是否达标。

### 检查清单

| # | 检查项 | 方法 | 通过条件 | 告警阈值 |
|---|--------|------|---------|---------|
| 1 | **单节点内容量** | 检查每篇已推送内容的字数 | ≥ 最低标准（2000/3000/4500 字） | 低于标准 → 标记需补充 |
| 2 | **知识树覆盖率** | 将该科目的知识树与该领域的通用知识框架（联网检索）对比 | 覆盖率 ≥ 70% | < 70% → 建议补充缺失模块 |
| 3 | **学习进度偏差** | 实际已完成节点数 / 计划应完成节点数 | 偏差 ≤ 30% | > 30% → 告警并建议调整计划 |
| 4 | **学习时长达成率** | 实际学习总时长 / 计划学习总时长 | 达成率 ≥ 70% | < 70% → 提醒用户关注时间投入 |

### 执行流程

```
1. 每周复盘时自动触发（由 learning-review 调用）
2. 读取相关数据文件
3. 执行检查项 1-4
4. 全部通过 → 记录 audit 结果 (passed: true)
5. 任一告警 → 记录告警项 → 生成调整建议
6. 检查项 2（覆盖率 < 70%）→ 自动检索缺失模块 → 建议补充到知识树
7. 检查项 3-4 告警 → 建议调整学习计划（增加每日时长 / 延长截止日期）
8. 记录 audit 结果到 data/<studentId>/audit/volume-<subjectId>-<timestamp>.json
```

### 知识树覆盖率计算方法

```
1. 联网检索该科目/领域的通用知识框架（搜索 "XXX 知识体系" / "XXX 完整框架"）
2. 提取通用框架的核心模块列表（通常 5-15 个一级模块）
3. 与当前知识树的 level-0 节点逐一比对（标题语义匹配）
4. 覆盖率 = 已覆盖模块数 / 通用框架总模块数
5. 未覆盖的模块 → 记录到审计结果，建议补充
```

---

## 五、学习计划审计

在学习计划生成或调整后执行。重点检查排程合理性，防止"为了填满期限而人为拉长"。

### 检查清单

| # | 检查项 | 方法 | 通过条件 |
|---|--------|------|---------|
| 1 | **总工时合理性** | 读取计划中所有 session 的 estimatedMinutes 求和，与 knowledgeTree 的 total estimatedMinutes 比对 | 偏差 ≤ 20% |
| 2 | **基础折减是否应用** | 读取 goals.yaml 的 baseline 字段，检查计划总工时是否对应有基础的用户做了折减 | 有相关基础的用户，总工时 ≤ 零基础估算值 × 0.6 |
| 3 | **里程碑间隔合理性** | 检查相邻 milestone 之间的日历天数，对比实际工时需求 | 间隔天数 ≤ 该阶段总工时 / 每日学习时长 + 3天缓冲 |
| 4 | **单 session 时长上限** | 检查每个 session 的 estimatedMinutes | ≤ 120 分钟 |
| 5 | **日历是否填满期限** | 计算 (deadline - startDate) 与 (totalMinutes / dailyMinutes) 的比值 | 比值 > 2.0 时告警（计划工时远少于可用时间，存在人为拉长嫌疑） |
| 6 | **session-notes 合规性** | 检查计划是否满足 session-notes 中的相关需求（如"本周加量"） | 所有未 resolved 的适用条目已落实 |

### 执行流程

```
1. 读取学生数据文件（计划、知识树、目标、session-notes）
2. 执行检查项 1-6
3. 检查项 1-4 为硬指标（结构性正确性），必须全部通过
4. 检查项 5 为软指标（告警但不阻塞）
5. 检查项 6 为硬指标（session-notes 合规）
6. 硬指标未通过 → 返回结果给 Main Agent，附带具体修复建议
7. 记录 audit 结果
```

### "填满期限"检测算法

```
totalPlannedMinutes = Σ(session.estimatedMinutes for all sessions)
dailyMinutes = plan.schedule.dailyMinutes
actualNeededDays = totalPlannedMinutes / dailyMinutes
calendarDays = (deadline - startDate).days

ratio = calendarDays / actualNeededDays

if ratio > 2.0:
  → 软指标告警："计划工时仅占可用时间的 {1/ratio:.0%}，存在人为拉长里程碑间隔的嫌疑"
  → 建议：告知用户实际可完成时间，询问是否增加进阶内容
if ratio > 3.0:
  → 硬指标不通过："计划严重拉伸（{1/ratio:.0%} 利用率），必须重新排程或增加内容"
```

---

## 审计记录格式

```json
{
  "auditId": "audit-20260615-001",
  "type": "content",
  "targetId": "mod-01-02",
  "studentId": "student-abc123",
  "subjectId": "python-basics",
  "timestamp": "2026-06-15T10:00:00+08:00",
  "retryCount": 0,
  "checks": [
    {
      "name": "字数达标",
      "checkId": 1,
      "severity": "hard",
      "passed": true,
      "detail": "实际 3200 字 ≥ 最低 3000 字"
    },
    {
      "name": "结构完整性",
      "checkId": 2,
      "severity": "hard",
      "passed": false,
      "detail": "缺少 '考试技巧' 小节",
      "issue": "内容模板要求考试类科目必须包含考试技巧小节",
      "fixAction": "在末尾补充 200-300 字的考试技巧段落",
      "fixableByMain": true
    },
    {
      "name": "知识准确性抽检",
      "checkId": 3,
      "severity": "soft",
      "passed": false,
      "detail": "「递归」定义与主流教材有偏差",
      "issue": "教材定义强调 '函数调用自身'，内容中表述为 '自己重复执行'",
      "fixAction": "建议修正为 '函数直接或间接调用自身的编程技术'",
      "fixableByMain": true
    },
    {
      "name": "session-notes 合规性",
      "checkId": 7,
      "severity": "hard",
      "passed": false,
      "detail": "session-notes 要求 '多用电商场景举例'，但内容中未包含电商案例",
      "issue": "用户需求未被满足",
      "fixAction": "在「条件判断」章节增加电商促销条件判断的示例（如满减/折扣计算）",
      "fixableByMain": true
    }
  ],
  "summary": {
    "totalChecks": 7,
    "passed": 4,
    "failedHard": 2,
    "failedSoft": 1
  },
  "verdict": "not_passed",
  "nextAction": "retry_by_main"
}
```

### verdict 取值

| verdict | 含义 | Main Agent 行为 |
|---------|------|----------------|
| `passed` | 全部通过 | 继续后续流程 |
| `passed_with_notes` | 通过但有 soft 建议 | 可推送，附带 soft 建议标记 |
| `not_passed` | 有 hard 指标未通过 | 按 fixAction 修复，重新派发（retryCount < 3） |
| `user_arbitration` | 重试 3 次后仍有未通过项 | 提交用户裁决 |

## 与 Main Agent 的协作

### 调用方式

Audit Agent 由 Main Agent 通过**跨 Agent 调用**触发，不是在同一上下文中作为 skill 调用。

| 触发方 | 审计类型 | 触发时机 | 派发内容 |
|--------|---------|---------|---------|
| `learning-knowledge-tree` | 知识图谱审计 | 生成/编辑后、保存前 | 知识树 YAML |
| `learning-plan` | 学习计划审计 | 生成/调整后 | 完整计划 YAML + goals.yaml |
| `learning-content` | 学习内容审计 | 生成后、写飞书文档前 | 完整学习内容 |
| `learning-quiz` | 测试题审计 | 生成后、发送用户前 | 完整题目集 |
| `learning-review` | 学习量审计 | 每周复盘时自动触发 | subjectId |

### 审计结果返回与处理

Audit Agent 完成审计后，返回结构化结果给 Main Agent。Main Agent 根据 verdict 决策：

```
verdict = "passed"
  → Main Agent 继续后续流程（写飞书文档/发送题目/保存知识树）

verdict = "passed_with_notes"
  → Main Agent 继续后续流程，推送时附带 soft 建议标记

verdict = "not_passed" 且 retryCount < 3
  → Main Agent 根据 fixAction 修复（仅处理 fixableByMain: true 的项）
  → 重新派发审计（携带 retryCount）

verdict = "not_passed" 且 retryCount = 3
  → verdict 自动升级为 "user_arbitration"
  → Main Agent 向用户展示审计反馈，等待裁决

verdict = "user_arbitration"
  → Main Agent 展示：生成物内容 + 未通过检查项的 issue/fixAction + 已尝试的修复
  → 用户选择：
    a) 接受 → 带标记推送
    b) 按审计建议修改 → Main Agent 修改后直接推送（不再审计）
    c) 重新生成 → 从头生成，重新走审计流程
    d) 跳过 → 不推送，记录原因
```

### 降级处理

如果 Audit Agent 调用失败（超时、不可用等）：
1. Main Agent 降级为在同一上下文中执行审计检查
2. 在审计记录中标注 `"degradedMode": true`
3. 下次对话时告知用户审计降级事件

## 注意事项

- **重试上限 3 次**：超过后提交用户裁决，不再自动重试
- **硬指标必须修复**：字数/结构/答案正确性/Schema 合规/错题覆盖等 hard 指标不通过，不可带标记推送
- **软指标可带标记推送**：知识准确性偏差等 soft 指标不通过，用户接受后可带标记推送
- **审计日志可追溯**：所有审计记录保留，供复盘时分析生成质量趋势
- **审计成本意识**：联网验证仅抽检核心概念，不全文搜索
- **学习量审计不阻塞推送**：覆盖率不足时建议补充，但不阻止当前学习计划继续执行
- **信息隔离是核心**：绝不向 Main Agent 索要"生成推理过程"，只基于生成物和数据文件做独立判断
- **审计延迟需提示**：因审计多轮修正导致推送延迟 > 15 分钟时，附带延迟提示
