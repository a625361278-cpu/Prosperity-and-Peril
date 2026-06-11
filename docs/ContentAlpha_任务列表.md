# Content Alpha 任务列表

## 执行规则

- 本阶段开始建立阶段性内容库和 UI 原型，但仍不伪装成完整正式版内容。
- 所有内容索引必须来自真实数据源、真实资源路径或已确认的项目内数据，不允许用默认头像、默认文本或猜测 ID 掩盖缺失。
- 候选半身像资源来自项目负责人另一个自有项目，不需要额外授权流程；仍必须记录来源项目、字段映射和导入流程边界。
- 每个任务完成后必须更新文档并运行验证；小任务可以本地提交，Content Alpha 大版本完成后再统一推送远端。

## 任务状态

- [x] Task 1：英雄半身像候选资源索引
  - 状态：已完成。
  - 范围：从候选项目的 `hero_英雄.xlsx`、`lang_多语言.xlsx` 和半身像目录审计英雄名称与 `halfBody` 映射，导出 Godot 可读的 `data/content_alpha/hero_portrait_index.json`。
  - 根因：后续 UI 原型需要头像资源入口；直接用英雄 ID 拼图片名会在 `2000501 -> UI_gj_gg_basemap_hero_1004` 这类真实映射上出错。
  - 边界：当前只建立候选资源索引，不导入图片到本项目，不制作正式武将界面。
  - 验收：缺失中文名、空 `halfBody`、缺失 `.png`、重复英雄 ID 必须失败；索引必须声明 `halfBody` 是权威映射来源。
  - 验证：
    - `py -3.14 tools\audit_hero_portrait_assets.py --export-json data\content_alpha\hero_portrait_index.json` 通过，导出 426 条记录。
    - `test_hero_portrait_index.gd` 通过，确认索引结构、样例映射和重复 ID 失败。

- [x] Task 2：英雄半身像索引读取与解析入口
  - 状态：已完成。
  - 范围：新增 Godot 侧 `HeroPortraitIndexLoader`，读取 `hero_portrait_index.json` 后先执行结构校验，再按英雄 ID 建立查找表；UI 或后续内容系统可通过英雄 ID 取得真实 `name_cn / half_body / portrait_source_path`。
  - 根因：只有静态 JSON 索引还不能约束后续 UI 的调用方式；必须提供统一入口，避免界面层重新拼接图片名或在缺失 ID 时使用默认头像。
  - 边界：当前只返回已审计的候选资源路径，不导入贴图、不创建正式武将界面。
  - 验收：索引文件缺失、JSON 非对象、结构校验失败、英雄 ID 缺失都必须失败；解析结果必须保留 `halfBody` 权威映射。
  - 验证：
    - `test_hero_portrait_index.gd` 通过，确认索引可加载、`2000501` 解析为 `UI_gj_gg_basemap_hero_1004`，缺失英雄 ID 明确失败。

- [x] Task 3：英雄半身像预览数据 Presenter
  - 状态：已完成。
  - 范围：新增 `HeroPortraitPreviewPresenter`，把已审计索引转成 UI 原型可用的预览行，字段包含英雄 ID、中文名、文本 key、`halfBody` 和真实候选资源路径。
  - 根因：Content Alpha 后续需要 UI 原型入口，但当前运行时测试武将没有权威字段能证明其对应哪一个历史英雄头像；因此先提供真实索引预览数据，不把测试武将强行绑定到候选头像。
  - 边界：不导入贴图到本项目，不制作正式武将面板，不把 `OFF_TEST_PLAYER` 等测试武将映射为历史人物。
  - 验收：预览行必须来自索引解析入口；资源路径不存在必须失败；`2000501` 仍必须保留 `UI_gj_gg_basemap_hero_1004` 的 `halfBody` 映射。
  - 验证：
    - `test_hero_portrait_preview_presenter.gd` 通过，确认默认预览行、非 ID 推导映射和缺失资源路径失败。

