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

- [x] Task 25：候选名册进入 Content Alpha 打包烟测
  - 状态：已完成。
  - 范围：重新导出 `builds/content_alpha/newsanguo_content_alpha.pck`，确认候选武将名册 JSON、候选名册浏览场景和相关脚本进入 Godot 打包资源。
  - 根因：上一版 `.pck` 在候选名册之前生成，不能证明新数据和新场景会被打包；Content Alpha 包校验必须覆盖当前真实资源链路。
  - 边界：仍只导出 `.pck` 烟测产物，不提交 `builds/` 临时包，不生成平台 exe。
  - 验收：导出日志必须包含 `candidate_officer_roster.json` 和 `candidate_officer_roster_browser_panel`；包校验脚本必须输出 `candidate_officers=212` 和非空 `.pck`。
  - 验证：
    - `Godot --headless --export-pack "Windows Desktop" builds\content_alpha\newsanguo_content_alpha.pck` 通过，导出日志包含候选名册数据和浏览场景。
    - `py -3.14 tools\validate_content_alpha_package.py --pck builds\content_alpha\newsanguo_content_alpha.pck` 通过，`.pck` 大小为 `181542608` bytes。

- [x] Task 26：Content Alpha 资源工作台场景
  - 状态：已完成。
  - 范围：新增 `ContentAlphaWorkbench` 独立场景和脚本，以 Tab 方式组织候选武将名册浏览组件、可复用半身像浏览组件，并显示 Content Alpha 聚合校验摘要。
  - 根因：半身像池、候选名册和浏览组件已经分散可用，但缺少一个内部工作台承载后续筛选和核对流程；继续塞进右侧调试面板会扩大调试 UI 职责。
  - 边界：工作台是 Content Alpha 内部资源工具，不是 Beta 正式游戏 UI；不写正式武将属性，不改变模拟状态，不保存筛选结果。
  - 验收：工作台必须包含候选名册和半身像池两个 Tab；默认加载必须显示 212 条候选、212 张图池和 426 条源绑定摘要。
  - 验证：
    - `test_content_alpha_workbench.gd` 通过，确认工作台节点结构、默认加载和聚合摘要。

- [x] Task 27：主场景接入 Content Alpha 工作台入口
  - 状态：已完成。
  - 范围：主场景 `CanvasLayer` 挂载默认隐藏的 `ContentAlphaWorkbench`；调试面板新增 `Content Alpha 工作台` 按钮，通过信号请求 `Main` 显示/隐藏工作台。
  - 根因：工作台场景独立存在但缺少运行时入口，不利于在编辑器运行时核对候选名册和图池；入口必须受控，不能让工作台默认遮挡地图或吞掉地图点击。
  - 边界：入口仍属于调试/Content Alpha 工具，不是正式 UI；默认隐藏，不改变模拟状态，不保存筛选结果。
  - 验收：主场景必须包含隐藏工作台；调试面板必须有明确按钮；按钮信号触发后工作台加载 212 条候选和 212 张图池，再次触发可关闭；调试面板根节点仍不拦截地图点击。
  - 验证：
    - `test_main_content_alpha_workbench.gd` 通过，确认主场景隐藏挂载和切换加载。
    - `test_debug_panel_layout.gd` 通过，确认按钮存在且调试面板根节点仍忽略鼠标。

- [x] Task 28：Content Alpha 工作台打包烟测
  - 状态：已完成。
  - 范围：重新导出 `builds/content_alpha/newsanguo_content_alpha.pck`，确认 Content Alpha 工作台场景、主场景入口、候选名册、半身像池和相关脚本进入 Godot 打包资源。
  - 根因：工作台和主场景入口已经成为 Content Alpha 当前资源筛选入口；只通过编辑器测试还不能证明导出包会包含这些场景和脚本。
  - 边界：仍只导出 `.pck` 烟测产物，不提交 `builds/` 临时包，不生成平台 exe。
  - 验收：导出日志必须包含 `content_alpha_workbench.scn` 和主场景 remap；包校验必须继续输出 212 张导入 PNG、212 条候选武将和非空 `.pck`。
  - 验证：
    - `Godot --headless --export-pack "Windows Desktop" builds\content_alpha\newsanguo_content_alpha.pck` 通过，导出日志包含 `content_alpha_workbench.scn`。
    - `py -3.14 tools\validate_content_alpha_package.py --pck builds\content_alpha\newsanguo_content_alpha.pck` 通过，`.pck` 大小为 `181554272` bytes。

