---
name: learning-cron
description: "Manage cron jobs for learning automation with multi-student isolation. Create, update, delete, and monitor scheduled tasks for content push, review reminders, quizzes, and reports."
---

# Learning Cron — 定时任务管理

## 定位

所有学习自动化定时任务的统一管理模块。支持**多学生隔离**，每个学生的 cron 任务独立运行。

## 🚨 Cron 任务投递配置（强制）

创建 cron 任务时，**必须**设置 delivery 配置以确保结果能送达用户：

```json
{
  "delivery": {
    "mode": "announce",
    "channel": "feishu",
    "target": "<用户的 feishu open_id>"
  }
}
```

**从 `data/<studentId>/feishu-mapping.yaml` 中读取 `feishuOpenId` 作为 target。**

**绝对禁止**：`delivery.mode = "none"`（这会导致 cron 结果丢失，用户收不到任何推送）。

## 触发条件

- 学习计划生成后 → **先询问用户**推送时间偏好，确认后创建 cron 任务
- 计划调整时 → 更新相关 cron 任务
- 用户要求"取消提醒" → 删除对应 cron
- 用户要求"增加推送频率" → 修改 cron 表达式

> 🚨 **创建 cron 前必须询问用户**（不可跳过）：
>
> 在批量创建 cron 任务之前，**必须**先问用户：
> 1. "你希望每天几点收到学习内容？"（默认 09:00）
> 2. "你希望每天几点收到复习提醒？"（默认 20:00）
> 3. "是否需要每周学习报告？"（默认周五 18:00）
> 4. "是否需要每周测验？"（默认周五 14:00）
>
> 用户确认后才可创建 cron 任务。**禁止在用户不知情的情况下自动创建。**

## 可选：预生成全部内容

在用户确认推送时间后、创建 cron 任务前，**询问**：

> "是否需要现在就预生成全部学习内容？预生成后每次推送的内容都经过审计，质量更有保证。
> 预生成大约需要 1-3 小时（131 个知识点，每个需生成+审计）。
> 如果选择不预生成，学习内容将在每天推送时实时生成（约 5-10 分钟/节）。"

### 用户选择"是"时的分批生成方案

> ⚠️ **不能在一个 session 里完成**（78 分钟就 compaction 丢失上下文了）

**步骤**：
1. 先创建推送 cron 任务（确保推送不中断）
2. 创建进度文件 `data/<studentId>/content-progress.json`：
   ```json
   {
     "total": 131,
     "completed": [],
     "failed": [],
     "batchSize": 5,
     "startedAt": "2026-06-28T13:00:00+08:00"
   }
   ```
3. 创建 cron 任务 `learning-pregenerate`：每 30 分钟触发一批
   - 读取进度文件，取下一批 5 个未完成的节点
   - 生成 → 保存到 content/ → 派发审计 → 标记 completed
   - 更新进度文件
   - 飞书通知进度："已预生成 15/131"
   - 全部完成后飞书通知"预生成完毕"并禁用自身 cron
4. Cron 推送优先用已审计的 ready 内容，未 ready 的实时生成
5. 任何一批失败都不阻塞后续批次——失败节点记入 failed 列表，最后统一重试

**可靠性保障**：
- 每批独立 session，一个崩溃不影响其他
- 进度文件持久化，重启后从断点继续
- 审计失败有 3 次重试，超过则记入 failed 列表
- 用户可随时说"查看预生成进度"

### 用户选择"否"时

- 直接创建推送 cron 任务
- 学习内容在每次 cron 触发时实时生成
- **但 cron 触发时，生成内容后必须派发审计，审计通过后才推送**（见 learning-content SKILL）

## Cron 任务命名规范（强制）

**命名格式**：`learning-<type>-<studentId>-<subjectId>`

示例：
- `learning-push-student-abc123-python-basics`
- `learning-review-student-abc123-python-basics`
- `learning-quiz-student-abc123-python-basics`
- `learning-report-student-abc123-python-basics`

