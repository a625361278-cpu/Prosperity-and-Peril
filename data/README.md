# 数据目录

本目录用于存放从四份交付文档和数据母表导出的 Godot 可读测试数据。

当前规则：

- 不手写伪造正式内容库。
- Prototype V0.1 只放核心闭环测试数据。
- Content Alpha 起允许放入从真实来源审计导出的阶段性资源索引，例如英雄半身像候选资源索引。
- 数据字段必须能追溯到 `三国志_治世与乱世_数据母表_V0.3.xlsx`。
- 缺字段、重复 ID、非法引用应阻断导入。

## 当前内容

- `prototype_v0_1/core_test_data.json`：核心闭环测试数据。
- `content_alpha/hero_portrait_index.json`：由 `tools/audit_hero_portrait_assets.py` 从项目负责人另一个自有项目的英雄表、多语言表和半身像目录审计导出的候选资源索引。
- `content_alpha/resource_manifest.json`：Content Alpha 候选资源包清单，用于记录来源项目、索引路径、所有权状态和允许用途。
- `content_alpha/hero_portrait_import_manifest.json`：由 `tools/import_hero_portrait_assets.py` 复制项目内半身像 PNG 后生成的导入清单，用于校验目标资源、哈希、尺寸和英雄绑定。
- `content_alpha/reusable_hero_portrait_pool.json`：由 `tools/export_reusable_hero_portrait_pool.py` 从项目内导入清单导出的 212 张可复用半身像池；只记录图片、尺寸、哈希和源英雄名参考，不导入源项目技能、传记、君略、官职或势力等玩法字段。
- `content_alpha/candidate_officer_roster.json`：由 `tools/export_candidate_officer_roster.py` 从可复用半身像池导出的 212 条头像绑定候选武将名册；只记录候选 ID、显示名、选择状态、头像路径和来源参考，不代表正式武将库。
- `content_alpha/ui_navigation_spec.json`：Content Alpha UI 信息架构规格，记录主界面、大地图、城市、武将、任命出阵、战报、事件日志和存档界面的数据源、入口、可用状态与阻塞项；它不是 Beta 正式 UI 成品。
- `content_alpha/ui_wireframe_spec.json`：Content Alpha 正式 UI 线框规格，记录核心界面的布局区域、组件、状态绑定和交互合同；它只约束后续实装方向，不代表正式控件已经完成。
- `content_alpha/ui_theme_tokens.json`：Content Alpha 正式 UI 主题 Token，记录已确认风格方向下的色板、字号、间距、圆角、控件状态和响应式规则；它不是 Godot Theme 成品。