- [x] Task 29：Content Alpha UI 信息架构规格
  - 状态：已完成。
  - 范围：新增 `data/content_alpha/ui_navigation_spec.json`，声明战略大地图、城市详情、候选武将工作台、正式武将名册、任命出阵、战报、事件日志和存档读档等 8 个界面的数据源、入口、允许动作、实现状态和阻塞项；Godot 侧新增校验器、读取入口，并接入 Content Alpha 聚合校验、工作台摘要和包校验脚本。
  - 根因：前面已完成资源工作台和调试入口，但正式 UI 仍缺少可追踪的信息架构边界；如果只在文档里描述，很容易把规划页面误当作已实现 UI，或让 UI 层绕过真实数据源。
  - 边界：规格只定义信息架构、数据来源和状态，不制作 Beta 正式 UI，不补齐视觉风格、线框图或正式交互稿；`planned` 界面必须保留阻塞项。
  - 验收：规格必须包含 8 个必需界面；状态只允许 `debug_available / content_alpha_available / planned`；规划界面必须声明阻塞项；`res://` 数据源必须真实存在；聚合校验和包校验必须输出 UI 规格数量。
  - 验证：
    - `test_ui_navigation_spec.gd` 通过，确认默认规格、读取入口和非法状态/缺资源失败。
    - `test_content_alpha_validation_runner.gd` 通过，确认聚合校验包含 `ui_navigation_screens=8`、可用界面 2 个、规划界面 6 个。
    - `test_content_alpha_workbench.gd` 通过，确认工作台摘要显示 UI 规格数量。
    - `py -3.14 tools\validate_content_alpha_package.py` 通过，确认包准备校验包含 UI 信息架构规格。

- [x] Task 30：Content Alpha 工作台浏览 UI 信息架构
  - 状态：已完成。
  - 范围：新增 `UiNavigationSpecPanel` 独立场景和脚本，在 Content Alpha 工作台增加 `UiNavigation` Tab，展示 8 个 UI 规格界面的状态列表、数据源、入口、动作、阻塞项和 Beta 边界说明。
  - 根因：UI 信息架构如果只能通过 JSON 或校验日志查看，设计和实现核对成本较高；工作台应把规格变成可见的内部工具，同时继续暴露规划界面尚未完成的事实。
  - 边界：该 Tab 只浏览规格，不创建正式界面、不改变模拟状态、不把 `planned` 页面包装成已实现玩法。
  - 验收：工作台必须有第三个 UI 信息架构 Tab；默认加载必须显示 8 个界面、1 个调试可用、1 个 Alpha 可用和 6 个规划；选择正式武将名册必须显示 `planned` 状态和 Beta 边界。
  - 验证：
    - `test_ui_navigation_spec_panel.gd` 通过，确认面板节点、默认加载和正式武将名册选择详情。
    - `test_content_alpha_workbench.gd` 通过，确认工作台第三个 Tab 和 8 条 UI 规格记录。

- [x] Task 31：正式 UI 风格方向确认
  - 状态：已完成。
  - 范围：生成并确认第一版正式 UI 风格方向图，归档到 `docs/资源/ui_style_concepts/content_alpha_formal_ui_style_v1.png`，并新增 `docs/UI_正式界面风格方向.md` 记录视觉关键词、信息架构落地原则和未完成边界。
  - 根因：正式 UI 风格不能在没有视觉确认的情况下直接进入 Godot 实装，否则容易把不合适的视觉方向固化到场景和控件结构里。
  - 边界：当前只确认视觉方向，不代表线框图、交互流程、主题资源或正式 UI 控件已经完成。
  - 验收：风格方向必须覆盖战略大地图、右侧城市/武将信息、底部命令栏和半身像卡片；文档必须说明该图不是 Beta 正式 UI 成品。
  - 验证：
    - 项目负责人已确认该风格方向“都合适”。
    - `docs/UI_正式界面风格方向.md` 已记录实装原则和未完成边界。

