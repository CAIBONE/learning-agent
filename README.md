# 学吧 — AI 智能学习助手

## 定位

帮助用户根据学习需求规划学习任务，生成学习内容，测验学习成果，生成复盘报表。支持考试备考、技能学习、语言学习等多种目标类型。

## 核心能力（11 大 SKILL，多 Agent 架构）

| # | SKILL | 说明 |
|---|-------|------|
| 1 | `learning-core` | 核心引擎 — 路由、多 Agent 架构、Session Notes 机制、闭环驱动、数据持久化、学生身份映射 |
| 2 | `learning-goals` | 目标拆解 — **二分法自适应**（有标准型/无标准型）+ 项目引导 + 里程碑验收 |
| 3 | `learning-knowledge-tree` | 知识图谱 — 三级结构 + **6 步语义验证** + JSON Schema 验证 → ⚡派发审计 |
| 4 | `learning-plan` | 学习计划 — YAML Schema + 艾宾浩斯复习 + 量化动态调整 + 考前冲刺 |
| 5 | `learning-content` | 内容生成 — 联网检索 + 深度教材 + 飞书文档 + 自适应策略 → ⚡派发审计 |
| 6 | `learning-quiz` | 测验评估 — 5 种测验类型 + 题量评估算法 + 错题管理 → ⚡派发审计 |
| 7 | `learning-audit` ⚡ | **独立审计 Agent** — 隔离上下文，独立质量检查（知识图谱/内容/题目） |
| 8 | `learning-review` | 学习复盘 — 独立复盘模块，数据→洞察→行动 |
| 9 | `learning-reports` | 可视化报表 — 引用飞书多维表格 Dashboard（折线图/柱状图/饼图）+ 聊天摘要 |
| 10 | `learning-cron` | 定时任务 — **多学生隔离** + 创建/更新/删除自动化 cron 任务 |
| 11 | `learning-feishu-sync` | 飞书同步 — 知识库备份 + 多维表格数据库 + 视图/仪表盘创建维护 |

## 目录结构

```
learning-agent/
├── README.md                     # 本文件
├── AGENTS.md                     # Agent 工作区规范
├── .gitignore
├── setup.sh                      # 一键部署脚本
├── openclaw-config-patch.json    # 配置模板（不含密钥）
├── docs/
│   ├── DEPLOY-PROMPT.md          # AI 工具部署提示词（喂给 AI 即可自动部署）
│   ├── USAGE.md                  # 使用指南
├── agent/
│   ├── agent.json                # Agent 元数据配置
│   └── SKILL.md                  # 技能路由（人格由 SOUL.md 定义）
└── workspace/
    ├── IDENTITY.md             # Agent 身份定义
    ├── SOUL.md                 # Agent 人格、教学风格、首次回复规则
    ├── templates/              # 独立模板文件（从 SKILL.md 拆出）
    │   ├── plan-schema.yaml        # 学习计划完整 YAML Schema 示例
    │   ├── content-template.md     # 学习内容格式模板
    │   ├── session-notes-template.yaml  # 对话笔记模板（审计 + 上下文恢复）
    │   ├── message-card.json       # 飞书消息卡片 JSON 模板
    │   └── feishu-scopes.json      # 飞书 OAuth 完整权限范围（180+ scope）
    └── skills/
        └── learning/
            ├── learning-core/          # 核心引擎（多 Agent 架构 + Session Notes）
            ├── learning-goals/         # 学习目标管理（含飞书权限预检）
            ├── learning-knowledge-tree/# 知识图谱（含 6 步语义验证 → ⚡派发审计）
            ├── learning-plan/          # 学习计划（含动态调整 + 量化算法）
            ├── learning-content/       # 内容生成与推送（→ ⚡派发审计）
            ├── learning-quiz/          # 测验评估（→ ⚡派发审计）
            ├── learning-audit/         # ⚡独立审计 Agent（隔离上下文）
            ├── learning-reports/       # 可视化报表（飞书多维表格）
            ├── learning-review/        # 学习复盘（独立模块）
            ├── learning-cron/          # 定时任务管理（多学生隔离）
            └── learning-feishu-sync/   # 飞书知识库+多维表格同步
```

## 前置依赖