**命名规则**：
- studentId 在前（紧跟 type），确保按学生分组
- 全部小写，用连字符分隔
- 必须包含 studentId + subjectId，确保唯一性

## Cron 任务清单

### 学习计划生成后自动创建的任务

| 任务名 | Cron 表达式 | 说明 |
|--------|------------|------|
| 每日学习推送 | `0 9 * * 1-5` | 工作日 9:00 推送新内容 |
| 每日复习提醒 | `0 20 * * 1-5` | 工作日 20:00 提醒复习 |
| 周末学习推送 | `0 9 * * 6` | 周六 9:00 推送 |
| 每周测验 | `0 14 * * 5` | 周五 14:00 阶段测验 |
| 每周复盘 | `0 18 * * 5` | 周五 18:00 生成周报 |
| 每月复盘 | `0 10 1 * *` | 每月 1 号 10:00 月报 |

### 按需创建的任务

| 任务名 | Cron 表达式 | 说明 |
|--------|------------|------|
| 考前冲刺推送 | `0 7,12,19 * * *` | 考试前 N 天，每天 3 次高频推送 |
| 错题复习提醒 | `0 20 * * *` | 每晚 20:00 提醒复习错题 |
| 间隔复习提醒 | 动态 | 根据艾宾浩斯曲线生成 |

## 多学生隔离（强制）

### 隔离原则

1. **每个 cron 任务绑定唯一 studentId + subjectId**
2. **payload 中必须包含 studentId**，用于定位该学生的数据目录
3. **不同学生的 cron 任务独立运行，不共享会话状态**
4. **创建前检查是否已存在同名任务**（按命名规范），避免重复

### payload 格式（强制包含 studentId）

```json
{
  "kind": "userMessage",
  "text": "请推送今天的学习内容。学生ID: <studentId>，科目: <subjectId>",
  "channel": "feishu",
  "accountId": "intelligent-learning",
  "metadata": {
    "studentId": "<studentId>",
    "subjectId": "<subjectId>",
    "taskType": "push | review | quiz | report"
  }
}
```

### 多学生管理操作

**列出所有 cron 任务**：
```
按 studentId 分组展示：
  student-abc123:
    - learning-push-student-abc123-python-basics [enabled] 下次: 2026-06-16 09:00
    - learning-review-student-abc123-python-basics [enabled] 下次: 2026-06-16 20:00
  student-def456:
    - learning-push-student-def456-marketing [enabled] 下次: 2026-06-16 09:00
```

**暂停/恢复**：按 studentId 过滤，只操作目标任务
**删除目标时**：删除该 studentId + subjectId 下的所有 cron 任务

### 资源限制

- 单个学生 cron 上限：**15 个**
- 所有学生 cron 总上限：**50 个**
- 超限时提示用户清理旧任务

## Cron 管理实现

### 创建
```
1. 确定任务参数（name, schedule, payload 含 studentId）
2. 检查同名任务是否已存在 → 存在则跳过
3. 通过 OpenClaw API 创建
4. 验证创建成功
```

### 更新
```
1. 找到目标 cron job（按 name 匹配）
2. 更新 schedule 表达式
3. 验证更新成功
```

### 删除
```
1. 找到目标 cron job
2. 删除任务
3. 验证删除成功
4. 通知用户
```

## 与其他 SKILL 的协作

| 调用方 | 操作 | 说明 |
|--------|------|------|
| learning-plan | create | 生成计划后批量创建 cron |
| learning-plan | update | 调整计划时更新 cron |
| learning-plan | delete | 暂停目标时禁用 cron |
| learning-content | create | 用户要求增加推送频率 |
| learning-quiz | create | 用户要求增加测验频率 |
| learning-review | update | 复盘后调整报表频率 |

## 注意事项

- **幂等性**：创建前检查是否已存在同名任务，避免重复
- **时区**：所有 cron 表达式使用服务器本地时区（Asia/Shanghai）
- **错误处理**：cron 创建失败时保存本地记录，不阻塞主流程