- [x] Task 32：正式 UI 线框规格
  - 状态：已完成。
  - 范围：新增 `data/content_alpha/ui_wireframe_spec.json`，为战略大地图、城市详情、正式武将名册、任命出阵、战报、事件日志、存档读档和候选武将工作台定义布局区域、组件、状态绑定、交互和阻塞项；新增 Godot 校验器、读取入口、工作台浏览面板，并接入 Content Alpha 聚合校验和包校验脚本。
  - 根因：风格方向和信息架构只能说明“像什么、有哪些入口”，还不能指导正式 UI 实装时每个界面该放哪些区域、绑定哪些真实状态、支持哪些交互。
  - 边界：线框规格只定义正式 UI 实装合同，不创建 Beta 正式控件，不补齐正式武将库、城市库或主题资源；缺真实数据源时仍必须暴露阻塞项。
  - 验收：线框规格必须包含 8 个必需界面；每个界面必须有至少 3 个布局区域、至少 2 个交互、非空组件、非空状态绑定和阻塞项；`res://` 绑定必须真实存在；工作台必须能浏览 8 条线框；包校验必须输出线框数量。
  - 验证：
    - `test_ui_wireframe_spec.gd` 通过，确认默认规格、读取入口、非法状态、缺风格图和布局不足会失败。
    - `test_ui_wireframe_spec_panel.gd` 通过，确认线框浏览面板节点、默认加载和任命出阵线框详情。
    - `test_content_alpha_validation_runner.gd` 通过，确认聚合校验包含 `ui_wireframes=8`、正式线框 7 个、Alpha 工具 1 个。
    - `test_content_alpha_workbench.gd` 通过，确认工作台第四个 Tab 和 8 条 UI 线框记录。
    - `py -3.14 tools\validate_content_alpha_package.py` 通过，确认包准备校验包含 UI 线框规格。

- [x] Task 33：正式 UI 主题 Token
  - 状态：已完成。
  - 范围：新增 `data/content_alpha/ui_theme_tokens.json`，记录正式 UI 风格方向下的色板、字号、间距、圆角、控件状态和响应式规则；新增 Godot 校验器、读取入口、工作台浏览面板，并接入 Content Alpha 聚合校验和包校验脚本。
  - 根因：只有风格图和线框规格还不足以指导控件实装；如果按钮、面板、警告状态和字体大小各处散写，会很快失去统一视觉和可维护性。
  - 边界：主题 Token 只定义视觉约束，不创建 Godot Theme 成品，不选择授权中文字体，不制作屏幕级正式控件。
  - 验收：主题 Token 必须包含必需色板、字号、间距、形状、控件状态和响应式规则；控件状态引用的颜色必须来自色板；风格图引用必须真实存在；工作台必须能浏览 6 组主题 Token；包校验必须输出主题 Token 数量。
  - 验证：
    - `test_ui_theme_tokens.gd` 通过，确认默认 Token、读取入口、非法色值、缺色板引用和缺风格图会失败。
    - `test_ui_theme_token_panel.gd` 通过，确认主题 Token 浏览面板节点、默认加载和控件状态详情。
    - `test_content_alpha_validation_runner.gd` 通过，确认聚合校验包含 15 个色板颜色、圆角 6 和风格图引用。
    - `test_content_alpha_workbench.gd` 通过，确认工作台第五个 Tab 和 6 组主题 Token。
    - `py -3.14 tools\validate_content_alpha_package.py` 通过，确认包准备校验包含 UI 主题 Token。