- [x] Task 4：调试面板接入半身像候选预览
  - 状态：已完成。
  - 范围：在现有调试面板中增加半身像候选预览文本区，从 `HeroPortraitIndexLoader` 和 `HeroPortraitPreviewPresenter` 读取真实候选索引，展示前 3 条英雄 ID、中文名和 `halfBody`。
  - 根因：Content Alpha 需要开始形成 UI 原型入口；但当前仍不具备正式武将头像绑定字段，因此只展示候选资源索引预览，不把原型测试武将伪装成历史人物。
  - 边界：不导入贴图，不显示正式头像图像，不替代正式武将界面；索引或资源路径异常时在调试面板暴露错误，不使用默认头像。
  - 验收：调试面板必须有独立预览区域；预览内容必须来自已审计索引入口；`2000501` 等非 ID 推导映射必须可被格式化展示。
  - 验证：
    - `test_debug_panel_layout.gd` 通过，确认预览区域存在、布局高度足够且可格式化真实映射行。

- [x] Task 5：英雄半身像纹理加载入口
  - 状态：已完成。
  - 范围：新增 `HeroPortraitTextureLoader`，从已审计预览行读取真实 PNG，生成 `ImageTexture`，并返回尺寸、英雄 ID、中文名、`halfBody` 和来源路径。
  - 根因：后续 UI 图片控件需要统一的真实资源加载入口；如果让界面层各自加载图片，容易出现默认图兜底、路径拼接或坏图静默失败。
  - 边界：只加载候选资源池中的 PNG，不复制资源、不生成 Godot import 资源、不制作正式头像组件。
  - 验收：缺字段、缺文件、非图片文件、坏图片必须失败；成功加载时必须保留审计行中的 `halfBody` 元数据和真实图片尺寸。
  - 验证：
    - `test_hero_portrait_texture_loader.gd` 通过，确认 `1001` 的候选 PNG 可加载为 `1300x1080` 纹理，非图片文件和缺字段明确失败。

- [x] Task 6：调试面板显示候选半身像纹理
  - 状态：已完成。
  - 范围：在调试面板加入 `PortraitPreviewImage`，启动时从已审计半身像预览行加载第一张真实 PNG 并设置到 `TextureRect`。
  - 根因：Content Alpha 需要验证候选资源不仅能形成文本索引，也能被 Godot UI 真实解码和显示；这一步为后续正式武将/头像组件提供最小可见入口。
  - 边界：只显示候选资源预览，不绑定测试武将，不导入贴图，不使用默认头像；加载失败时清空纹理并显示错误。
  - 验收：调试面板必须有独立图片预览节点；节点初始不得带默认纹理；纹理可被设置和清空；图片来源必须继续走已审计索引与纹理加载入口。
  - 验证：
    - `test_debug_panel_layout.gd` 通过，确认图片预览节点存在、没有默认纹理，且可以设置/清空纹理。

- [x] Task 7：半身像候选预览组件化
  - 状态：已完成。
  - 范围：新增 `HeroPortraitPreviewPanel` 独立场景和脚本，把候选半身像文本预览、真实 PNG 加载和 `TextureRect` 显示逻辑从调试面板中抽出；调试面板只负责嵌入组件。
  - 根因：候选半身像入口后续会被正式武将/头像 UI 复用，继续把索引、Presenter、纹理加载逻辑写在 `DebugPanel` 会扩大调试面板职责。
  - 边界：组件仍只展示候选资源预览，不绑定测试武将，不导入图片资源，不替代正式武将界面。
  - 验收：组件必须独立加载默认审计预览、格式化非 ID 推导映射、设置/清空纹理；调试面板必须通过组件节点接入，不直接处理候选资源加载细节。
  - 验证：
    - `test_hero_portrait_preview_panel.gd` 通过，确认组件节点、预览格式、真实默认预览加载和纹理设置/清空。
    - `test_debug_panel_layout.gd` 通过，确认调试面板继续正确嵌入半身像预览组件。

