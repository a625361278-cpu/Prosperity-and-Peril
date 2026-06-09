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

- [x] Task 2：英雄半身像索引读取与解析入口
  - 状态：已完成。
  - 范围：新增 Godot 侧 `HeroPortraitIndexLoader`，读取 `hero_portrait_index.json` 后先执行结构校验，再按英雄 ID 建立查找表；UI 或后续内容系统可通过英雄 ID 取得真实 `name_cn / half_body / portrait_source_path`。
  - 根因：只有静态 JSON 索引还不能约束后续 UI 的调用方式；必须提供统一入口，避免界面层重新拼接图片名或在缺失 ID 时使用默认头像。
  - 边界：当前只返回已审计的候选资源路径，不导入贴图、不创建正式武将界面、不确认商业授权。
  - 验收：索引文件缺失、JSON 非对象、结构校验失败、英雄 ID 缺失都必须失败；解析结果必须保留 `halfBody` 权威映射。
  - 验证：
    - `test_hero_portrait_index.gd` 通过，确认索引可加载、`2000501` 解析为 `UI_gj_gg_basemap_hero_1004`，缺失英雄 ID 明确失败。

- [x] Task 3：英雄半身像预览数据 Presenter
  - 状态：已完成。
  - 范围：新增 `HeroPortraitPreviewPresenter`，把已审计索引转成 UI 原型可用的预览行，字段包含英雄 ID、中文名、文本 key、`halfBody` 和真实候选资源路径。
  - 根因：Content Alpha 后续需要 UI 原型入口，但当前运行时测试武将没有权威字段能证明其对应哪一个历史英雄头像；因此先提供真实索引预览数据，不把测试武将强行绑定到候选头像。
  - 边界：不导入贴图到本项目，不制作正式武将面板，不把 `OFF_TEST_PLAYER` 等测试武将映射为历史人物，不确认商业授权。
  - 验收：预览行必须来自索引解析入口；资源路径不存在必须失败；`2000501` 仍必须保留 `UI_gj_gg_basemap_hero_1004` 的 `halfBody` 映射。
  - 验证：
    - `test_hero_portrait_preview_presenter.gd` 通过，确认默认预览行、非 ID 推导映射和缺失资源路径失败。

## 当前缺口

- 半身像资源仍来自候选项目路径，正式商业使用前必须确认授权。
- 正式武将数据、技能、官职、势力剧本尚未进入 Content Alpha 内容包；当前测试武将也尚未具备权威头像绑定字段。
- 正式 UI 信息架构和视觉风格仍未落地；当前只准备资源索引入口。
