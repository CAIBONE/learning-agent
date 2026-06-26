---
name: learning-feishu-sync
description: "Sync learning profiles, knowledge trees, plans, and progress data to Feishu Knowledge Base, Cloud Docs, and Bitable. Create and maintain Bitable views (kanban/calendar/grid) and dashboards with chart components. Initialized once during project creation by learning-goals."
---

# Learning Feishu Sync — 飞书知识库同步

## 定位

将本地学习数据同步到飞书平台，实现：
1. **学习档案云端备份** — 跨设备访问，不怕本地数据丢失
2. **飞书知识库管理** — 学习内容按学科/章节组织在知识库中
3. **飞书多维表格数据库** — 过程数据（掌握度/测验/错题）存储在多维表格中
4. **飞书报表 Dashboard** — 用多维表格的图表功能替代 ASCII 可视化

## 触发条件

- **学习项目创建时**由 `learning-goals` 调用 → 初始化飞书空间结构（一次性）
- 知识树生成后 → 同步到知识库
- 学习计划生成后 → 同步到多维表格
- 每次内容推送后 → 更新多维表格记录
- 每次测验后 → 更新掌握度和错题记录
- 用户主动要求"同步到飞书"
- 每日定时同步 cron（可选）

> **注意**：飞书授权已在 `learning-goals` 创建学习项目时一次性完成。
> 本模块不再处理初始授权流程，仅处理 token 刷新。

## 飞书空间结构设计

### 知识库结构

```
 学习空间（根知识库）
── 📁 学科A（如：Python编程）
│   ├──  知识图谱 — Python编程
│   ├── 📄 学习计划 — Python编程
│   ├── 📁 第1章 - 基础语法
│   │   ├──  第1节 - 变量与数据类型
│   │   ├── 📄 第2节 - 运算符
│   │   └── ...
│   └── 📁 复习资料
│       ├── 📄 错题本
│       └── 📄 复习笔记
├── 📁 学科B
│   └── ...
── 📁 复盘报表
    ├── 📄 周报_2026-W24
    └── 📄 月报_2026-06
```

### 多维表格结构（作为数据库）

创建一张多维表格 `学习数据中心`，包含 5 张数据表：

| 数据表 | 核心字段 |
|--------|---------|
| **知识节点表** | nodeId, subjectId, title, level, estimatedMinutes, status, masteryLevel, docUrl, prerequisites |
| **学习记录表** | sessionId, studentId, nodeId(关联), startedAt, completedAt, durationMinutes, efficiencyRatio, selfRating, status |
| **测验记录表** | quizId, nodeId(关联), quizType, totalQuestions, correctAnswers, score, masteryBefore, masteryAfter, takenAt |
| **错题本表** | errorId, quizId(关联), nodeId(关联), question, userAnswer, correctAnswer, errorType, reviewCount, nextReviewAt, mastered |
| **掌握度追踪表** | recordId, nodeId(关联), masteryLevel, assessedAt, assessmentType |

## 初始化流程

> 由 `learning-goals` 在创建学习项目时调用，授权已完成。

### 第 1 步：验证授权状态

```
1. 读取 feishu-mapping.yaml 中的授权信息
2. 调用 feishu_oauth 验证 token 是否有效
3. 如果 token 过期 → 尝试刷新
4. 如果刷新失败 → 报错并通知用户需重新授权
   （不再引导逐步授权，直接发送完整授权链接）
```

### 第 2 步：创建知识库

```
1. 使用 feishu_drive_file 检查根目录
2. 创建「学习空间」知识库（如不存在）
3. 记录 root_folder_token
4. 保存映射关系到 data/<studentId>/feishu-mapping.yaml
```

### 第 3 步：创建多维表格

```
1. 使用 feishu_bitable_app 创建「学习数据中心」多维表格
2. 创建 5 张数据表（按上述结构配置字段）
3. 记录 app_token + 各 table_id 到 feishu-mapping.yaml
```

### 第 4 步：创建图表视图与仪表盘