- [x] Task 8：候选资源包来源清单与路径校验
  - 状态：已完成。
  - 范围：新增 `data/content_alpha/resource_manifest.json` 和 `ContentAlphaResourceManifestValidator`，把候选资源的来源项目、索引路径、所有权状态、允许用途和说明变成可校验数据。
  - 根因：半身像候选资源来自项目负责人另一个自有项目，不存在额外授权问题；但来源和映射边界仍需要机器可读记录，避免后续错绑、猜路径或丢失来源。
  - 边界：不改变候选资源实际来源，不导入图片资源；当前状态明确为 `project_owner_resource`。
  - 验收：资源包必须声明来源项目、所有权状态、来源路径、索引路径和允许用途；索引路径缺失必须失败；非法所有权状态必须失败。
  - 验证：
    - `test_content_alpha_resource_manifest.gd` 通过，确认当前资源清单有效，缺所有权状态、非法所有权状态和缺索引路径会失败。

- [x] Task 9：候选资源来源路径存在性校验
  - 状态：已完成。
  - 范围：扩展 `ContentAlphaResourceManifestValidator`，要求 `source_project` 和 `source_paths` 都必须真实存在，覆盖自有项目目录、英雄表、多语言表和半身像目录。
  - 根因：半身像资源来自另一个自有项目，后续工具链依赖这些来源路径；如果路径移动或缺失，应该在内容校验阶段暴露，而不是等 UI 加载图片时才出错。
  - 边界：只校验路径存在，不复制资源、不修复路径、不自动切换到备用资源。
  - 验收：来源项目路径缺失必须失败；任一来源文件/目录缺失必须失败；当前清单中的真实路径必须通过。
  - 验证：
    - `test_content_alpha_resource_manifest.gd` 通过，确认真实来源路径有效，缺来源项目和缺来源文件会失败。

- [x] Task 10：候选资源清单读取入口
  - 状态：已完成。
  - 范围：新增 `ContentAlphaResourceManifestLoader`，统一读取 `resource_manifest.json`、执行清单校验，并按资源包 ID 建立查找表。
  - 根因：后续内容工具和 UI 不应各自直接解析资源清单 JSON；必须先经过统一加载与校验入口，避免绕过来源路径、所有权状态和索引路径校验。
  - 边界：只提供读取和解析入口，不自动修复缺失路径，不复制资源，不替换资源包 ID。
  - 验收：清单文件缺失、JSON 非对象、清单校验失败、资源包 ID 缺失都必须失败；`candidate_hero_portraits` 必须能解析出真实索引路径和自有资源状态。
  - 验证：
    - `test_content_alpha_resource_manifest.gd` 通过，确认清单可加载成资源包查找表，缺失资源包 ID 明确失败。

- [x] Task 11：半身像资源包加载入口
  - 状态：已完成。
  - 范围：新增 `HeroPortraitPackLoader`，从 `resource_manifest.json` 解析 `candidate_hero_portraits` 资源包，再通过包内 `index_path` 加载半身像索引；`HeroPortraitPreviewPanel` 改为通过资源包加载，不再硬编码索引路径。
  - 根因：UI 组件不应该直接依赖具体 JSON 文件路径；后续如果资源包迁移或加入更多资源包，应只改资源清单，而不是改 UI。
  - 边界：只解析清单和索引，不导入图片、不替换资源包、不自动修复错误路径。
  - 验收：资源包缺失、资源包类型错误、索引加载失败都必须失败；默认半身像预览必须继续能通过清单解析出 `1001 -> UI_gj_gg_basemap_hero_1001`。
  - 验证：
    - `test_content_alpha_resource_manifest.gd` 通过，确认 `HeroPortraitPackLoader` 可从清单解析半身像查找表。
    - `test_hero_portrait_preview_panel.gd` 通过，确认 UI 组件继续能加载默认审计预览。

- [x] Task 12：Content Alpha 聚合校验入口
  - 状态：已完成。
  - 范围：新增 `ContentAlphaValidationRunner`，串联资源清单、半身像资源包、索引查找表、默认预览行和第一张真实 PNG 解码，输出阶段性内容摘要。
  - 根因：前面任务已经分别校验清单、索引和 UI 预览，但大版本验收需要一个统一入口确认真实链路可以贯通；否则单点测试通过仍可能遗漏清单到图片解码之间的断点。
  - 边界：只做校验和摘要输出，不自动导入资源、不生成默认图、不修复缺失路径、不把测试武将绑定到历史英雄。
  - 验收：默认内容链路必须能解析 `candidate_hero_portraits`、426 条候选英雄、3 条默认预览和 `1001 -> 刘备 -> UI_gj_gg_basemap_hero_1001` 的 `1300x1080` PNG；缺失清单或非法预览数量必须失败。
  - 验证：
    - `test_content_alpha_validation_runner.gd` 通过，确认默认内容链路贯通，缺失清单和非法预览数量明确失败。