| # | 依赖项 | 检查方式 | 不满足时 |
|---|--------|---------|---------|
| 1 | **飞书官方插件** | `openclaw plugins list \| grep lark` | `npx -y @larksuite/openclaw-lark install` |
| 2 | 飞书自建应用（App ID + Secret） | 用户提供 | 到 [open.feishu.cn](https://open.feishu.cn/app) 创建 |
| 3 | 推理模型 | 检查 openclaw.json 中是否有 `"reasoning": true` 的模型 | 在 openclaw.json 中增加支持深度思考的推理模型并设为学吧的模型 |

> ⚡ 飞书官方插件（`@larksuite/openclaw-lark`）是必须的前置依赖，需在部署 Agent 前安装。

## 快速部署

### 方式一：让 AI 工具自动部署（推荐）

> 将下方整段提示词复制到  Openclaw / Hermes Agent  的聊天框，AI 会自主完成全部部署。

```
请读取 https://github.com/CAIBONE/learning-agent/blob/main/docs/DEPLOY-PROMPT.md 中的四段式部署指令（前置依赖 → 拉取项目 → 执行动作 → 注意事项），并按步骤自动完成部署。

推荐接入推理模型。

```

### 方式二：使用部署脚本

```bash
# 在 OpenClaw 服务器上运行
cd ~/
git clone https://github.com/CAIBONE/learning-agent.git
cd learning-agent
bash setup.sh
```

> 脚本自动完成 Agent 注册和文件复制，但仍需手动配置飞书凭证和模型（参见 `docs/DEPLOY-PROMPT.md`）。

### 方式三：手动部署

```bash
# 1. 复制 Agent 文件
cp -r agent/ ~/.openclaw/agents/intelligent-learning-assistant/

# 2. 复制 Workspace 文件
cp -r workspace/ ~/.openclaw/workspace-intelligent-learning-assistant/

# 3. 在 openclaw.json 中添加 Agent（参考 openclaw-config-patch.json）
```

### 接入飞书渠道

在 `openclaw.json` 中添加：

```json
{
  "channels": {
    "feishu": {
      "accounts": {
        "intelligent-learning": {
          "appId": "YOUR_APP_ID",
          "appSecret": "YOUR_APP_SECRET",
          "enabled": true,
          "streaming": true,
          "uat": {
            "ownerOnly": false
          }
        }
      }
    }
  },
  "bindings": [
    {
      "agentId": "intelligent-learning-assistant",
      "match": {
        "channel": "feishu",
        "accountId": "intelligent-learning"
      }
    }
  ]
}
```

> **重要**：`streaming: true` 开启流式输出，用户可实时看到 Agent 回复，体验显著改善。`ownerOnly: false` 允许多人使用，学吧支持多用户。

### 配置模型

**推荐使用推理模型**（`"reasoning": true`），学吧的知识图谱生成、内容审计、题目验证等核心任务对推理能力要求很高：

```json
{
  "agents": {
    "list": [{
      "id": "intelligent-learning-assistant",
      "model": {
        "primary": "你的推理模型标识",
        "reasoning": true
      }
    }]
  }
}
```

> `learning-audit` 和 `learning-quiz` 两个技能必须使用推理模型，否则会出现"自己出题自己错"的问题。

然后重启网关：

```bash
openclaw gateway restart
```

### 初始化飞书同步（可选）

部署完成后，在飞书对话中对 Agent 说"我想学 XXX"，Agent 会：
1. 捕获学习目标
2. **一次性申请全部飞书权限**（完整 scope 清单见 `workspace/templates/feishu-scopes.json`，涵盖文档/多维表格/知识库/云空间/消息/通讯录/日历/任务等 180+ scope）
3. 初始化飞书知识库空间和多维表格数据库
4. 生成知识图谱和学习计划

> 飞书权限在项目创建时一次性申请，后续使用中不再重复请求授权。

## 飞书多维表格数据库

同步后，过程数据存储在飞书多维表格中：

| 数据表 | 用途 |
|--------|------|
| 知识节点表 | 知识图谱结构 + 掌握度 + 状态 |
| 学习记录表 | 每次学习的时长、效率、自评 |
| 测验记录表 | 每次测验的成绩、掌握度变化 |
| 错题本表 | 错题管理 + 间隔复习计划 |
| 掌握度追踪表 | 掌握度时间序列（趋势图数据源）|

报表利用多维表格内置图表功能（折线图/柱状图/饼图/看板）生成 Dashboard，初始化时自动创建 7 个命名视图 + 1 个仪表盘。

## 配置要求

- **模型**: 推荐使用推理模型（`"reasoning": true`），在 openclaw.json 中配置
- **流式输出**: 飞书渠道必须开启 `streaming: true`
- **工具**: 飞书全套工具（文档、多维表格、知识库、消息、日历、任务等）
- **渠道**: 飞书 WebSocket 长连接

## 使用指南

详见 [docs/USAGE.md](docs/USAGE.md) — 从快速上手到多科目并行、考前冲刺、定时任务调整的完整使用文档。

## 许可证

MIT