> 多维表格只有"数据"没有"图表"，必须显式创建视图（view）和仪表盘（dashboard）。
> 此步骤确保后续报表模块有可用的可视化资源，且幂等——视图/仪表盘已存在则跳过。

**4.1 为每张数据表创建命名视图**

使用 `feishu_bitable_app_table_view` (POST /bitable/v1/apps/:app_token/tables/:table_id/views)：

| 数据表 | 视图名 | 视图类型 | 配置要点 |
|--------|--------|---------|---------|
| knowledge_nodes | 知识图谱看板 | kanban | groupBy=status, cardFields=[title,masteryLevel,estimatedMinutes], sortBy=level ASC |
| knowledge_nodes | 掌握度热力图 | grid | columns=[title,masteryLevel(条件格式≥4绿/2-3黄/<2红)], sortBy=masteryLevel ASC |
| knowledge_nodes | 学习日历 | calendar | dateField=startedAt, titleField=title, colorBy=status |
| mastery_tracking | 掌握度趋势 | grid | columns=[nodeId,masteryLevel,assessedAt], sortBy=assessedAt ASC（供仪表盘折线图引用） |
| quiz_records | 测验记录列表 | grid | columns=[nodeId,quizType,score,takenAt], sortBy=takenAt DESC |
| learning_sessions | 学习时长统计 | grid | columns=[nodeId,durationMinutes,startedAt,efficiencyRatio], sortBy=startedAt DESC |
| wrong_answers | 错题本 | grid | columns=[nodeId,errorType,question,nextReviewAt,mastered], filter=mastered=false, sortBy=nextReviewAt ASC |

**4.2 创建仪表盘**

使用 `feishu_bitable_dashboard` (POST /bitable/v1/apps/:app_token/dashboards)：

创建名为「学习仪表盘」的 Dashboard，然后使用 `feishu_bitable_dashboard_block` 依次添加以下图表组件：

| 图表组件 | 图表类型 | 数据源表 | 配置 |
|---------|---------|---------|------|
| 掌握度趋势 | line | mastery_tracking | X=assessedAt, Y=masteryLevel, seriesBy=nodeId |
| 测验成绩趋势 | bar_line_combo | quiz_records | X=takenAt, bar=totalQuestions, line=score |
| 错题类型分布 | pie | wrong_answers | groupBy=errorType, value=count |
| 学习时长趋势 | bar | learning_sessions | X=startedAt(按天聚合), Y=durationMinutes |
| 知识完成度 | pie | knowledge_nodes | groupBy=status, value=count |

仪表盘布局建议：2 行 × 3 列，掌握度趋势占 2 列宽度。

**4.3 幂等性保证**

```
创建视图/仪表盘前：
1. GET /bitable/v1/apps/:app_token/tables/:table_id/views → 列出已有视图
2. 若同名视图已存在 → 记录 view_id，跳过创建
3. GET /bitable/v1/apps/:app_token/dashboards → 列出已有仪表盘
4. 若「学习仪表盘」已存在 → 记录 dashboard_id，跳过创建
5. 新建时 → 保存返回的 view_id / dashboard_id 到 mapping
```

### 第 5 步：保存映射关系

