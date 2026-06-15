# UI 层

Prototype V0.1 允许先使用调试 UI，但 UI 数据必须来自真实模拟状态。

Beta 前目标：

- 主界面、大地图、城市、武将、任命、出阵、战报、事件、存档界面都应成为正式游戏界面。
- 主要玩法不得依赖调试面板完成。
- Content Alpha 的资源预览入口必须来自已审计内容索引，不允许用测试武将 ID 猜测头像。
- 候选半身像图片加载必须通过统一入口暴露错误，不允许用默认图掩盖缺失或损坏资源。
- Content Alpha 工作台可以浏览候选武将、可复用半身像、UI 信息架构规格、UI 线框规格和 UI 主题 Token，并在校验成功后应用 `themes/content_alpha_formal_theme.tres`；这些入口仍是内部工具，不代表 Beta 正式 UI。
- `FormalUiComponentFactory` 是正式 UI 动态控件入口，负责从 `ui_theme_tokens` 派生标题、信息行、状态徽标、命令按钮和动作按钮；动态按钮必须保留真实 `blocked_reason`，不得在组件层生成业务默认值。
- `FormalHud` 是第一层正式主界面外壳，读取真实运行时状态显示日期、势力摘要、领袖卡、主地图摘要和地图选择详情；底部命令在对应正式界面完成前必须保持禁用并显示阻塞原因。领袖卡文本必须来自 `runtime_state.forces / officers`，半身像未正式绑定前只能标注为候选资源示例；地图选择摘要必须用真实名称和可读状态展示，不把内部 ID 当作正式摘要常态文本。正式弹窗统一挂在 `PopupLayer` 下，主地图摘要只读 `runtime_state.cities / routes / armies`，缺字段必须失败。
- Playable Slice 阶段优先让正式 HUD 承载主流程：目标提示、推进一日、战报、事件和存档优先可用；正式武将名册等低优先级系统可以先保留禁用入口。
- `CityDetailPanel` 是第一层正式城市详情面板，读取 `runtime_state.cities / forces / officers`，并按兵粮民生、治理状态、太守、属官和动作区展示；任命和出阵按钮会打开 `AppointmentSortiePanel`。不存在真实上限字段时不得伪造成“当前 / 上限”。
- `AppointmentSortiePanel` 是第一层正式任命与出阵面板，读取 `runtime_state.cities / forces / officers / routes / armies / next_army_seq`，并只通过 `AppointmentSystem` 与 `SortieSystem` 修改真实运行时状态。
- `BattleReportPanel` 是第一层正式战报面板，读取 `runtime_state.battle_logs / armies / cities`；战报引用断裂必须失败，不允许显示空假战报。
- `EventLogPanel` 是第一层正式事件日志面板，聚合现有运行时日志字典；它不代表完整历史事件链已经完成。
- `SaveLoadPanel` 是第一层正式存档读档面板，调用 `SaveSystem` 保存和读取真实动态状态；读档必须有真实 base dataset 重建静态数据，不允许用空数据伪造成功。