- [x] Task 34：正式 UI Godot Theme 资源
  - 状态：已完成。
  - 范围：新增 `themes/content_alpha_formal_theme.tres`，由 `data/content_alpha/ui_theme_tokens.json` 生成基础 Godot Theme；新增 Theme Builder、Loader 和生成脚本，校验 Label、Button、PanelContainer 的字号、颜色、圆角和样式与 Token 一致，并在 Content Alpha 工作台加载成功后应用该 Theme。
  - 根因：主题 Token 只定义视觉约束，Godot 运行时仍缺少可加载、可漂移检测的 Theme 资源；如果直接在场景里散写样式，后续正式控件会失去统一来源。
  - 边界：Theme 资源只覆盖基础面板、按钮、字号、间距和焦点样式，不选择授权中文字体，不实现屏幕级正式控件，不把规划界面标记为已完成。
  - 验收：Theme 资源必须真实存在并能由 Godot 加载；资源必须与 Token 对齐，字体大小或样式漂移要失败；工作台必须在校验成功后应用 Theme；包校验必须检查 Theme 资源关键标记。
  - 验证：
    - `test_content_alpha_theme_resource.gd` 通过，确认 Theme 资源可加载、Builder 生成结果符合 Token、漂移会失败。
    - `test_content_alpha_validation_runner.gd` 通过，确认聚合校验包含 Theme 资源路径和 3 个基础控件类型。
    - `test_content_alpha_workbench.gd` 通过，确认工作台应用正式 Theme 并显示主题控件数量。
    - `py -3.14 tools\validate_content_alpha_package.py` 通过，确认包准备校验包含 Theme 资源关键标记。

- [x] Task 35：正式主界面 HUD 外壳
  - 状态：已完成。
  - 范围：新增 `scenes/formal_hud.tscn`、`scripts/ui/formal_hud.gd` 和 `scripts/ui/formal_hud_presenter.gd`，在主场景挂载顶部日期/势力摘要、右侧选择详情和底部命令栏；HUD 使用基础 Theme，读取真实运行时状态，地图选择时同步显示城市/部队详情。
  - 根因：前面已完成风格、线框和 Theme，但主场景仍主要依赖调试面板显示状态；正式 UI 需要先建立屏幕级外壳，让后续城市、任命、出阵等界面有真实挂载位置。
  - 边界：底部命令栏只展示正式入口位置；任命、出阵、战报、事件、存档界面没有真实业务界面前按钮必须保持禁用并显示阻塞原因，不伪造点击结果。
  - 验收：Formal HUD 必须真实挂载到主场景；根节点不得吞掉地图点击；状态缺关键字段必须失败；城市选择必须显示真实城市数据；底部 5 个命令按钮必须禁用。
  - 验证：
    - `test_formal_hud.gd` 通过，确认 HUD 节点、真实状态加载、城市选择和缺状态失败。
    - `test_main_content_alpha_workbench.gd` 通过，确认主场景地图选择会更新 Formal HUD。
    - `test_debug_panel_layout.gd` 通过，确认调试面板原有布局与点击穿透仍正常。

- [x] Task 36：正式城市详情面板
  - 状态：已完成。
  - 范围：新增 `scenes/city_detail_panel.tscn`、`scripts/ui/city_detail_panel.gd` 和 `scripts/ui/city_detail_presenter.gd`，在 Formal HUD 的右侧区域显示城市标题、归属势力、兵力粮草、民心治安、士族支持、整合状态、太守摘要和同势力武将列表；城市选择时自动展示该面板。
  - 根因：Formal HUD 只有文本选择摘要，无法满足城市详情线框中“资源与军事指标、治理状态、太守与属官区、城市动作区”的结构要求。
  - 边界：该任务完成时面板只读；Task 37 后任命和出阵按钮已改为打开真实任命出阵面板，不伪造业务操作。
  - 验收：城市详情必须读取 `runtime_state.cities / forces / officers`；缺城市、缺势力或太守引用错误必须失败；城市选择必须显示真实城市名和势力名；UI 信息架构中城市详情从 `planned` 更新为 `content_alpha_available`。
  - 验证：
    - `test_formal_hud.gd` 通过，确认城市详情节点、真实城市显示、太守摘要和缺势力失败。
    - `test_ui_navigation_spec.gd` 通过，确认城市详情状态为 `content_alpha_available`。
    - `test_ui_navigation_spec_panel.gd` 通过，确认 UI 信息架构摘要更新。
    - `py -3.14 tools\validate_content_alpha_package.py` 通过，确认包准备校验包含城市详情场景。

