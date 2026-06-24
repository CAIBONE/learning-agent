# 学吧 Agent 部署提示词

## 一、前置依赖

> 在执行任何部署动作之前，以下环境必须就绪。逐项检查，缺失则先安装。

### 1.1 飞书官方插件

> **关键前置条件。** OpenClaw 通过飞书官方插件接入飞书渠道，必须在部署 Agent 前安装。

```
检查命令：openclaw plugins list | grep lark
预期输出：包含 @larksuite/openclaw-lark 插件
若未安装：
  npx -y @larksuite/openclaw-lark install
安装后验证：
  openclaw plugins list | grep lark
```

### 1.2 飞书应用（在飞书开放平台创建）

> 需要用户在飞书开放平台创建一个企业自建应用，获取 App ID 和 App Secret。

```
操作地址：https://open.feishu.cn/app
必须完成：
  1. 创建企业自建应用 → 记录 App ID 和 App Secret
  2. 开启机器人能力（应用功能 → 机器人）
  3. 配置权限（权限管理 → 参考 workspace/intelligent-learning-assistant/templates/feishu-scopes.json 中的 180+ scope）
     核心权限分类：
     - 文档：docx:document, docs:document.*
     - 多维表格：base:*, bitable:*
     - 知识库：wiki:*
     - 云空间：drive:*
     - 消息：im:message, im:chat
     - 通讯录：contact:*
     - 日历：calendar:*
     - 任务：task:*
     - 搜索：search:*
  4. 发布应用版本（版本管理 → 创建版本 → 申请发布）
  5. 记录以下变量，后续步骤使用：
     FEISHU_APP_ID=<App ID>
     FEISHU_APP_SECRET=<App Secret>
```

### 1.3 推理模型 API 接入

> 学吧的核心任务（知识图谱审计、题目验证、内容交叉验证）依赖深度推理能力，必须配置推理模型。

```bash
# 查看当前环境中有无推理模型
openclaw models list
# 或检查 openclaw.json 中 reasoning 字段
grep -B2 -A2 '"reasoning"' ~/.openclaw/openclaw.json
```

- ✅ 找到 `"reasoning": true` 的模型 → 记录该模型 ID，后续设为学吧主模型
- ❌ 未找到 → 告诉用户：「学吧的知识图谱审计、题目验证、内容交叉验证等核心任务依赖深度推理能力，必须配置支持深度思考的推理模型（thinking/reasoning model）。请在 openclaw.json 中增加一个 `"reasoning": true` 的模型并设为学吧的主模型。」

请确认用户有可用推理模型后再继续。

### 1.4 依赖检查汇总

| # | 依赖项 | 检查方式 | 不满足时 |
|---|--------|---------|---------|
| 1 | 飞书官方插件 | `openclaw plugins list \| grep lark` | `npx -y @larksuite/openclaw-lark install` |
| 2 | 飞书应用 (App ID + Secret) | 用户提供 | 引导用户到 open.feishu.cn 创建 |
| 3 | 推理模型（`reasoning: true`） | `openclaw models list` | 配置模型提供商 API Key |

**所有依赖就绪后，方可进入第二步。**

---

## 二、拉取项目

### 2.1 克隆仓库

```bash
cd ~
git clone https://github.com/CAIBONE/learning-agent.git
cd learning-agent
```

### 2.2 项目文件结构

