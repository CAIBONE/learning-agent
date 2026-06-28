---
name: learning-content
description: "Retrieve, generate, audit, and push learning content per knowledge tree node. Content is audited by independent Audit Agent before delivery, written to Feishu Docs, and a link is pushed via message card with interactive buttons. Adapts depth based on student learning speed."
---

# Learning Content - 学习内容生成与推送

> 🚨 **强制流程（不可跳过任何步骤）**
>
> ```
> 1. 读取 learning-content SKILL（必须在生成任何内容之前）
> 2. 联网检索 + 生成完整教材（2000-4500 字/节）
> 3. 保存到 data/<studentId>/content/<nodeId>-<seq>.md
> 4. 记录到 content-log.jsonl
> 5. 派发审计 (sessions_send → intelligent-learning-audit, auditType: content)
> 6. 审计通过后才可写入飞书文档
> 7. 通过消息卡片推送文档链接
> ```
>
> **绝对禁止**：
> - 跳过审计直接写飞书文档
> - 写少于 2000 字的"概要"代替完整教材
> - 在没读 SKILL 的情况下生成内容
> - 在审计未通过时写入飞书文档
> - **使用 `message` 工具发送学习内容**（`message` 工具在 cron session 中可能使用错误的身份发送消息）
> - **使用 `sessions_spawn` 生成教材内容**（subagent 不会执行审计流程）
> - **审计未通过时直接推送内容**（即使是 cron 触发的实时生成，也必须先审计再推送）

## Cron 触发时的内容生成流程

> 当 cron 任务触发学习内容推送时，**必须**遵循完整流程：
>
> 1. 检查 `data/<studentId>/content/` 是否有已审计的 ready 内容（预生成场景）
> 2. 如有 ready 内容 → 直接通过 `feishu_im_user_message` 推送
> 3. 如无 ready 内容 → 生成教材 → 保存到 content/ → **派发审计** → 审计通过后推送
> 4. 审计未通过 → 修复后重新审计（最多 3 次）→ 仍不通过则推送时附带审计提示
>
> **绝对禁止**：cron 触发时跳过审计直接推送内容。

## 飞书投递规则（cron session 特别注意）

> 🔴 **cron 触发的 session 与用户主动发起的 session 有不同权限**：
>
> | 操作 | 用户 session | cron session | 替代方案 |
> |------|-------------|-------------|---------|
> | `feishu_create_doc` | ✅ | ❌ need_user_authorization | 保存本地 .md 文件，发送文件路径 |
> | `feishu_im_user_message` | ✅ | ✅ | **必须使用此工具发送消息** |
> | `feishu_oauth_batch_auth` | ✅ | ❌ 无 senderOpenId | 不可在 cron 中重新授权 |
> | `message` | ⚠️ | 🔴 **身份可能错误** | **绝对禁止使用** |
>
> **cron session 的投递流程**：
> 1. 生成教材 → 保存到 `data/<studentId>/content/` 本地文件
> 2. 派发审计 → sessions_send（审计官可正常读取文件）
> 3. 审计通过 → 用 `feishu_im_user_message` 发送消息给用户，内容包括：
>    - 学习节点标题和摘要
>    - 本地文件路径
>    - （如已创建飞书文档）飞书文档链接

## 核心原则（强制）

1. **必须尝试写飞书文档。** 任何学习材料都必须先写入飞书文档，再通过消息卡片推送文档链接。
   **失败回退：** 如果飞书文档创建失败（授权问题、网络问题等），必须：
   a) 将完整内容保存到本地 `data/<studentId>/content/<nodeId>-<seq>.md`
   b) 通过聊天发送简短通知（NOT 完整内容），包含：节点信息、内容摘要、本地保存路径
   c) 通知用户文档创建失败，授权后将自动补推
   d) **禁止重试超过2次**，避免超时
   e) **禁止在聊天中发送完整学习内容**（太长的消息会被截断，用户体验差）
2. **内容必须有足够深度和长度。** 每个节点的学习材料是一篇完整教材，不是概要或提纲。
3. **内容生成 = 联网检索 + 深度整合 + 结构化输出。** 不是搜索结果的拼接，而是基于多方资料的原创教材。
4. **效率高 = 内容更多。** 学习效率高说明用户吸收快，应该推送更多、更深的内容。
5. **生成后必须审计。** 内容生成后必须经过 **Audit Agent** 独立审计，通过后才能写入飞书文档。

## 内容深度与长度要求

**最低标准（所有节点）：**