- [x] Task 37：正式任命出阵面板
  - 状态：已完成。
  - 范围：新增 `scenes/appointment_sortie_panel.tscn`、`scripts/ui/appointment_sortie_panel.gd` 和 `scripts/ui/appointment_sortie_presenter.gd`，从城市详情动作打开任命与出阵面板，读取真实运行时城市、势力、武将、路线、部队序列，并通过 `AppointmentSystem` 与 `SortieSystem` 执行业务修改。
  - 根因：城市详情已有任命/出阵入口，但按钮停留在占位会阻断正式 UI 主流程；必须接入已有真实系统，而不是在 UI 层伪造任命或部队结果。
  - 边界：当前使用基础 `OptionButton` 和 `SpinBox` 作为第一层正式面板控件；不生成假武将、不伪造路线、不绕过兵粮校验；正式武将选择器、路线预览、目标确认和战报反馈仍留作后续专项。
  - 验收：任命必须写入 `city.governor_officer_id` 和武将任命状态；出阵必须扣除城市兵粮、创建 `runtime_state.armies` 部队并递增 `next_army_seq`；缺状态键、缺城市、无同势力武将或无出城路线必须明确失败；UI 信息架构中任命出阵从 `planned` 更新为 `content_alpha_available`。
  - 验证：
    - `test_appointment_sortie_panel.gd` 通过，确认面板节点、真实表单、任命、出阵和非法状态暴露。
    - `test_formal_hud.gd` 通过，确认城市详情动作可打开任命出阵面板，并能通过 HUD 改写真实运行时状态。
    - `test_content_alpha_validation_runner.gd`、`test_content_alpha_workbench.gd` 和 `test_ui_navigation_spec_panel.gd` 通过，确认 UI 信息架构摘要更新为 Alpha 可用 3 个、规划 4 个。
    - `py -3.14 tools\validate_content_alpha_package.py` 通过，确认包准备校验包含任命出阵场景。

- [x] Task 38：正式战报面板
  - 状态：已完成。
  - 范围：新增 `scenes/battle_report_panel.tscn`、`scripts/ui/battle_report_panel.gd` 和 `scripts/ui/battle_report_presenter.gd`，底部命令栏战报按钮可打开正式战报面板，读取真实 `runtime_state.battle_logs / armies / cities`，展示战斗结果、攻守损失、城市归属和跳转目标城市入口。
  - 根因：战斗系统已写入 `battle_logs`，但正式 HUD 缺少战报读取界面；继续只靠调试文本会让战斗结果反馈无法进入正式 UI 主流程。
  - 边界：当前只做第一层只读战报面板；没有生成战斗时显示真实空状态；缺 `battle_logs` 或战报引用的部队/城市断裂必须失败，不创建空假战报；完整战报事件结构、事件流分类和更细的结果解释留作后续专项。
  - 验收：战报必须来自真实 `BattleSystem` 输出；必须显示目标城市、胜者、攻守损失、部队剩余和城市归属；战报按钮必须由 Formal HUD 打开；UI 信息架构中战报从 `planned` 更新为 `content_alpha_available`。
  - 验证：
    - `test_battle_report_panel.gd` 通过，确认真实战报详情、空状态和断裂引用失败。
    - `test_formal_hud.gd` 通过，确认底部战报命令可打开战报面板并读取真实战斗日志。
    - `test_content_alpha_validation_runner.gd`、`test_content_alpha_workbench.gd` 和 `test_ui_navigation_spec_panel.gd` 通过，确认 UI 信息架构摘要更新为 Alpha 可用 4 个、规划 3 个。
    - `py -3.14 tools\validate_content_alpha_package.py` 通过，确认包准备校验包含战报场景。