```
learning-agent/                                      # 仓库根目录
├── setup.sh                                         # 一键部署脚本（自动完成步骤 3.1 + 3.2）
├── openclaw-config-patch.json                       # Agent 注册 + 渠道 + 绑定配置模板
├── agent/
│   ├── intelligent-learning-assistant/              # Main Agent 源文件（学吧）
│   │   ├── agent.json                               # Agent 元数据（10 个技能、工具白名单、subagents）
│   │   └── SKILL.md                                 # 技能路由表 + 多 Agent 架构说明
│   └── intelligent-learning-audit/                  # Audit Agent 源文件（审计官）
│       ├── agent.json                               # Agent 元数据（1 个技能）
│       └── SKILL.md                                 # 审计入口 + 派发协议
└── workspace/
    ├── intelligent-learning-assistant/              # Main Agent 工作区源文件
    │   ├── IDENTITY.md                              # Agent 身份卡
    │   ├── SOUL.md                                  # Agent 人格（苏格拉底式教学 + 费曼法 + 数据驱动）
    │   ├── templates/
    │   │   ├── plan-schema.yaml                     # 学习计划 YAML Schema
    │   │   ├── content-template.md                  # 学习内容格式模板
    │   │   ├── message-card.json                    # 飞书消息卡片模板
    │   │   ├── feishu-scopes.json                   # 飞书 OAuth 完整权限范围（180+ scope）
    │   │   └── session-notes-template.yaml          # 会话笔记模板（跨 Agent 上下文桥接）
    │   └── skills/learning/                         # 10 个技能模块（详见 README.md）
    └── intelligent-learning-audit/                  # Audit Agent 工作区源文件
        ├── IDENTITY.md                              # 审计官身份卡
        ├── SOUL.md                                  # 审计官人格（独立、客观、严格）
        └── skills/learning/
            └── learning-audit/SKILL.md              # 审计规则（知识图谱/内容/题目/学习量）
```

---

## 三、执行动作

> 以下动作按顺序执行。可优先使用 `setup.sh` 自动完成 3.1 和 3.2。

### 3.1 运行部署脚本（创建目录 + 复制文件 + 注册 Agent）

```bash
bash setup.sh
```

脚本自动完成以下操作：

**创建目录**（注意目标目录名与 agent ID 保持一致）：
```
~/.openclaw/agents/intelligent-learning-assistant/agent/    ← Main Agent 配置
~/.openclaw/agents/intelligent-learning-audit/agent/        ← Audit Agent 配置
~/.openclaw/workspace-intelligent-learning-assistant/       ← Main 工作区
~/.openclaw/workspace-intelligent-learning-audit/           ← Audit 工作区
```

**复制文件**：
- `agent/intelligent-learning-assistant/` → `~/.openclaw/agents/intelligent-learning-assistant/agent/`
- `agent/intelligent-learning-audit/` → `~/.openclaw/agents/intelligent-learning-audit/agent/`
- `workspace/intelligent-learning-assistant/` → `~/.openclaw/workspace-intelligent-learning-assistant/`
- `workspace/intelligent-learning-audit/` → `~/.openclaw/workspace-intelligent-learning-audit/`

**注册 Agent**：调用 `openclaw agents add` 注册两个 Agent

**验证：**
```bash
openclaw agents list
# 预期输出包含：
# intelligent-learning-assistant（Main Agent，10 个 skills）
# intelligent-learning-audit（Audit Agent，1 个 skill）
```

### 3.2 合并配置到 openclaw.json

> 如果 setup.sh 已自动注册，此步可跳过配置合并，但仍需手动补充飞书凭证和模型。

将 `openclaw-config-patch.json` 中的内容合并到 OpenClaw 配置（通常位于 `~/.openclaw/openclaw.json`）：

```bash
# 方式一：CLI 合并（如支持）
openclaw config merge --patch openclaw-config-patch.json

# 方式二：手动编辑 openclaw.json，将 patch 中的三个部分合并进去
```

需要合并的三个部分：

**① agents.list — 追加两个 Agent 定义**