| 章节 | 最低字数 | 结构要求 |
|------|---------|---------|
| 单个知识点（estimatedMinutes <= 60） | 2000+ 字 | 6+ 个小节 |
| 中等知识点（60 < estimatedMinutes <= 120） | 3000+ 字 | 8+ 个小节 |
| 大章节（estimatedMinutes > 120） | 4500+ 字 | 10+ 个小节 |

**"太浅"的定义（禁止出现）：**
- 只有要点列表，没有展开解释
- 每个要点只有一句话
- 没有具体例子或案例
- 没有"为什么重要"的动机说明
- 没有练习题或思考题
- 内容读完不超过 10 分钟

**"足够深"的标准：**
- 每个关键概念都有定义 + 解释 + 例子
- 有实际案例或真题引用（考试类科目）
- 有常见误区和易错点分析
- 有前后知识点的关联说明
- 有动手练习和思考题
- 有阶段性总结便于复习

## 学习速度自适应

**核心逻辑：学习效率越快，推送的内容应该越多、越深。**

### 内容生成策略

| 学习速度 | 内容长度 | 例子数量 | 练习难度 | 解释深度 |
|---------|---------|---------|---------|---------|
| **快（效率高）** | **4000-5000+字** | **5-6个** | **中等+到困难** | **深入+拓展** |
| 中等 | 3000-3500字 | 4-5个 | 中等 | 详细 |
| **慢（效率低）** | **2000-2500字** | **2-3个** | **基础** | **分步详解、精简** |

**注意：** 首次学习（无历史数据）按"中等"策略生成。

## 触发条件

- Cron 定时任务触发（按计划推送下一个节点）
- 用户主动要求"推送学习内容"或"学下一节"
- 补救内容安排（掌握度未达标后触发）
- 用户针对某个知识点提问时，临时生成补充文档

## 数据路径约定

- 计划：`data/<studentId>/plans/<subjectId>.yaml`
- 知识树：`data/<studentId>/<subjectId>.yaml`
- 掌握度：`data/<studentId>/mastery.json`
- 内容日志：`data/<studentId>/content-log.jsonl`
- 内容文件：`data/<studentId>/content/<nodeId>-<seq>.md`
- **对话笔记**：`data/<studentId>/session-notes.yaml`
- 内容模板：`templates/content-template.md`
- 卡片模板：`templates/message-card.json`

## 内容生成流程

### 第 1 步：确定推送节点
1. 读取计划文件，找到下一个 scheduledAt <= 当前时间 且 status = "scheduled" 的 session
2. 如果多个科目都有待推送，按优先级排序（截止日期近的优先）
3. 如果所有 session 都已完成，检查是否有待回顾的节点
4. 如果用户手动指定节点，直接使用指定节点

### 第 2 步：读取上下文
1. 从知识树中读取该节点的 title、description、level、prerequisites、estimatedMinutes
2. 从掌握度中读取该节点的 masteryLevel
3. 从内容日志中计算该用户的学习速度指标
4. 根据学习速度确定内容生成策略
5. 如果有前置节点未完成，读取前置节点内容摘要
6. 读取 `session-notes.yaml`，检查是否有适用于当前节点的对话衍生需求

### 第 3 步：联网检索（收集素材）

**必须搜索，不能凭记忆生成。**

**基础搜索：** 节点 title（中文 + 英文）
**深度搜索（level >= 1 或 estimatedMinutes > 30）：** + "教程"/"常见错误"/"实际案例"
**考试类科目额外：** + "考点"/"历年真题"/"公式定义"

### 第 4 步：生成学习材料（教材）

> 内容格式模板见 `templates/content-template.md`，必须包含其中全部小节。

> 🚨 **强制：生成前读取前置节点摘要**
>
> 生成新节点教材前，**必须**执行以下步骤：
> 1. 读取 `data/<studentId>/content-summaries.jsonl`（如存在）
> 2. 筛选当前节点 `prerequisites`（前置节点）对应的摘要
> 3. 筛选当前节点 `nextNodes`（后续节点）对应的摘要（如有）
> 4. 将摘要注入教材生成上下文：
>    - **开头衔接**：用 1-2 句话回顾前置节点核心概念（"上一节我们学了 X..."）
>    - **知识递进**：基于前置节点知识深入，不重复已讲内容
>    - **结尾铺垫**：为后续节点埋引子（"下一节我们将基于 X 来探讨 Y"）
> 5. 如果 `content-summaries.jsonl` 不存在或无匹配摘要，正常生成即可（首节课无需衔接）

**不是搜索结果的简单拼接，而是基于检索素材重新创作的完整学习材料。**

生成原则：准确性优先 → 结构化 → 渐进式 → 举例说明 → 联系实际 → 语言简洁 → 足够长

**生成时必须满足 session-notes 中的适用需求**（如用户要求多用电商案例、要求分步讲解等）。