```yaml
# data/<studentId>/feishu-mapping.yaml
studentId: "<studentId>"
createdAt: "2026-06-14"
authorizationStatus: "authorized"   # authorized / expired / refreshing
authorizedScopes:                    # 已授权的 scope 列表（引用 templates/feishu-scopes.json）
  tenant: ["aily:data_asset:read", "..."]
  user: ["offline_access", "..."]
authorizedAt: "2026-06-14T10:00:00+08:00"
lastTokenRefresh: "2026-06-14T10:00:00+08:00"
knowledgeBase:
  rootFolderToken: "fldxxxxxxxxxxxxx"
  url: "https://xxx.feishu.cn/wiki/xxxxx"
bitable:
  appToken: "bascnxxxxxxxxxxxxx"
  url: "https://xxx.feishu.cn/base/xxxxx"
  tables:
    knowledgeNodes: "tblxxxxxxxxxxxxx"
    learningSessions: "tblxxxxxxxxxxxxx"
    quizRecords: "tblxxxxxxxxxxxxx"
    wrongAnswers: "tblxxxxxxxxxxxxx"
    masteryTracking: "tblxxxxxxxxxxxxx"
  views:
    # 每张表的视图 viewId，初始化时创建，幂等
    knowledgeNodes:
      kanban: "vewxxxxxxxxxxxxx"      # 知识图谱看板
      heatmap: "vewxxxxxxxxxxxxx"     # 掌握度热力图
      calendar: "vewxxxxxxxxxxxxx"    # 学习日历
    masteryTracking:
      trend: "vewxxxxxxxxxxxxx"       # 掌握度趋势
    quizRecords:
      list: "vewxxxxxxxxxxxxx"        # 测验记录列表
    learningSessions:
      duration: "vewxxxxxxxxxxxxx"    # 学习时长统计
    wrongAnswers:
      unmastered: "vewxxxxxxxxxxxxx"  # 未掌握错题
  dashboards:
    learning:                          # 「学习仪表盘」
      id: "dblxxxxxxxxxxxxx"
      url: "https://xxx.feishu.cn/base/xxxxx?dashboard=dblxxxxx"
subjects:
  python-basics:
    folderToken: "fldxxxxxxxxxxxxx"
    folderUrl: "https://xxx.feishu.cn/wiki/xxxxx"
```

## 同步操作

### 知识树同步
1. 读取本地 knowledge-trees → 2. 生成知识图谱文档 → 3. 写入飞书文档 → 4. 更新多维表格 → 5. 保存 URL 映射

### 学习计划同步
1. 读取本地 plans → 2. 生成学习计划文档 → 3. 写入飞书文档 → 4. 更新多维表格 status

### 学习记录同步（每次内容推送后）
1. 追加记录到 learning_sessions 表 → 2. 更新 knowledge_nodes 表 status + lastStudiedAt

### 测验结果同步（每次测验后）
1. 追加 quiz_records → 2. 更新 mastery_tracking → 3. 更新 knowledge_nodes masteryLevel → 4. 追加 wrong_answers

### 错题同步
1. 批量更新 wrong_answers 表 → 2. 设置 nextReviewAt → 3. 已掌握标记 mastered = true

## 视图与仪表盘维护

> 视图和仪表盘在初始化时创建一次，后续数据变更会自动反映在图表中（飞书多维表格的数据驱动机制）。
> 但以下场景需要重新创建或修复：

### 缺失修复（报表请求时发现视图/仪表盘不存在）

```
当 learning-reports 发现 feishu-mapping.yaml 中 views/dashboards 为空或 API 返回 404：
1. 按第 4 步流程补建缺失的视图/仪表盘（幂等）
2. 更新 feishu-mapping.yaml 中对应的 view_id / dashboard_id
3. 通知用户「报表视图已初始化」
```

### 视图重建触发条件

- mapping.yaml 中 views/dashboards 字段缺失（老项目迁移）
- API 调用返回 view_id/dashboard_id 无效（被手动删除）
- 用户主动要求「重新生成报表视图」

## 从飞书读取数据

当本地数据丢失或需要跨设备访问时：
1. 读取 feishu-mapping.yaml 获取多维表格 app_token
2. 使用 feishu_bitable_app_table_record 读取数据
3. 重建本地 mastery.json / quiz-results.jsonl / wrong-answers.jsonl

## 注意事项

- **双向同步**：本地→飞书为主，飞书→本地为灾备
- **增量同步**：只同步变更的数据，不每次都全量同步
- **冲突处理**：以最新时间戳为准
- **限流**：飞书 API 有调用频率限制，批量操作时注意间隔
- **隐私**：学习数据属于用户隐私，知识库设为私有
- **授权过期处理**：尝试刷新 token，失败则通知用户重新授权（一次性完整授权链接）