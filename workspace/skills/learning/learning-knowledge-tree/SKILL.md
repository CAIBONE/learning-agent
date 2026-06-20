---
name: learning-knowledge-tree
description: "Generate, edit, and manage knowledge trees and frameworks for any subject. Creates hierarchical YAML structures with semantic validation and independent audit by Audit Agent before saving."
---

# Learning Knowledge Tree — 知识树管理

## 触发条件

- 用户确认学习目标后
- 用户要求"帮我梳理 X 的知识体系"
- 用户说"生成知识框架"

## 数据路径约定

- 知识树文件：`knowledge-trees/<studentId>/<subjectId>.yaml`
- 目标文件：`learning-profiles/<studentId>/goals.yaml`
- Schema 验证：`schemas/knowledge-tree.schema.json`
- **对话笔记**：`progress/<studentId>/session-notes.yaml`
- `<studentId>` 从对话上下文或 profile 路径推断

## 知识树生成流程

### 第 1 步：分析目标
1. 读取对应学生的 `goals.yaml`，理解：
   - 学习科目和范围
   - 目标类型（有标准型 benchmarked / 无标准型 unbenchmarked）
   - 有标准型：考试日期 / 目标分数 / 考纲
   - 无标准型：里程碑列表 + 各里程碑 targetDate + 期望 proficiency 水平
   - 用户当前基础
2. 读取 `session-notes.yaml`，检查是否有适用于当前科目的对话衍生需求（如用户要求增加/删除某些模块、强调某方向）

### 第 2 步：生成知识树

根据目标类型采用不同的深度策略：

**有标准型**：以考试大纲为边界，截止日期决定树的深度（时间紧→只覆盖核心考点，时间充裕→覆盖扩展内容）

**无标准型**：以里程碑为边界，树的深度和范围由 milestone 的验收标准决定。
- 里程碑只要求"能解释"→ 树到 level-1 即可
- 里程碑要求"能操作"→ 树扩展到 level-2
- 里程碑要求"能创造"→ 树扩展到 level-3
- 如果无明确 proficiency 要求 → 默认生成到 level-2，告知用户可在确认时调整

**生成时必须满足 session-notes 中的适用需求**（如用户要求侧重某方向、跳过已掌握的模块等）。

**树结构规则：**
- 根节点：科目大模块（通常 3-8 个）
- 二级节点：每个模块下的核心知识点
- 三级节点：具体技能/概念
- 最多 4 层，避免过深
- 每个节点标注 prerequisites（前置依赖）和 estimatedMinutes（预计学习分钟）

### 第 3 步：强制验证清单（生成后必须逐项执行，不通过则不可保存）

#### Step 1：JSON Schema 结构验证
- 用 `schemas/knowledge-tree.schema.json` 验证 YAML 结构
- 有错误 → 修复后重新验证

#### Step 2：nodeId 唯一性
- 遍历所有节点（含嵌套 children），收集全部 nodeId
- 检查是否有重复
- 有重复 → 重新生成重复的 nodeId

#### Step 3：prerequisites 引用完整性
- 收集所有 nodeId 到集合 `allNodeIds`
- 遍历每个节点的 prerequisites，检查每个引用是否在 `allNodeIds` 中
- 引用不存在 → 移除无效引用或添加缺失节点

#### Step 4：循环依赖检测
- 对 prerequisites 构建有向图
- 执行 DFS 检测环
- 发现环（如 A→B→...→A）→ 断开环中最弱的一条依赖

#### Step 5：深度和时长合理性
- 树深 ≤ 4 层
- 单个节点 estimatedMinutes ∈ [5, 120]
- `totalNodes` 与实际节点数一致
- `estimatedTotalMinutes` 与实际总和一致
- 不一致 → 修正计数

#### Step 6：内容合理性抽检
- 根节点数 ∈ [3, 8]
- 每个叶子节点 description 非空
- level 值与嵌套深度一致（根=0，逐级递增）

```
验证通过 → 进入第 4 步
验证失败 → 修复后重新验证，最多重试 2 次
2 次仍失败 → 记录问题，保存但在推送时告知用户
```

### 第 4 步：派发 Audit Agent 知识图谱审计

**将知识树派发给独立的 Audit Agent 进行审计。**

派发内容：
```yaml
auditType: "knowledge_tree"
targetId: "<subjectId>"
studentId: "<studentId>"
artifact: "<完整的知识树 YAML>"
```

Audit Agent 自己读取知识树 Schema、目标文件、session-notes 等进行独立审计。