- [x] Task 39：正式事件日志面板
  - 状态：已完成。
  - 范围：新增 `scenes/event_log_panel.tscn`、`scripts/ui/event_log_panel.gd` 和 `scripts/ui/event_log_presenter.gd`，底部命令栏事件按钮可打开正式事件日志面板，聚合真实 `battle_logs / legitimacy_logs / local_governance_logs / loyalty_logs / diplomacy_logs / scheme_states`，并支持按军事、内政、武将、外交谋略分类筛选。
  - 根因：V0.2/V0.3 已产生多类运行时日志，但正式 HUD 没有统一查看入口；如果继续只在调试面板或测试中查看，用户无法从正式 UI 追踪状态变化。
  - 边界：当前只聚合现有真实日志字典，不创建完整历史事件链，不补事件剧情，不伪造 `change_logs`；日志字段缺失必须失败，空日志显示真实空状态。
  - 验收：面板必须读取现有真实日志；分类筛选必须返回对应日志；缺日志状态键或日志字段缺失必须报错；UI 信息架构中事件日志从 `planned` 更新为 `content_alpha_available`。
  - 验证：
    - `test_event_log_panel.gd` 通过，确认真实日志聚合、分类筛选、空状态和畸形日志失败。
    - `test_formal_hud.gd` 通过，确认底部事件命令可打开事件日志面板。
    - `test_content_alpha_validation_runner.gd`、`test_content_alpha_workbench.gd` 和 `test_ui_navigation_spec_panel.gd` 通过，确认 UI 信息架构摘要更新为 Alpha 可用 5 个、规划 2 个。
    - `py -3.14 tools\validate_content_alpha_package.py` 通过，确认包准备校验包含事件日志场景。

- [x] Task 40：正式存档读档面板
  - 状态：已完成。
  - 范围：新增 `scenes/save_load_panel.tscn`、`scripts/ui/save_load_panel.gd` 和 `scripts/ui/save_load_presenter.gd`，底部命令栏存档按钮可打开正式存档读档面板，显示当前运行时摘要、存档路径、存档 schema 和已有存档摘要，并直接调用 `SaveSystem.save_state / load_state`。
  - 根因：V0.1 已有真实存档系统，但正式 HUD 缺少游戏内入口；如果继续只靠测试或调试脚本保存读取，核心闭环无法从正式 UI 主流程验证。
  - 边界：当前只实现单一 `user://content_alpha_quick_save.json` 快速存档槽；不做多槽管理、不做旧版本迁移、不伪造 base dataset；读档必须依赖主场景传入的真实核心数据集重建静态数据。
  - 验收：保存必须写入真实动态状态；读取必须通过 `SaveSystem` 重建运行时状态并同步主场景、HUD、地图和调试面板；缺状态键、空 base dataset、无存档或损坏存档必须明确失败；UI 信息架构中存档读档从 `planned` 更新为 `content_alpha_available`。
  - 验证：
    - `test_save_load_panel.gd` 通过，确认面板节点、真实保存读取、缺 base dataset 和缺状态键失败。
    - `test_formal_hud.gd` 通过，确认底部存档命令可打开存档读档面板。
    - `test_content_alpha_validation_runner.gd`、`test_content_alpha_workbench.gd` 和 `test_ui_navigation_spec_panel.gd` 通过，确认 UI 信息架构摘要更新为 Alpha 可用 6 个、规划 1 个。
    - `py -3.14 tools\validate_content_alpha_package.py` 通过，确认包准备校验包含存档读档场景。

- [x] Task 41：Content Alpha Playable Slice 主流程优先级调整
  - 状态：已完成。
  - 范围：把下一阶段目标从“继续补齐所有规划面板”调整为“优先形成可玩可看的正式主流程”；正式 HUD 新增目标提示和 `推进一日` 命令，调试面板默认隐藏；出阵后直接开始行军，推进日期会驱动行军、到达后调用真实 `BattleSystem` 自动结算并刷新地图、HUD 和调试状态。
  - 根因：继续把每个低优先级系统都做成完整面板，会推迟真正可演示的游戏体验；当前更需要让玩家从地图、城市、任命、出阵、行军、战斗、战报、存档形成闭环。
  - 边界：该任务不新增假剧情、不伪造战斗结果、不补正式武将名册；武将名册等低优先级功能先保留入口和阻塞说明。自动结算只使用已有真实行军与战斗系统，状态不合法仍失败暴露。
  - 验收：第一屏默认隐藏调试面板；HUD 必须显示当前目标；出阵必须进入行军态；推进一日必须推进日期、行军进度并在接敌后写入真实战报；地图和 HUD 必须随状态刷新。
  - 验证：
    - `test_appointment_sortie_panel.gd` 通过，确认出阵后直接进入 `marching` 并带有行军元数据。
    - `test_formal_hud.gd` 通过，确认 HUD 目标提示和正式命令栏仍可用。
    - `test_main_content_alpha_workbench.gd` 通过，确认调试面板默认隐藏，推进三日后能结算 `BATTLE_1` 并显示接敌反馈。