- [x] Task 13：调试面板显示 Content Alpha 校验摘要
  - 状态：已完成。
  - 范围：在半身像候选预览组件中增加 `ContentAlphaValidationText`，默认加载候选半身像时同步运行 `ContentAlphaValidationRunner` 并显示资源包、索引数量、预览数量和首张真实图片尺寸。
  - 根因：聚合校验如果只存在于测试脚本里，编辑器运行时无法直观看到当前内容链路是否贯通；调试面板应该展示真实校验摘要，而不是只显示图片加载结果。
  - 边界：只显示校验摘要，不把摘要当作正式 UI，不绕过任何清单、索引或图片解码错误。
  - 验收：调试面板必须包含校验摘要节点；默认预览成功时必须显示 `candidate_hero_portraits`、426 条英雄、3 条预览和 `1001 刘备 1300x1080`。
  - 验证：
    - `test_hero_portrait_preview_panel.gd` 通过，确认组件可格式化并加载默认校验摘要。
    - `test_debug_panel_layout.gd` 通过，确认调试面板包含 Content Alpha 校验摘要节点。

- [x] Task 14：半身像项目内导入流程与清单
  - 状态：已完成。
  - 范围：新增 `tools/import_hero_portrait_assets.py`，按已审计索引把唯一 `halfBody` PNG 导入到 `assets/content_alpha/hero_portraits`，生成 `hero_portrait_import_manifest.json`；资源清单新增 `import_manifest_path` 指向项目内导入清单。
  - 根因：外部候选路径只能证明资源存在，不能证明项目打包时能拿到对应 PNG；必须把导入后的目标路径、大小、哈希、尺寸和英雄绑定写成可验证清单。
  - 边界：按唯一 `halfBody` 导入，不为 426 个英雄重复复制同一张 NPC 图；英雄与图片的关系仍以审计索引和导入清单绑定为准，不用 ID 推导文件名。
  - 验收：导入清单必须包含 212 张唯一项目内 PNG 和 426 条英雄绑定；缺目标文件、哈希不一致或绑定目标不匹配必须失败；`2000501` 必须继续绑定 `UI_gj_gg_basemap_hero_1004`。
  - 验证：
    - `py -3.14 tools\import_hero_portrait_assets.py` 通过，导入 212 张唯一 PNG，生成 426 条英雄绑定。
    - `test_hero_portrait_import_manifest.gd` 通过，确认导入清单、目标 PNG、哈希、尺寸和非 ID 推导绑定。
    - `test_content_alpha_resource_manifest.gd` 通过，确认资源清单显式引用导入清单。

- [x] Task 15：运行时半身像加载切换到项目内资源
  - 状态：已完成。
  - 范围：`HeroPortraitPackLoader` 读取资源包时同步加载导入清单，把每个索引记录补上项目内 `portrait_res_path`；`HeroPortraitTextureLoader` 在存在导入路径时优先从 `res://assets/content_alpha/hero_portraits` 加载。
  - 根因：调试面板和后续 UI 如果继续读取另一个项目的绝对路径，打包和跨机器运行都会断；既然资源包已经声明导入清单，默认运行时链路必须使用项目内资源。
  - 边界：索引级测试仍允许验证外部源路径，作为审计来源校验；默认资源包链路不允许导入清单缺失、绑定缺失或 `halfBody` 不一致。
  - 验收：默认 Content Alpha 校验必须使用 `imported_res` 路径；`1001` 必须加载 `res://assets/content_alpha/hero_portraits/UI_gj_gg_basemap_hero_1001.png`；直接索引行仍可验证外部源图。
  - 验证：
    - `test_content_alpha_validation_runner.gd` 通过，确认默认链路使用项目内导入资源。
    - `test_hero_portrait_texture_loader.gd` 通过，确认导入资源优先、外部源索引仍可单独校验。
    - `test_hero_portrait_preview_panel.gd` 和 `test_debug_panel_layout.gd` 通过，确认调试面板继续显示半身像预览。