### 第 5 步：更新 session-notes

内容生成后，检查本次对话中是否产生了需要持久化的信息，如果有则写入 `session-notes.yaml`：

```yaml
# 需要写入 session-notes 的场景：
# - 用户在本轮对话中表达了新的偏好（如"多用案例"、"讲慢一点"）
# - 发现了之前内容中的错误并修正
# - 用户调整了学习计划或范围
# - 观察到了学习状态变化（如用户对某概念困惑）
```

> 格式见 `templates/session-notes-template.yaml`

### 第 6 步：派发 Audit Agent 审计

**将生成物派发给独立的 Audit Agent 进行审计。**

**审计前告知用户**："开始审计，预计需要 5-10 分钟，请稍候"

调用方式（同步阻塞）：
```json
sessions_send({
  "agentId": "intelligent-learning-audit",
  "message": "审计类型: content\n目标: <nodeId>\n学生: <studentId>\n生成物:\n<artifact内容>",
  "timeoutSeconds": 600
})
```

派发内容：
```yaml
auditType: "content"
targetId: "<当前 nodeId>"
studentId: "<studentId>"
artifact: "<生成的完整学习内容>"
```

**不传递**：生成推理过程、自适应分析结论、对话历史。

审计结果处理：
- **verdict = "passed"** → 通知用户审计通过，进入第 7 步（写飞书文档）
- **verdict = "passed_with_notes"** → 通知用户审计通过但附带建议，进入第 7 步，推送时附带 soft 建议标记
- **verdict = "not_passed" 且 retryCount < 3** → 通知用户"审计发现问题，正在修复中"，根据 fixAction 修复（仅 fixableByMain: true 的项），重新 sessions_send 审计
- **verdict = "user_arbitration"（重试 3 次后）** → 向用户展示完整审计反馈，等待裁决（接受/修改/重新生成/跳过）
- **超时或 Audit Agent 不可用** → 降级为本地审计（在同一上下文中执行检查项 1-7），记录降级事件

**审计结果必须通知用户**（通过飞书消息），格式：
```
✅ 内容审计通过 | ⚠️ 审计通过（有建议） | 🔧 审计未通过，修复中 | ❓ 需要你的确认

审计摘要：
• 通过 N 项 / 共 M 项
• soft 建议：（如有）
```

审计结果保存到 `data/<studentId>/audit/content-<nodeId>-<timestamp>.json`

### 第 7 步：写入飞书文档（必须执行）

**严禁跳过此步骤直接在聊天中发送内容。**

**开启新学科时**，必须先在飞书创建知识库文件夹（由 `learning-feishu-sync` 初始化）。

**文档命名规则：** `[科目] 第X节 - [节点标题]`

**写入方式：** 调用 `feishu_create_doc`（传入 Markdown + folder_token），失败则最多重试 1 次。

### 第 8 步：推送消息卡片（必须执行）

> 卡片 JSON 模板见 `templates/message-card.json`

通过飞书发送交互卡片，包含"已完成"和"有疑问"按钮。

### 第 9 步：处理用户交互

**"已完成" 按钮：** 更新 session 状态 → 记录日志 → 触发随堂小测 → 推送下一条
**"有疑问" 按钮：** 引导提问 → 解答 → 补充飞书文档

**用户反馈写入 session-notes**：如果用户在交互中表达了偏好或纠正了错误，立即更新 `session-notes.yaml`。

### 第 10 步：保存本地副本

1. 保存内容到 `data/<studentId>/content/<nodeId>-<seq>.md`
2. 追加记录到 `data/<studentId>/content-log.jsonl`
3. 更新计划中该 session 的 status 为 "delivered"
4. **生成内容摘要**，追加到 `data/<studentId>/content-summaries.jsonl`：

```json
{
  "nodeId": "<nodeId>",
  "subjectId": "<subjectId>",
  "title": "<节点标题>",
  "summary": "<100-200 字摘要，概括本节核心概念和关键知识点>",
  "keyConcepts": ["概念1", "概念2", "概念3"],
  "prerequisites": ["前置nodeId1", "前置nodeId2"],
  "nextNodes": ["后续nodeId1"],
  "generatedAt": "<ISO timestamp>"
}
```

此摘要将在后续节点生成教材时被读取（第 4 步），确保跨节课的知识连贯性。

## 飞书文档创建失败处理

1. 调用 `feishu_create_doc` 尝试创建文档
2. 如果失败，捕获错误信息
3. 保存完整内容到本地文件
4. 通过 `feishu_im_user_message` 发送简短通知（NOT 完整内容）
5. 记录到 content-log.jsonl，action 为 "doc_failed_auth"
6. **最多重试 1 次**