- [x] Task 42：正式主界面骨架贴近风格图
  - 状态：已完成。
  - 范围：按 `docs/资源/ui_style_concepts/content_alpha_formal_ui_style_v1.png` 的结构重排 Formal HUD，形成顶部标题/日期/势力/目标栏、左侧任务事件面板、右侧城市详情面板、左下武将卡和底部大命令台；调试面板继续默认隐藏。
  - 根因：上一版界面虽然有功能入口，但整体仍像测试面板堆叠，不能直观看出正式 UI 方向；先建立接近设计图的屏幕骨架，后续逐个补功能会更容易评估。
  - 边界：本任务只重排正式主界面骨架和地图可读性，不伪造小地图、完整州郡边界、正式武将库或资源经济；左下武将卡当前使用已导入半身像资源作为视觉占位，后续必须接入正式君主/武将状态。
  - 验收：主界面必须保留真实功能节点路径；左侧任务事件、右侧城市详情、左下武将卡、底部命令台必须同时存在；推进/出阵/战报/存档链路不得被视觉重排破坏。
  - 验证：
    - `test_formal_hud.gd` 通过，确认新版 HUD 骨架节点和原有功能节点同时存在。
    - `test_main_content_alpha_workbench.gd` 通过，确认主流程推进仍能结算战斗。
    - `test_strategic_map_view.gd` 通过，确认地图选择和渲染仍有效。

- [x] Task 43：正式城市详情面板视觉强化
  - 状态：已完成。
  - 范围：强化 Formal HUD 右侧 `CityDetailPanel` 的信息排版，把兵粮民生、治理状态、太守、属官和操作按钮按正式界面区域纵向呈现，减少调试文本感并更接近风格图右侧信息栏。
  - 根因：主界面骨架已经接近设计图，但城市详情仍偏紧凑文本块；如果不先把高频选择反馈做成可读面板，后续补任命、出阵和战报功能时仍难评估第一屏体验。
  - 边界：本任务只调整真实城市详情的展示结构和控件尺寸；不伪造兵力上限、不补虚假的城市资源、不新增未接入业务的操作结果。
  - 验收：城市详情必须继续读取 `runtime_state.cities / forces / officers`；兵力和粮草只显示现有真实字段，民心、治安、士族按百分制展示；任命和出阵按钮必须继续触发真实任命出阵面板。
  - 验证：
    - `test_formal_hud.gd` 通过，确认城市详情仍能加载真实状态和动作入口。
    - `test_main_content_alpha_workbench.gd` 通过，确认主流程推进仍能结算战斗。
    - `test_appointment_sortie_panel.gd` 通过，确认任命出阵面板真实业务入口未被视觉调整破坏。

- [x] Task 44：正式领袖卡接入真实运行时状态
  - 状态：已完成。
  - 范围：Formal HUD 左下角武将卡从静态“刘备 / 声望 / 威名”文案改为读取真实 `runtime_state.forces / officers`，展示当前势力君主、所属势力、正统、名望、忠诚、统率和政治。
  - 根因：左下角卡片虽然接近风格图，但静态历史人物和假数值会与测试运行时状态混淆；Playable Slice 第一屏必须优先消除这类伪正常展示。
  - 边界：本任务只把文本数据接入真实运行时状态；半身像仍作为候选资源示例显示，不把 `OFF_TEST_PLAYER` 强行绑定为刘备或任何源项目武将。
  - 验收：领袖卡必须来自真实势力君主和武将数据；缺君主武将必须失败；界面不得再显示静态 `刘备` 或 `1800/3000` 这类假占位数值。
  - 验证：
    - `test_formal_hud.gd` 通过，确认领袖卡显示测试主将、正统和名望，并拒绝缺失君主武将。
    - `test_main_content_alpha_workbench.gd` 通过，确认主场景正式 HUD 仍能随地图选择和推进流程运行。
    - `test_appointment_sortie_panel.gd` 通过，确认任命出阵业务入口未受领袖卡改动影响。