- [x] Task 16：Content Alpha 打包烟测
  - 状态：已完成。
  - 范围：新增 Windows Desktop `export_presets.cfg` 和 `tools/validate_content_alpha_package.py`，先验证项目内半身像导入资源全部使用 `res://` 目标路径，再用 Godot CLI 导出 `builds/content_alpha/newsanguo_content_alpha.pck`。
  - 根因：完成项目内资源导入后，必须确认这些 PNG 会被 Godot 打包系统实际收集；只在编辑器里能加载不等于导出包可用。
  - 边界：本任务只做 `.pck` 包烟测，不提交 `builds/` 临时产物，不生成平台 exe；Windows Desktop 预设为后续正式桌面导出提供基础。
  - 验收：包就绪脚本必须确认 212 张导入 PNG 和 426 条英雄绑定；Godot `--export-pack` 必须成功生成非空 `.pck`；导出期间生成的 `.png.import` 和脚本 `.uid` 必须纳入版本库，保证导入设置可复现。
  - 验证：
    - `py -3.14 tools\validate_content_alpha_package.py` 通过。
    - `Godot --headless --export-pack "Windows Desktop" builds\content_alpha\newsanguo_content_alpha.pck` 通过。
    - `py -3.14 tools\validate_content_alpha_package.py --pck builds\content_alpha\newsanguo_content_alpha.pck` 通过，`.pck` 大小为 `181152528` bytes。

- [x] Task 17：可复用半身像武将池
  - 状态：已完成。
  - 范围：新增 `tools/export_reusable_hero_portrait_pool.py`，从项目内半身像导入清单导出 `data/content_alpha/reusable_hero_portrait_pool.json`，形成 212 张唯一 `halfBody` PNG 的可复用候选池；Godot 侧新增校验器和读取入口。
  - 根因：源项目也是三国题材，半身像可以复用，但源项目的技能、传记、君略、官职、势力和数值不是本项目业务规则；如果把这些字段导入，会污染正式武将设计。
  - 边界：只记录图片资源、尺寸、哈希和源英雄名参考；不导入源项目玩法字段；最终武将库可以只从有半身像的约 200 名武将中选择，不强行补齐没有半身像的角色。
  - 验收：池内必须正好对应 212 张项目内导入 PNG；缺图片必须失败；记录中出现 `skill_ids / secret_ids / biography_cn / source_power` 等源玩法字段必须失败；`UI_gj_gg_basemap_hero_1004` 必须保留 `1004` 和 `2000501` 两个赵云源绑定用于识别同图复用。
  - 验证：
    - `py -3.14 tools\export_reusable_hero_portrait_pool.py` 通过，导出 212 张可复用半身像。
    - `test_reusable_hero_portrait_pool.gd` 通过，确认池结构、运行时读取、同图源绑定、源玩法字段泄漏失败和缺图片失败。

- [x] Task 18：调试面板显示可复用半身像池摘要
  - 状态：已完成。
  - 范围：`ContentAlphaValidationRunner` 接入 `ReusableHeroPortraitPoolLoader`，默认校验摘要增加 `reusable_portraits=212` 和半身像池范围规则；半身像预览面板同步显示可复用数量。
  - 根因：可复用半身像池如果只存在于 JSON 和测试中，编辑器运行时无法直观看到最终可选资源规模；调试面板应该显示 426 条源英雄绑定与 212 张唯一可复用图之间的区别。
  - 边界：只显示资源池摘要，不把 212 张图自动生成正式武将，不导入源项目技能、传记、君略或数值。
  - 验收：默认 Content Alpha 校验必须读取半身像池并显示 `可复用=212`；首图必须能从半身像池反查到刘备；校验摘要必须携带禁止导入源玩法字段的范围规则。
  - 验证：
    - `test_content_alpha_validation_runner.gd` 通过，确认聚合校验包含 212 张可复用半身像和范围规则。
    - `test_hero_portrait_preview_panel.gd` 通过，确认调试面板组件显示 `可复用=212`。
    - `test_debug_panel_layout.gd` 通过，确认调试面板仍能加载半身像预览组件。

