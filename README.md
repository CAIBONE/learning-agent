# 学吧 — AI 智能学习助手

## 定位

帮助用户根据学习需求规划学习任务，生成学习内容，测验学习成果，生成复盘报表。支持考试备考、技能学习、语言学习等多种目标类型。

## 核心能力（双 Agent 架构）

### Main Agent（学吧）— 10 个 Skill

| # | SKILL | 说明 |
|---|-------|------|
| 1 | `learning-core` | 核心引擎 — 路由、Session Notes 机制、闭环驱动、数据持久化、学生身份映射 |
| 2 | `learning-goals` | 目标拆解 — **二分法自适应**（有标准型/无标准型）+ 项目引导 + 里程碑验收 |
| 3 | `learning-knowledge-tree` | 知识图谱 — 三级结构 + **6 步语义验证** + JSON Schema 验证 → ⚡派发审计 |
| 4 | `learning-plan` | 学习计划 — YAML Schema + 艾宾浩斯复习 + 量化动态调整 + 考前冲刺 |
| 5 | `learning-content` | 内容生成 — 联网检索 + 深度教材 + 飞书文档 + 自适应策略 → ⚡派发审计 |
| 6 | `learning-quiz` | 测验评估 — 5 种测验类型 + 题量评估算法 + 错题管理 → ⚡派发审计 |
| 7 | `learning-review` | 学习复盘 — 独立复盘模块，数据→洞察→行动 |
| 8 | `learning-reports` | 可视化报表 — 引用飞书多维表格 Dashboard（折线图/柱状图/饼图）+ 聊天摘要 |
| 9 | `learning-cron` | 定时任务 — **多学生隔离** + 创建/更新/删除自动化 cron 任务 |
| 10 | `learning-feishu-sync` | 飞书同步 — 知识库备份 + 多维表格数据库 + 视图/仪表盘创建维护 |

### Audit Agent（审计官）— 1 个 Skill

| # | SKILL | 说明 |
|---|-------|------|
| 1 | `learning-audit` ⚡ | **独立审计 Agent** — 隔离上下文，同步阻塞调用，独立质量检查（知识图谱/内容/题目/学习量） |

### 跨 Agent 调用机制

- **Main Agent** 通过 `sessions_send`（同步阻塞）调用 **Audit Agent**
- `timeoutSeconds: 600`（10 分钟），审计期间 Main Agent 等待结果
- 审计结果自动返回 Main Agent，Main Agent 根据 verdict 决定是否修复重试
- 重试上限 3 次，超过则提交用户裁决

## 目录结构

```
learning-agent/
├── README.md                     # 本文件
├── AGENTS.md                     # Agent 工作区规范
├── .gitignore
├── setup.sh                      # 一键部署脚本（双 Agent）
├── openclaw-config-patch.json    # 配置模板（双 Agent + subagents 权限）
├── docs/
│   ├── DEPLOY-PROMPT.md          # AI 工具部署提示词
│   ├── USAGE.md                  # 使用指南
│   └── INTRODUCTION.md           # 项目介绍
├── agent/
│   ├── main/                     # Main Agent（学吧）
│   │   ├── agent.json            # Agent 元数据（10 skills + sessions_send）
│   │   └── SKILL.md              # 技能路由入口
│   └── audit/                    # Audit Agent（审计官）
│       ├── agent.json            # Agent 元数据（1 skill）
│       └── SKILL.md              # 审计入口 + 派发协议
└── workspace/
    ├── main/                     # Main Agent 专属 workspace
    │   ├── IDENTITY.md           # Agent 身份定义
    │   ├── SOUL.md               # Agent 人格、教学风格、首次回复规则
    │   ├── data/                 # 学生数据（profile/progress/audit 记录）
    │   ├── templates/            # 模板文件
    │   │   ├── plan-schema.yaml
    │   │   ├── content-template.md
    │   │   ├── session-notes-template.yaml
    │   │   ├── message-card.json
    │   │   └── feishu-scopes.json
    │   └── skills/
    │       └── learning/
    │           ├── learning-core/
    │           ├── learning-goals/
    │           ├── learning-knowledge-tree/
    │           ├── learning-plan/
    │           ├── learning-content/
    │           ├── learning-quiz/
    │           ├── learning-reports/
    │           ├── learning-review/
    │           ├── learning-cron/
    │           └── learning-feishu-sync/
    └── audit/                    # Audit Agent 专属 workspace
        ├── IDENTITY.md           # 审计官身份
        ├── SOUL.md               # 审计官人格
        └── skills/
            └── learning/
                └── learning-audit/   # 审计技能
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

> 将下方整段提示词复制到 OpenClaw / Hermes Agent 的聊天框，AI 会自主完成全部部署。

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

> 脚本自动完成双 Agent 注册和文件复制，但仍需手动配置飞书凭证和模型。

### 方式三：手动部署

```bash
# 1. 复制 Main Agent
cp -r agent/main/ ~/.openclaw/agents/intelligent-learning-assistant/

# 2. 复制 Audit Agent
cp -r agent/audit/ ~/.openclaw/agents/intelligent-learning-audit/

# 3. 复制 Main workspace
cp -r workspace/main/ ~/.openclaw/workspace-main/

# 4. 复制 Audit workspace
cp -r workspace/audit/ ~/.openclaw/workspace-audit/

# 5. 合并 openclaw-config-patch.json 到 ~/.openclaw/openclaw.json
```

### 接入飞书渠道

在 `openclaw.json` 中添加（参考 `openclaw-config-patch.json`）：

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

> **重要**：`streaming: true` 开启流式输出，用户可实时看到 Agent 回复。只有 Main Agent 绑定飞书渠道，Audit Agent 通过 `sessions_send` 被 Main Agent 调用。

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

然后重启网关：

```bash
openclaw gateway restart
```

### 初始化飞书同步（可选）

部署完成后，在飞书对话中对 Agent 说"我想学 XXX"，Agent 会：
1. 捕获学习目标
2. 一次性申请飞书权限（完整 scope 清单见 `workspace/main/templates/feishu-scopes.json`）
3. 初始化飞书知识库空间和多维表格数据库
4. 生成知识图谱和学习计划

## 飞书多维表格数据库

同步后，过程数据存储在飞书多维表格中：

| 数据表 | 用途 |
|--------|------|
| 知识节点表 | 知识图谱结构 + 掌握度 + 状态 |
| 学习记录表 | 每次学习的时长、效率、自评 |
| 测验记录表 | 每次测验的成绩、掌握度变化 |
| 错题本表 | 错题管理 + 间隔复习计划 |
| 掌握度追踪表 | 掌握度时间序列（趋势图数据源）|

报表利用多维表格内置图表功能生成 Dashboard。

## 配置要求

- **模型**: 推荐使用推理模型（`"reasoning": true`）
- **流式输出**: 飞书渠道必须开启 `streaming: true`
- **工具**: 飞书全套工具 + `sessions_send`（跨 Agent 调用）
- **渠道**: 飞书 WebSocket 长连接

## 使用指南

详见 [docs/USAGE.md](docs/USAGE.md) — 从快速上手到多科目并行、考前冲刺、定时任务调整的完整使用文档。

## 许可证

MIT