- [x] Task 45：正式选择摘要可读化
  - 状态：已完成。
  - 范围：Formal HUD 右侧“当前选择”摘要从 `ID / FORCE / ROUTE / OFFICER` 调试字段改为玩家可读文本；城市摘要显示势力名、兵粮、民心、治安、士族和整合状态，部队摘要显示主将名、起止城市、兵粮、行军进度和战果。
  - 根因：主界面已经接近设计图，但选择摘要仍暴露内部 ID，会让第一屏看起来像调试工具；正式 UI 应该优先展示真实业务名称，内部 ID 只用于测试和错误定位。
  - 边界：本任务只格式化已有真实运行时数据；不伪造路线名、不补正式地名、不隐藏断裂引用。部队 route、城市或主将引用断裂必须失败。
  - 验收：城市选择摘要不得常态显示 `CITY_TEST_A / FORCE_PLAYER / ID=`；部队选择摘要不得常态显示 `ROUTE_TEST_A_B / OFF_TEST_PLAYER`；整数指标不得显示为浮点文本；断裂部队路线必须明确失败。
  - 验证：
    - `test_formal_hud.gd` 通过，确认城市和部队摘要使用真实名称，并拒绝断裂部队路线。
    - `test_main_content_alpha_workbench.gd` 通过，确认主场景地图选择仍能驱动 Formal HUD。
    - `test_strategic_map_view.gd` 通过，确认地图选择和渲染入口未被摘要格式化破坏。

- [x] Task 46：正式地图标签可读化
  - 状态：已完成。
  - 范围：战略地图城市标签从硬编码势力简称改为真实势力名，部队标签从 `ARMY_*` 内部 ID 改为真实主将名和兵力；地图渲染状态校验补充 `forces / officers` 引用检查。
  - 根因：主界面第一屏已经开始接近正式 UI，但地图上仍有 `ARMY_1` 等内部 ID，会让可玩演示继续呈现调试感；地图标签必须优先展示玩家能理解的真实名称。
  - 边界：本任务只使用已有运行时 `forces / officers / cities / armies` 数据，不伪造正式武将库、不补半身像绑定、不把缺失引用显示成默认名称。
  - 验收：城市地图标签显示真实势力名；部队地图标签显示真实主将名；常态标签不得显示 `FORCE_PLAYER / ARMY_1 / OFF_TEST_PLAYER`；城市势力或部队主将引用断裂必须失败。
  - 验证：
    - `test_strategic_map_view.gd` 通过，确认地图标签可读化和断裂引用失败。

## 当前缺口

- 半身像资源来自项目负责人另一个自有三国项目；项目内导入流程、运行时 `res://` 加载、`.pck` 打包烟测、212 张可复用半身像池、头像绑定候选武将名册和包校验一致性检查已经完成。
- 正式武将数据、技能、官职、势力剧本尚未进入 Content Alpha 内容包；本阶段不复用源项目技能、传记、君略或数值，候选名册也不代表正式武将库。
- 授权中文 UI 字体、正式武将选择器等屏幕级正式界面仍未落地；当前已准备 Content Alpha 资源工作台及主场景调试入口、可复用半身像池入口、候选武将名册、选择状态工具、独立浏览组件、UI 信息架构规格、UI 线框规格、UI 主题 Token、Godot Theme 基础资源、正式主界面 HUD 外壳、正式城市详情面板、正式任命出阵面板、正式战报面板、正式事件日志面板、正式存档读档面板、Playable Slice 推进一日链路、工作台 UI 规格浏览入口、正式 UI 风格方向图与调试面板可见摘要。
- 后续不再默认把所有规划系统都做成完整面板；低优先级系统可以先保留入口和阻塞说明，优先打磨可玩主流程和第一屏观感。