- [x] Task 19：半身像预览列表切换到可复用图池
  - 状态：已完成。
  - 范围：新增 `ReusableHeroPortraitPoolPresenter`，调试面板默认预览从 `ReusableHeroPortraitPoolLoader` 读取 212 张可复用半身像池；`HeroPortraitTextureLoader` 支持只通过项目内 `portrait_res_path` 加载纹理，不再要求 UI 预览行携带外部源项目路径。
  - 根因：源项目 426 条英雄绑定只是审计映射来源，不等同于本项目武将候选名单；用户已明确本阶段只看半身像能否复用，最终可以只做有半身像的约 200 名武将。
  - 边界：预览列表只展示可复用图片候选，不自动生成正式武将属性；外部源路径仍可用于审计测试，但默认运行时预览走项目内导入资源。
  - 验收：默认预览必须来自 212 张可复用图池；缺项目内 PNG 必须失败；纹理加载在只有 `portrait_res_path` 时必须成功；调试面板仍显示首图刘备和 `可复用=212` 摘要。
  - 验证：
    - `test_reusable_hero_portrait_pool_presenter.gd` 通过，确认图池预览行、非法数量和缺图片失败。
    - `test_hero_portrait_texture_loader.gd` 通过，确认项目内资源路径可独立加载。
    - `test_hero_portrait_preview_panel.gd` 与 `test_debug_panel_layout.gd` 通过，确认面板预览切换后仍可运行。

- [x] Task 20：可复用半身像浏览组件
  - 状态：已完成。
  - 范围：新增 `ReusableHeroPortraitBrowserPanel` 独立场景和脚本，提供 212 张可复用半身像的列表、选中详情和项目内 PNG 预览；支持按 `halfBody` 选择指定候选。
  - 根因：只显示前三条预览无法支撑后续正式武将 UI 选图；需要一个可复用组件让设计和 UI 能浏览完整图池，同时仍保持“只复用半身像，不复用源玩法字段”的边界。
  - 边界：组件不生成正式武将、不写入武将属性、不做源项目技能/传记/君略映射；缺项目内 PNG 时直接失败并显示错误。
  - 验收：默认加载必须出现 212 项；首项刘备可加载纹理；选择 `UI_gj_gg_basemap_hero_1004` 必须显示赵云且源绑定数为 2；缺图必须失败。
  - 验证：
    - `test_reusable_hero_portrait_browser_panel.gd` 通过，确认节点结构、默认加载、按 `halfBody` 选择和缺图失败。

- [x] Task 21：打包校验接入可复用半身像池
  - 状态：已完成。
  - 范围：扩展 `tools/validate_content_alpha_package.py`，在校验导入清单和 `.pck` 基础上，同步校验 `reusable_hero_portrait_pool.json`。
  - 根因：半身像池已经成为 Content Alpha 默认 UI 数据源；如果打包校验仍只看导入清单，可能漏掉池记录指向未导入 PNG 或源玩法字段泄漏。
  - 边界：只校验池记录与已导入 PNG 一致，不检查正式武将属性，因为本阶段尚未生成正式武将库。
  - 验收：包校验脚本必须输出 `reusable_portraits=212`；池记录必须全部指向已导入资源；出现 `skill_ids / secret_ids / biography_cn / source_power` 等源玩法字段必须失败。
  - 验证：
    - `py -3.14 tools\validate_content_alpha_package.py` 通过，确认 212 张导入 PNG、426 条源绑定和 212 张可复用半身像池一致。