```jsonc
// Main Agent（学吧）— 10 个 skills，负责生成和交互
{
  "id": "intelligent-learning-assistant",
  "name": "学吧",
  "workspace": "./workspace-intelligent-learning-assistant",
  "agentDir": "./agents/intelligent-learning-assistant/agent",
  "model": { "primary": "<你的推理模型 ID>" },  // ← 替换为实际推理模型
  "skills": [ "learning-core", "learning-goals", "learning-knowledge-tree",
              "learning-plan", "learning-content", "learning-quiz",
              "learning-reports", "learning-review", "learning-cron",
              "learning-feishu-sync" ],
  "tools": {
    "subagents": {
      "allowAgents": ["intelligent-learning-audit"]   // ← 允许调用审计 Agent
    },
    "alsoAllow": [ "sessions_send", "cron_create", ... 30+ 飞书工具 ... ]
  }
}

// Audit Agent（审计官）— 1 个 skill，独立上下文审计
{
  "id": "intelligent-learning-audit",
  "name": "学习审计 Agent",
  "workspace": "./workspace-intelligent-learning-audit",
  "agentDir": "./agents/intelligent-learning-audit/agent",
  "model": { "primary": "<你的推理模型 ID>" },  // ← 同样使用推理模型
  "skills": ["learning-audit"]
}
```

> **注意**：
> - 以上路径均相对于 `~/.openclaw/` 目录
> - `model.primary` 必须使用 `reasoning: true` 的推理模型（如 `glm-5.2`、`bailian-thinking/qwen3.7-plus` 等）
> - `tools.subagents.allowAgents` 必须包含 `intelligent-learning-audit`，否则 Main Agent 无法向 Audit Agent 派发审计任务

**② channels.feishu.accounts — 追加飞书渠道账号**
```json
{
  "intelligent-learning": {
    "appId": "<FEISHU_APP_ID>",
    "appSecret": "<FEISHU_APP_SECRET>",
    "enabled": true,
    "streaming": true,
    "uat": { "ownerOnly": false }
  }
}
```

**③ bindings — 追加绑定关系**
```json
{
  "agentId": "intelligent-learning-assistant",
  "match": { "channel": "feishu", "accountId": "intelligent-learning" }
}
```

### 3.3 配置模型

检查当前环境中可用的推理模型：

```bash
# 列出所有模型，找 reasoning: true 的
openclaw models list
# 或直接查看配置
cat ~/.openclaw/openclaw.json | python3 -c "
import sys,json
c=json.load(sys.stdin)
for p,v in c.get('models',{}).get('providers',{}).items():
    for m in v.get('models',[]):
        if m.get('reasoning'):
            print(f'{p}/{m[\"id\"]}')"
```

将找到的推理模型设为两个 Agent 的主模型：

```jsonc
// 在 agents.list 中两个 agent 的条目里设置
"model": { "primary": "<推理模型 ID>" }
```

### 3.4 重启网关

```bash
openclaw gateway restart
# 或
systemctl restart openclaw
```

### 3.5 验证部署

在飞书中找到机器人，发送：

```
你好
```

**预期响应：** Agent 回复自我介绍（"你好！我是你的智能学习助手 🧠📚"）。

再发送：

```
我想学 Python，零基础，3 个月内能做一些小项目
```

**预期行为：**
1. Agent 判断为**无标准型**目标（项目驱动）
2. 询问工作场景和兴趣方向
3. 联网推荐具体项目

**验证飞书同步：** 创建学习项目后，检查飞书中是否自动生成了：
- 知识库目录结构（学科目录 + 知识图谱文档）
- 多维表格「学习数据中心」（5 张数据表 + 7 个命名视图 + 1 个仪表盘）

---

## 四、双 Agent 架构说明

```
┌─────────────────────────────────────────────┐
│           Main Agent（学吧 📚）               │
│  intelligent-learning-assistant              │
│  10 个 Skill · 保持对话历史 · 负责生成和交互   │
│  生成完成 → 写 session-notes → 派发审计       │
└────────────────────┬────────────────────────┘
                     │ sessions_send（同步阻塞）
                     ▼
       ┌──────────────────────────┐
       │  Audit Agent（审计官 🔍） │
       │  intelligent-learning-audit
       │  1 个 Skill · 独立上下文  │
       │  看不到生成推理过程        │
       │  自主读取数据文件审计      │
       └──────────────────────────┘
```

**为什么拆**：既当运动员又当裁判会出问题。Audit Agent 在独立上下文中运行，只看到生成物、数据文件和 session-notes，确保审计客观性。

