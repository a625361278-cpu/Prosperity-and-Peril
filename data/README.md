# 数据目录

本目录用于存放从四份交付文档和数据母表导出的 Godot 可读测试数据。

当前规则：

- 不手写伪造正式内容库。
- Prototype V0.1 只放核心闭环测试数据。
- Content Alpha 起允许放入从真实来源审计导出的阶段性内容索引，例如英雄半身像候选资源索引。
- 数据字段必须能追溯到 `三国志_治世与乱世_数据母表_V0.3.xlsx`。
- 缺字段、重复 ID、非法引用应阻断导入。

## 当前内容

- `prototype_v0_1/core_test_data.json`：核心闭环测试数据。
- `content_alpha/hero_portrait_index.json`：由 `tools/audit_hero_portrait_assets.py` 从项目负责人另一个自有项目的英雄表、多语言表和半身像目录审计导出的候选资源索引。
- `content_alpha/resource_manifest.json`：Content Alpha 候选资源包清单，用于记录来源项目、索引路径、所有权状态和允许用途。
- `content_alpha/hero_portrait_import_manifest.json`：由 `tools/import_hero_portrait_assets.py` 复制项目内半身像 PNG 后生成的导入清单，用于校验目标资源、哈希、尺寸和英雄绑定。
