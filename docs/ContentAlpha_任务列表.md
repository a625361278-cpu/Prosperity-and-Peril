# Content Alpha 任务列表

## 执行规则

- 本阶段开始建立阶段性内容库和 UI 原型，但仍不伪装成完整正式版内容。
- 所有内容索引必须来自真实数据源、真实资源路径或已确认的项目内数据，不允许用默认头像、默认文本或猜测 ID 掩盖缺失。
- 候选资源可用于内部原型；商业正式使用前必须确认版权、授权和项目间复用边界。
- 每个任务完成后必须更新文档并运行验证。

## 任务状态

- [x] Task 1：英雄半身像候选资源索引
  - 状态：已完成。
  - 范围：从候选项目的 `hero_英雄.xlsx`、`lang_多语言.xlsx` 和半身像目录审计英雄名称与 `halfBody` 映射，导出 Godot 可读的 `data/content_alpha/hero_portrait_index.json`。
  - 根因：后续 UI 原型需要头像资源入口；直接用英雄 ID 拼图片名会在 `2000501 -> UI_gj_gg_basemap_hero_1004` 这类真实映射上出错。
  - 边界：当前只建立内部原型候选资源索引，不确认商业正式授权，不导入图片到本项目，不制作正式武将界面。
  - 验收：缺失中文名、空 `halfBody`、缺失 `.png`、重复英雄 ID 必须失败；索引必须声明 `halfBody` 是权威映射来源。
  - 验证：
    - `py -3.14 tools\audit_hero_portrait_assets.py --export-json data\content_alpha\hero_portrait_index.json` 通过，导出 426 条记录。
    - `test_hero_portrait_index.gd` 通过，确认索引结构、样例映射和重复 ID 失败。

## 当前缺口

- 半身像资源仍来自候选项目路径，正式商业使用前必须确认授权。
- 正式武将数据、技能、官职、势力剧本尚未进入 Content Alpha 内容包。
- 正式 UI 信息架构和视觉风格仍未落地；当前只准备资源索引入口。
