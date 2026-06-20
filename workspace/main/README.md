# 智能学习助手 — 工作区

本工作区是「学吧」📚 的运行环境。

## 核心文件

- `SOUL.md` — 人格定义、教学风格、首次回复规则
- `IDENTITY.md` — 身份定义
- `AGENTS.md` — 工作区规范、技能路由、数据目录说明

## 技能模块

`skills/learning/` 下 11 个 Skill，每个含 `SKILL.md`：

| Skill | 职责 |
|-------|------|
| learning-core | 路由、闭环驱动、学生身份映射 |
| learning-goals | 目标捕获 + 飞书权限预检 |
| learning-knowledge-tree | 知识树生成 + 6 步语义验证 |
| learning-plan | 排程 + 艾宾浩斯 + 量化动态调整 |
| learning-content | 内容生成 + 审计 + 飞书推送 |
| learning-quiz | 测验 + 审计 + 评分 |
| learning-audit | 知识图谱/内容/题目质量检查 |
| learning-reports | 飞书多维表格 Dashboard |
| learning-review | 复盘：数据→洞察→行动 |
| learning-cron | 定时任务（多学生隔离） |
| learning-feishu-sync | 飞书知识库+多维表格同步 |

## 模板

`templates/` 目录：
- `plan-schema.yaml` — 学习计划 YAML Schema 完整示例
- `content-template.md` — 学习内容格式模板（10 个必需小节）
- `message-card.json` — 飞书消息卡片 JSON
- `feishu-scopes.json` — 飞书 OAuth 完整权限范围（tenant + user 共 180+ scope）

## 运行时数据

| 目录 | 内容 |
|------|------|
| `knowledge-trees/<studentId>/` | 知识图谱 YAML |
| `learning-profiles/<studentId>/` | 目标、计划、档案、飞书映射、openid 映射 |
| `progress/<studentId>/` | 掌握度、测验、内容日志、错题、审计记录 |
| `memory/` | Agent 记忆 |
| `artifacts/` | 生成文件缓存 |

## 飞书集成

权限在学习项目创建时一次性申请（180+ scope，完整清单见 `templates/feishu-scopes.json`），映射关系保存在 `learning-profiles/<studentId>/feishu-mapping.yaml`。