- [x] Task 22：头像绑定候选武将名册
  - 状态：已完成。
  - 范围：新增 `tools/export_candidate_officer_roster.py`，从 212 张可复用半身像池导出 `data/content_alpha/candidate_officer_roster.json`；Godot 侧新增候选名册校验器和读取入口；Content Alpha 聚合校验和包校验脚本同步接入候选名册。
  - 根因：后续正式武将库需要一个可筛选的“有头像候选名单”，但不能把源项目技能、传记、君略或数值误导入成本项目正式武将内容。
  - 边界：候选名册只包含 `candidate_officer_id / display_name_cn / selection_status / half_body / portrait_res_path / source_reference`；不包含统率、武力、智力、政治、魅力、势力、官职、技能、传记或君略。
  - 验收：候选名册必须包含 212 条记录；每条记录必须指向项目内导入 PNG；默认状态为 `candidate`；泄漏玩法字段、缺图或非法选择状态必须失败；赵云头像候选必须保留两个源绑定用于识别同图复用。
  - 验证：
    - `py -3.14 tools\export_candidate_officer_roster.py` 通过，导出 212 条候选武将。
    - `test_candidate_officer_roster.gd` 通过，确认名册结构、读取、字段边界、缺图失败和非法状态失败。
    - `test_content_alpha_validation_runner.gd` 通过，确认聚合校验包含 212 条候选武将。
    - `py -3.14 tools\validate_content_alpha_package.py` 通过，确认候选名册与项目内导入 PNG 一致。

- [x] Task 23：候选武将名册浏览组件
  - 状态：已完成。
  - 范围：新增 `CandidateOfficerRosterBrowserPanel` 独立场景和脚本，读取头像绑定候选武将名册，显示列表、选择状态筛选、摘要、详情和项目内 PNG 预览。
  - 根因：候选名册需要被设计和 UI 浏览、筛选和核对，不能只停留在 JSON；但当前仍不能把筛选结果伪装成正式武将库。
  - 边界：组件只展示和筛选 `candidate/selected/rejected` 状态，不写回正式武将属性，不生成势力、官职、技能或传记。
  - 验收：默认加载必须显示 212 条候选；状态筛选必须正确统计 `candidate/selected/rejected`；选择赵云候选必须显示源绑定数为 2；缺项目内 PNG 必须失败。
  - 验证：
    - `test_candidate_officer_roster_browser_panel.gd` 通过，确认节点结构、默认加载、状态筛选、赵云候选详情和缺图失败。

- [x] Task 24：候选武将选择状态导出工具
  - 状态：已完成。
  - 范围：新增 `tools/update_candidate_officer_selection.py`，从候选武将名册读取记录，只允许把指定候选 ID 的 `selection_status` 更新为 `candidate/selected/rejected` 并导出到目标文件。
  - 根因：后续筛选约 200 名武将时需要可重复、可审计的状态变更方式，不能让人手改 JSON 时误写技能、属性、势力或非法状态。
  - 边界：工具只修改 `selection_status`；不写回正式武将库，不生成属性，不自动补齐没有头像的武将，不允许未知候选 ID 或非法状态。
  - 验收：合法状态变更必须输出新名册和状态计数；未知候选 ID 必须失败；输出文件仍必须通过候选名册结构规则。
  - 验证：
    - `py -3.14 tools\update_candidate_officer_selection.py --output tmp\candidate_roster_selection_test.json --set CANDIDATE_UI_GJ_GG_BASEMAP_HERO_1001=selected --set CANDIDATE_UI_GJ_GG_BASEMAP_HERO_1002=rejected` 通过，输出 `selected=1 / rejected=1 / candidate=210`。
    - 未知候选 ID 验证返回非 0，并输出 `candidate officer id not found`。

## 当前缺口

- 半身像资源来自项目负责人另一个自有三国项目；项目内导入流程、运行时 `res://` 加载、`.pck` 打包烟测、212 张可复用半身像池、头像绑定候选武将名册和包校验一致性检查已经完成。
- 正式武将数据、技能、官职、势力剧本尚未进入 Content Alpha 内容包；本阶段不复用源项目技能、传记、君略或数值，候选名册也不代表正式武将库。
- 正式 UI 信息架构和视觉风格仍未落地；当前只准备可复用半身像池入口、候选武将名册、选择状态工具、独立浏览组件与调试面板可见摘要。
