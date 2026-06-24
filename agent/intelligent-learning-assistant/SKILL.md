# Intelligent Learning Assistant — 技能路由

> 人格定义、教学风格、首次回复规则见 `SOUL.md`。
> 本文件仅定义工作流路由和数据组织方式。

## 工作流总览

本 Agent 通过 10 个内置 skill + 1 个独立 Audit Agent 驱动完整学习闭环：**规划→生成→审计→测验→审计→调整→复盘**。

| 步骤 | 调用 Skill / Agent | 职责 |
|------|-----------|------|
| 目标设定 | `learning-goals` | 对话式捕获目标 + 飞书权限预检，写入 goals.yaml |
| 知识树生成 | `learning-knowledge-tree` | 从目标生成知识树 + 语义验证 → ⚡派发审计 |
| 学习计划 | `learning-plan` | 从知识树+目标生成计划 + 动态调整，写入 plans/ |
| 内容推送 | `learning-content` | 生成教材 + 写飞书文档 + 消息卡片推送 → ⚡派发审计 |
| 测验评估 | `learning-quiz` | 生成测验题 + 交互式答题 + 评分 → ⚡派发审计 |
| **质量审计** | **`learning-audit`** ⚡独立 Agent | **知识图谱/内容/题目的独立质量检查** |
| 学习复盘 | `learning-review` | 独立复盘模块，数据→洞察→行动 |
| 报表生成 | `learning-reports` | 飞书多维表格 Dashboard + 聊天摘要 |
| 定时任务 | `learning-cron` | 创建/更新/删除自动化 cron 任务（按学生隔离） |
| 飞书同步 | `learning-feishu-sync` | 学习档案同步到飞书知识库+多维表格数据库 |

## 工作流阶段

### 阶段 1：学习目标拆解与路径规划
**触发**：用户表达学习意愿 → `learning-goals` → `learning-knowledge-tree` → ⚡审计 → `learning-plan`

### 阶段 2：学习内容生成与推送
**触发**：cron 定时 / 用户请求 → `learning-content` → ⚡审计 → 飞书文档 + 消息卡片

### 阶段 3：阶段测验与评估
**触发**：内容完成 / 定期 / 用户要求 → `learning-quiz` → ⚡审计 → 评分 + 错题管理

### 阶段 4：动态调整学习规划
**触发**：测验后 / 复盘后 → `learning-plan` 调整 → `learning-cron` 更新

### 阶段 5：可视化报表与复盘
**触发**：每周五 / 每月 / 用户请求 → `learning-reports` + `learning-review`

## 多 Agent 架构

```
┌─────────────────────────────────────────────────┐
│              学吧 Main Agent                      │
│  (intelligent-learning-assistant)                │
│  内置 10 个 Skill，保持对话历史，负责生成和交互      │
│  生成完成 → 写 session-notes → 派发 Audit Agent    │
└──────────────────────┬──────────────────────────┘
                       │ 跨 Agent 调用
                       ▼
         ┌──────────────────────────┐
         │   Audit Agent             │
         │   (intelligent-learning-audit)
         │   独立上下文              │
         │   看不到生成推理过程       │
         │   自主读取数据文件审计      │
         └──────────────────────────┘
```

**为什么要拆**：既当运动员又当裁判会出问题。Audit Agent 在独立上下文中运行，只看到生成物、数据文件和 session-notes，确保审计客观性。

**Agent 配置**：
- Main Agent: `agent/intelligent-learning-assistant/agent.json` — 加载 10 个 skill（不含 learning-audit）
- Audit Agent: `agent/intelligent-learning-audit/agent.json` — 只加载 learning-audit

**派发协议**：

Main Agent 生成完成后，向 Audit Agent 发送：

```yaml
auditType: "content | quiz | knowledge_tree | volume"
targetId: "<nodeId 或 subjectId>"
studentId: "<studentId>"
artifact: "<生成物的完整内容>"
```

**不传递**：生成推理过程、Main Agent 的自适应分析结论、对话历史。

**Session Notes**：对话中产生的关键信息（用户偏好、纠错、状态变化）持久化到 `session-notes.yaml`，供 Audit Agent 审计和下次会话恢复上下文。

**OpenClaw 配置**：需要在 `openclaw.json` 中注册两个 Agent，详见 `docs/DEPLOY-PROMPT.md`。

## 补充能力

- **费曼学习法模式**：用户尝试解释概念 → 识别模糊点 → 针对性补充 → 循环至完全理解
- **学习伙伴系统**：支持多科目/多目标并行管理，跨科目知识关联提醒
- **考前冲刺模式**：距截止日期 ≤ 14 天自动切换，聚焦高频考点，增加模拟频率

## 数据组织

详见 `learning-core/SKILL.md` 中的数据持久化定义。

## 交互格式

- 推送卡片格式：见 `templates/message-card.json`
- 学习内容模板：见 `templates/content-template.md`
- Session Notes 模板：见 `templates/session-notes-template.yaml`
- 测验交互格式：见 `learning-quiz/SKILL.md`

---

*创建日期：2026-06-14*
*更新日期：2026-06-20*
*版本：2.1*
*定位：Intelligent Learning Assistant — 技能路由 + 多 Agent 架构（人格由 SOUL.md 定义）*