# UI 层

Prototype V0.1 允许先使用调试 UI，但 UI 数据必须来自真实模拟状态。

Beta 前目标：

- 主界面、大地图、城市、武将、任命、出阵、战报、事件、存档界面都应成为正式游戏界面。
- 主要玩法不得依赖调试面板完成。
- Content Alpha 的资源预览入口必须来自已审计内容索引，不允许用测试武将 ID 猜测头像。
- 候选半身像图片加载必须通过统一入口暴露错误，不允许用默认图掩盖缺失或损坏资源。
- Content Alpha 工作台可以浏览候选武将、可复用半身像、UI 信息架构规格、UI 线框规格和 UI 主题 Token，并在校验成功后应用 `themes/content_alpha_formal_theme.tres`；这些入口仍是内部工具，不代表 Beta 正式 UI。
- `FormalHud` 是第一层正式主界面外壳，读取真实运行时状态显示日期、势力摘要和地图选择详情；底部命令在对应正式界面完成前必须保持禁用并显示阻塞原因。
- `CityDetailPanel` 是第一层正式城市详情面板，读取 `runtime_state.cities / forces / officers`；任命和出阵按钮会打开 `AppointmentSortiePanel`。
- `AppointmentSortiePanel` 是第一层正式任命与出阵面板，读取 `runtime_state.cities / forces / officers / routes / armies / next_army_seq`，并只通过 `AppointmentSystem` 与 `SortieSystem` 修改真实运行时状态。