审计结果处理：
- **verdict = "passed"** → 进入第 5 步
- **verdict = "passed_with_notes"** → 进入第 5 步，展示时附带 soft 建议标记
- **verdict = "not_passed" 且 retryCount < 3** → 根据 fixAction 修复（仅 fixableByMain: true 的项），重新派发审计
- **verdict = "user_arbitration"（重试 3 次后）** → 向用户展示审计反馈，等待裁决（接受/修改/重新生成/跳过）
- **Audit Agent 不可用** → 降级为本地审计（执行 6 步验证清单），记录降级事件

审计结果保存到 `progress/<studentId>/audit/knowledge-tree-<subjectId>-<timestamp>.json`

### 第 5 步：展示与确认
向用户展示知识树概要（不是全部细节，而是结构）：

```
科目: XXX
|-- 模块 A
|   |-- 知识点 A1
|   |-- 知识点 A2
|   +-- 知识点 A3
|-- 模块 B
|   |-- 知识点 B1
|   +-- 知识点 B2
...

共 X 个模块，Y 个知识点，预计 Z 小时
✅ 验证通过 | 审计通过
```

### 第 6 步：自动创建飞书学科目录

知识树确认后，**必须立即在飞书创建学科目录结构**，不要等到首次推送内容时才创建。

**前提条件**：读取 `learning-profiles/<studentId>/feishu-mapping.yaml`，确认已授权且知识库根目录已创建。

**创建流程**：

1. **创建学科文件夹**
   - 在知识库根目录下创建以 `subjectId` 命名的文件夹（如「中级经济师-经济基础」）
   - 记录 `folderToken` 到 `feishu-mapping.yaml` 的 `subjects.<subjectId>`

2. **创建章节子文件夹**
   - 为知识树的每个 level-0 节点（根模块）创建子文件夹
   - 文件夹名称 = 节点 title（如「第1章 - 社会主义市场经济」）
   - 记录每个子文件夹的 `folderToken` 到 `subjects.<subjectId>.chapters`

3. **创建通用子文件夹**
   - 在学科文件夹下创建：
     - `复习资料/` — 错题本、复习笔记
     - `报表/` — 周报、月报

4. **保存映射关系**

```yaml
# learning-profiles/<studentId>/feishu-mapping.yaml 追加
subjects:
  economic-basics:
    folderToken: "fldxxxxxxxxxxxxx"
    folderUrl: "https://xxx.feishu.cn/wiki/xxxxx"
    chapters:
      mod-01:
        title: "第1章 - 社会主义市场经济"
        folderToken: "fldxxxxxxxxxxxxx"
      mod-02:
        title: "第2章 - 市场机制"
        folderToken: "fldxxxxxxxxxxxxx"
    subfolders:
      review: "fldxxxxxxxxxxxxx"   # 复习资料
      reports: "fldxxxxxxxxxxxxx"  # 报表
```

**失败处理**：
- 飞书 API 调用失败 → 记录错误到本地，不阻塞主流程
- 告知用户"飞书目录创建失败，后续推送内容时可重试"
- 后续 `learning-content` 推送内容时检测到目录不存在会自动补建

**用户确认修改后**：如果用户修改了知识树（增删模块），同步更新飞书目录结构（新增文件夹 / 删除无用文件夹）。

### 第 7 步：接受修改
用户可以：
- 添加遗漏的知识点
- 删除不需要的内容
- 调整优先级
- 重新分组

**注意**：用户修改后需重新执行第 3 步验证清单。

## 知识树文件格式

```yaml
subjectId: "subject-slug"
studentId: "<studentId>"
title: "科目名称"
version: 1
generatedAt: "2026-06-06T12:00:00+08:00"
updatedAt: "2026-06-06T12:00:00+08:00"
totalNodes: 25
estimatedTotalMinutes: 600
nodes:
  - nodeId: "mod-01"
    title: "模块名称"
    description: "模块简介"
    level: 0
    prerequisites: []
    estimatedMinutes: 120
    children:
      - nodeId: "mod-01-01"
        title: "知识点名称"
        description: "知识点描述"
        level: 1
        prerequisites: []
        estimatedMinutes: 45
        children: []
```

## 知识树编辑

当用户要求修改知识树时：
1. 读取现有 `knowledge-trees/<studentId>/<subject>.yaml`
2. 执行修改（添加/删除/调整节点）
3. **重新执行强制验证清单**（第 3 步全部 6 项）
4. 更新 version 和 updatedAt
5. 重新计算 totalNodes 和 estimatedTotalMinutes
6. 保存并确认

## 与学习计划的衔接

知识树确认后，自动进入学习计划生成阶段：
1. 读取知识树
2. 读取目标（deadline、dailyMinutes）
3. 计算每个节点的排程
4. 生成 `learning-profiles/<studentId>/plans/<subject>.yaml`