**派发协议**：Main Agent 通过 `sessions_send` 向 Audit Agent 发送审计任务（仅传生成物 + 审计类型 + 学生 ID，不传推理过程）。Audit Agent 返回结构化审计结果（verdict: passed / passed_with_notes / not_passed / user_arbitration）。

**subagents 配置**：Main Agent 的 `tools.subagents.allowAgents` 必须包含 `intelligent-learning-audit`，否则跨 Agent 调用会被拒绝。

**审计失败处理**：最多重试 3 次，仍不通过则提交用户裁决。

---

## 五、注意事项

### 5.1 必须配置项

| 配置项 | 值 | 原因 |
|--------|---|------|
| `streaming` | `true` | 学吧回复通常 500-5000 字，无流式输出用户需干等 10-30 秒 |
| `uat.ownerOnly` | `false` | 学吧支持多用户，每人通过飞书 open_id 自动识别 |
| `model.primary` | 推理模型（`reasoning: true`） | 知识图谱审计、题目验证、内容交叉验证依赖深度推理 |
| `tools.subagents.allowAgents` | 含 `intelligent-learning-audit` | Main Agent 需能调用 Audit Agent |

### 5.2 飞书权限

- 权限在项目创建时由 Agent 发起 OAuth 一次性申请，用户点击授权链接完成
- 无需在飞书后台手动逐个授权，但应用必须有权限**申请**这些 scope
- 完整 scope 清单：`workspace/intelligent-learning-assistant/templates/feishu-scopes.json`（tenant + user 共 180+）

### 5.3 飞书多维表格初始化

部署后首次创建学习项目时，Agent 会自动：
- 创建「学习数据中心」多维表格（5 张数据表）
- 创建 7 个命名视图（知识图谱看板、掌握度热力图、学习日历等）
- 创建「学习仪表盘」（5 个图表组件：折线图、柱线组合、饼图×2、柱状图）
- 将所有 view_id 和 dashboard_id 保存到 `feishu-mapping.yaml`

若视图/仪表盘被误删，Agent 在生成报表时会自动检测并补建（幂等逻辑）。

### 5.4 多人使用

- 每个学生数据完全隔离（按 feishu_open_id → studentId 映射）
- cron 任务按学生隔离：`learning-<type>-<studentId>-<subjectId>`
- 多个 Agent 可共用一个飞书应用，但建议学吧使用独立应用和独立 accountId

### 5.5 模型选择

| 场景 | 推荐 | 最低要求 |
|------|------|---------|
| 全流程 | 当前环境中 `reasoning: true` 的模型 | 必须有推理能力 |
| 预算有限 | 主流程用推理模型，简单任务可降级 | `learning-audit` + `learning-quiz` 必须推理模型 |
| 不推荐 | — | qwen-turbo、gpt-4o-mini 等非推理模型 |

---

## 部署检查清单

- [ ] OpenClaw 已安装（`openclaw --version` 有输出）
- [ ] 飞书官方插件已安装（`npx -y @larksuite/openclaw-lark install`）
- [ ] 飞书应用已创建（向用户确认 App ID + App Secret）
- [ ] 飞书应用权限已配置（参考 feishu-scopes.json）
- [ ] 飞书应用已发布版本
- [ ] 推理模型可用（`reasoning: true`）
- [ ] `bash setup.sh` 执行成功
- [ ] openclaw.json 已合并配置（appId/appSecret 已替换）
- [ ] 两个 Agent 已注册（intelligent-learning-assistant + intelligent-learning-audit）
- [ ] Main Agent 的 `model.primary` 已设为推理模型
- [ ] Main Agent 的 `tools.subagents.allowAgents` 包含 `intelligent-learning-audit`
- [ ] `streaming: true` 已设置
- [ ] `uat.ownerOnly: false` 已设置
- [ ] 网关已重启
- [ ] 飞书发消息"你好"测试通过
- [ ] 创建学习项目后飞书知识库 + 多维表格自动初始化

---

*最后更新：2026-06-24*
