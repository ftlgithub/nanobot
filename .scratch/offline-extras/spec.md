---
labels: [ready-for-agent]
---

# Spec: nanobot 离线 Extras 包（CLI App + Skill + MCP）

## Problem Statement

离线安装包（`nanobot-offline-*`）只带通用 nanobot（网关 + 内置 skill）。内网服务器装完后，告警分析等实际工作链路仍不可用：缺内部 CLI App（`dct-north-cli`、`cli-anything-asset-historical-data`、`chart`）、缺业务 skill（`alert-analysis`、`dynamic-monitor`、`doc-page`）、缺 `fastgpt-knowledge` MCP。这些资产目前散落在开发机上，且其安装态（`installed.json` 的入口路径、MCP 启动命令）全是**机器绝对路径**，直接拷贝到离线机不可用。

另外，产品自动安装 CLI App 的路径（`install()`）在离线环境下**无法拿到真实 skill 内容**（`_fetch_skill_content()` 需联网，失败即回退通用占位），且会**删除** `workspace/skills/cli-app-*` 目录、改走需启用的插件路径——直接用它会破坏预期的 skill 名称与内容。

## Solution

新增**独立的跨平台 extras 离线包**（`nanobot-extras-<version>.tar.gz`）：主包保持通用；extras 携带内部 CLI 的预编 wheel、`chart` 本地脚本目录、真实 skill 内容、`fastgpt-knowledge` MCP 目录、一个 **Python 安装器**（`installer.py`）以及一个**薄包装** `install-extras.sh`。安装器在**断网环境**下把 CLI 装进自带 Python、软链入口到 PATH、**手工种子化 `installed.json`**（绕开会删 skill 的自动路径）、把 skill 拷进 `<workspace>/skills/`、并把 MCP 配置 merge 进 `~/.nanobot/config.json`（改写写死的 conda 命令）。

**逻辑载体决策**：安装逻辑写在 Python 安装器里，`.sh` 只做"定位自带 Python → 调用安装器"的薄引导。理由：MCP 配置 merge 是 JSON 读-改-写，bash 下需 `jq`/`sed` 拼串、易错难测；Python 实现安全且可单测，且未来任何新入口（CLI 子命令/WebUI/agent 工具）只需薄包装复用同一个安装器。

## User Stories

1. As a 运维工程师, I want to 在无网服务器上装完主包后再装 extras, so that 内部 CLI/Skill/MCP 全部可用。
2. As a 运维工程师, I want to 一条命令完成 extras 安装, so that 不需要手工改路径/配置。
3. As a 运维工程师, I want to extras 与主包同版本配套, so that 不会出现版本错配。
4. As a 运维工程师, I want to 安装器支持传参指定主包 prefix 与 workspace, so that 多实例也能装对位置。
5. As a 运维工程师, I want to 不传参时自动探测 prefix/workspace, so that 常规安装零参数。
6. As a 运维工程师, I want to 探测结果可疑时安装器拒绝执行并报错, so that 不会静默装到错误的 Python。
7. As a 运维工程师, I want to 安装器幂等可重跑, so that 升级或修复时不会累积脏状态。
8. As a 扩展用户, I want to 离线机上 `alert-analysis` skill 可用, so that 告警根因分析链路（DCT Nanobot 扩展）端到端可用。
9. As a 扩展用户, I want to `dynamic-monitor`、`doc-page` skill 可用, so that 机房巡检与文档生成可用。
10. As a 终端用户, I want to `run_cli_app` 能调起 `dct-north-cli`/`chart`/`cli-anything-asset-historical-data`, so that 拓扑/测点/告警/图表查询都能跑。
11. As a 终端用户, I want to CLI 入口在 PATH 上可解析, so that `run_cli_app` 不会报 "not available on PATH"。
12. As a 终端用户, I want to skill 名与开发机一致（`cli-app-dct-north-cli` 等）, so that 行为与调试经验可复用。
13. As a 知识库用户, I want to `fastgpt-knowledge` MCP 在离线机可用, so that MQTT 知识库问答可用。
14. As a 知识库用户, I want to MCP 启动命令自动改写为自带 Python, so that 不依赖不存在的 conda 环境。
15. As a fork maintainer, I want to extras 打包复用现有构建流程风格, so that 与主包构建/发版记录一致。
16. As a fork maintainer, I want to 断网端到端验证, so that 发出的包确实可用。
17. As a fork maintainer, I want to extras 内容来源可追溯（取自哪个 commit/路径）, so that 出问题能定位。

## Implementation Decisions

### 范围（已确认）

| 类别 | 内容 |
|---|---|
| CLI App | `dct-north-cli`、`cli-anything-asset-historical-data`（预编 wheel）、`chart`（本地 Python 脚本目录） |
| Skill | `alert-analysis`、`dynamic-monitor`、`doc-page`、`cli-app-dct-north-cli`、`cli-app-chart`、`cli-app-cli-anything-asset-historical-data` |
| MCP | `fastgpt-knowledge`（本地 Python MCP server + 内部 API 凭据） |
| 不含 | `obsidian`/`drawio`/`dify-workflow`/`pm2`/`ego-browser`、开发辅助 skill（`grilling`/`to-spec`/`to-tickets`） |

### 包形态

- **单一跨平台包**：全部内容为纯 Python/markdown（已核实无 `.so`/`.dylib`），无需按平台分包。
- 形态沿用主包风格：`nanobot-extras-<version>.tar.gz`，内含 `wheels/`、`cli-apps/chart/`、`skills/`、`mcp/fastgpt-knowledge/`、`install-extras.sh`、`README/安装说明`。
- 与主包**分开分发**：主包保持通用、不含内部资产与凭据（`fastgpt-knowledge` 的 api_key）。

### 关键决策：不走 `install()`，改手工种子化

已实测确认以下行为，据此决定绕开产品自动安装路径：

| 实测结论 | 影响 |
|---|---|
| `install_skill()` 会 `rmtree` 掉 `workspace/skills/cli-app-<name>`，改写 `workspace/plugins/...` | 先拷 skill 再调 install() 会把刚拷的删掉 |
| `_record_installed()` 会启用插件（`set_agent_plugin_enabled(..., True)`），skill 以 `cli-app-<name>` 可见 | 自动路径能用，但引入 plugins 目录 + `enabled` 指纹状态 |
| 对 `dct-north-cli` 同时打包 skill 并调 install() 会产生**两个 skill**（`dct-north-cli` + `cli-app-dct-north-cli`） | 重复，需避免 |
| 离线 `_fetch_skill_content()` 拉 URL 失败 → `_fallback_skill()` 生成**通用占位** | 自动路径拿不到真实 skill 内容，仍需手工提供 |
| 手工种子化 `installed.json` 后 `get_app()` 离线解析成功 | 种子化可行且足够 |
| `run()` 用 `shutil.which(entry_point)` 定位 CLI | 入口必须在 PATH 上 |

**因此**：extras 安装不调用 `install()`/`install_skill()`；改为写 `installed.json` + 直接投放 skill 文件。

### Skill 投放位置与作用域

- 投放目标：`<workspace>/skills/`（workspace 由安装器定位）。
- 作用域事实（已核实）：skill 根在网关启动时由 `--workspace` 固定，`ContextBuilder` 只构造一次；UI 的 workspace_scope 切换**不影响** skill；用不同 `--workspace` 重启则 skill 不可见。
- 因此安装器接受 workspace 参数；文档说明"换 `--workspace` 需重跑 extras"。

### 命名对齐

- `dct-north-cli` skill 更名为 `cli-app-dct-north-cli`，与另两个已带前缀的 CLI skill 统一，且与产品 `_skill_name()` 约定一致。
- 开发机同步改名（目录 + `name:` 字段），保持两边一致。
- 已核实无硬引用（无 `$dct-north-cli`）；`run_cli_app` 用 app 名而非 skill 名；对 gitlab 仓库 `cloud-ops/dct-north-cli` 无影响（仓库未打包/暴露 SKILL.md 给 nanobot）。

### 安装器契约（Python 安装器 + `.sh` 薄包装）

**载体划分**

- `installer.py`（extras 包内，纯 stdlib）：承载全部安装逻辑，可在任意平台用任意 Python 3 调用。
- `install-extras.sh`（薄包装，~10 行）：定位目标主包的自带 Python → 以它调用 `installer.py`，透传参数与退出码。首个步骤（找 Python）必须留在 shell，因为调用者还不知道用哪个解释器。

**接口**：`install-extras.sh [<nanobot-prefix>] [<workspace>]`（等价 `installer.py --prefix <p> --workspace <w>`）；**传参优先**，缺省自动探测（prefix 由 PATH 上的 `nanobot` 反推；workspace 由 config 读取）；探测结果不合理（如 prefix 下无 `python/bin`）时**报错拒绝**。

**步骤**（安装器内实现）：

1. 解析/校验 prefix 与 workspace（必要时要求显式传参）
2. `pip install --no-index --no-deps` 两个预编 wheel 进 `<prefix>/python`
3. 拷 `chart` 目录到数据目录的 `cli-apps/chart/`
4. 软链 3 个 CLI 入口到 `<prefix>/bin/`（该目录已在 PATH）
5. 种子化 `installed.json`（3 个 App，`entry_point` 与 `entry_point_path` 指向新位置）
6. 拷 6 个 skill 到 `<workspace>/skills/`
7. 拷 `fastgpt-knowledge` 到数据目录的 `mcp/`，并 merge `~/.nanobot/config.json` 的 `tools.mcpServers.fastgpt-knowledge`（`command` 改写为自带 Python，**先备份**原配置）
8. 打印摘要与后续提示（PATH、MCP 需重载或重启网关）

**幂等**：重复执行结果一致；不改动既有无关配置项。

**未来入口复用（本次不实现）**：任何新入口（A. `nanobot` CLI 子命令 / B. WebUI 操作 / C. 聊天或 agent 工具）都只需薄包装调同一个 `installer.py`；B/C 涉及权限门禁（沿用 `webuiAllowRemotePackageInstall` 语义）与安全评审，须另立议题。

### MCP 配置

- `fastgpt-knowledge` 的 `config.json`（含内部 api_key）随 extras 走；配置以 **merge** 方式写入，`command` 从 `/opt/anaconda3/bin/conda run -n nanobot-312 python3` 改写为 `<prefix>/python/bin/python`。
- MCP server 依赖（`httpx`、`mcp`）已在主包核心依赖中，**无需额外 wheel**。

## Testing Decisions

- **好的测试**：只断言外部可观察行为——安装命令退出码、`run_cli_app` 是否真能调起 CLI、`list_skills` 是否含预期 skill 名、MCP 是否启动并列出 tools、文件是否落在预期位置。不断言内部实现细节。
- **测试 seam（单一最高层）**：断网环境（Linux 容器 `--network none` + macOS 干净 HOME）中，装完主包 + extras 后的**网关/CLI/skill 对外行为**。
- 验证矩阵：
  | 项 | 断言 |
  |---|---|
  | 安装命令（.sh 薄包装） | 退出码 0；重跑幂等 |
  | CLI 可调用 | `run_cli_app(name)` 三个 App 均返回结果；入口在 PATH 可解析 |
  | Skill 可见 | `list_skills()` 含 6 个预期名；`cli-app-dct-north-cli` 存在且无重复 |
  | MCP | server 能启动并列出 tools（**不验**内网 API 连通性，测试环境不可达） |
  | 路径改写 | `installed.json` 无开发机绝对路径；MCP command 指向自带 Python |
  | 回归 | 主包原有冒烟（bootstrap→建会话→删会话→health）仍通过 |
- **prior art**：主包离线包的断网容器验证流程（`packaging/README.md`、`.scratch/offline-installer/`）；skill/CLI 行为断言可复用 `tests/` 中既有 CliAppManager/SkillsLoader 测试风格。
- **安装器附加测试面（Python 载体带来的收益）**：`installer.py` 的纯函数部分（定位/校验、config merge、`installed.json` 生成）可用临时目录直接单测，不必等端到端容器——测 merge 不破坏无关字段、测探测拒绝逻辑、测幂等重跑。断言仍只看外部结果（文件内容/退出状态），不测内部函数结构。
- 构建期须验证的既有结论（防回归）：种子化 `installed.json` 后 `get_app()` 可离线解析；`shutil.which` 能找到软链入口。

## Out of Scope

- 不把 extras 内容并入主包（保持主包通用、避免凭据扩散）。
- 不含 `ego-browser`（独立浏览器应用，需其自身离线安装；`dynamic-monitor` 的 NAV 路径不依赖它，已确认可接受）。
- 不含第三方 CLI App（`obsidian`/`drawio`/`dify-workflow`/`pm2`）与开发辅助 skill。
- 不修产品侧 `install()`/`install_skill()` 的离线行为（不改 fork 代码）；如未来要"标准化走 install()"，需另立需求（涉及：先种子化、PATH、覆盖 stub、接受 `cli-app-*` 改名与 plugins 状态）。
- 不把 workspace skill 的增量回灌 gitlab 仓库 `cloud-ops/dct-north-cli`（独立事项；当前 workspace 版 348 行 vs 仓库版 316 行，离线包以 workspace 版为准）。
- 不做多 workspace 的全局 skill 共享（未选定 B/C 方案）。
- 不验内网 API（`192.168.12.37:3000`）连通性。

## Further Notes

- 事实核查记录（本次对话实测，可作为实现依据）见上文「关键决策」表；复现方式：临时 workspace + 临时 `data_dir` 调 `CliAppManager.install_skill()`/`_record_installed()`/`get_app()`，再用 `SkillsLoader.list_skills()` 观察可见性。
- `~/.nanobot/skills/` 是**遗留目录，代码不读**（全库无引用），不要作为投放目标。
- extras 与主包版本需配套（`<version>` 一致）；发版记录建议并入 `packaging/RELEASES*.md` 或新增 extras 章节。
- 若后续离线机出现 skill 名重复或 MCP 启动失败，排查顺序：`installed.json` 条目 → PATH 上的入口 → `workspace/skills/` 实际内容 → config 的 `mcpServers` 段。

### 未来入口（A/B/C）— 已评估，本次不实现

背景：本次交付的 `installer.py` 是唯一安装逻辑载体；以下入口都只是"薄包装调同一个安装器"。为便于将来接入，`installer.py` 的接口应预留 `--prefix` / `--workspace` / `--dry-run` / `--json`。

**A. `nanobot extras install <tarball>`（CLI 子命令）— 推荐优先**

- 做法：在 fork 补丁层加一个薄 CLI 子命令（遵循 `# FORK-HOOK` 约定）；主包**不含安装逻辑**，命令接收 tarball 后运行时从包内解出 `installer.py` 执行，避免逻辑二次实现、也避免把内部资产塞进主包。
- 收益：与 `nanobot gateway/plugins/sessions` 风格统一；运维不必先解压找 `.sh`。
- 代价：改动 fork 代码（跨上游 rebase 需维护该命令）。
- 风险：低（本地操作者权限）。

**B. WebUI 操作（上传/指定路径）— 次之**

- 做法：新增 API + 设置页入口，网关进程内执行安装器。
- 门禁：沿用 `webuiAllowRemotePackageInstall`（默认 False）；本地客户端可放宽。
- 风险：中——"上传即远程装包"是提权面，必须**校验 SHA256 清单**、限定路径/来源，并记录审计。
- 运行时可即时生效项已核实：`installed.json`（每次读文件）、workspace skill（每次扫描）、CLI 入口（每次 `shutil.which`）；**MCP 需调用已有的 `mcp_provider.reload`**（无需重启进程）。

**C. 聊天 / agent 工具 — 不建议**

- 做法：新增 agent 工具（如 `install_extras`），对话触发。
- 风险：**最高**——prompt 注入可诱导安装任意包；即使白名单路径，agent 仍可能被诱导。
- 若最终必须做：仅限本地 trusted WebUI 连接 + 显式人工确认 + 路径白名单 + SHA256 校验 + 审计日志，且需独立安全评审。

---

### 扩展安装卡片（D / E 两条实现路径）— 已评估，本次不实现

需求形态：复用扩展已有的**场景引导卡片**（`content/scenario-cards.js` 硬编码数据 + `scenario-cards-ui.js` 渲染，点击回调）新增一张"安装 extras"卡片。两条实现路径共用卡片 UI，差别在"点下去之后谁执行安装"。

**共同前提（安全）**：扩展面板挂在页面 DOM（`#dct-nanobot-root`），**无 shadow DOM 隔离**，且现有代码**无 `isTrusted` 校验**；`host_permissions: http://*/*` 意味着内容脚本被注入任意页面。因此**装包类卡片必须校验 `event.isTrusted === true`**（合成点击为 `false` 直接忽略），否则任意页面可诱发安装。

**D. 卡片 → 网关 mutation（受控版）** ← 即上面的 B，用扩展卡片替代 WebUI UI

- 扩展侧：
  1. `scenario-cards.js` 加卡片数据（id/icon/title/prompt/group/order，title 走 i18n key）
  2. `scenario-cards-ui.js` 支持按卡片 id 分流到 `onInstall`（现仅 `onSend(prompt)`）
  3. 调 `ws.requestMutation('extras.install', {path})`——**基础设施已具备**（本 fork 已实现 `requestMutation` + `webui_response` 关联）
  4. 装前查状态：`PROXY_FETCH` → `GET /api/webui/extras/status`，据此显示"已装/可装"
  5. `isTrusted` 校验；建议加二次确认（扩展已有确认弹层模式可参考 `session-manager-ui` 的删除确认）
  6. i18n 词条（zh/en）
- nanobot 侧（**必须改**，已核实无现成通道）：
  1. `nanobot/webui/ws_http.py` 的 `_WEBUI_MUTATION_PATHS` 加 `"extras.install": "/api/webui/extras/install"`（字典驱动，自动纳入 mutation 门禁）
  2. `_dispatch_misc_routes`（与 `/api/webui/skills/install` 并列处）加路由分支
  3. 新增 `_handle_extras_install(connection, request)`：校验入参路径（**白名单目录 + 存在性**）→ 解压到临时目录 → 用 `<prefix>/python` 子进程执行包内 `installer.py` → 触发 `mcp_reload`（回调已在 handler 构造参数中存在）→ 返回结果
  4. 新增 `_handle_extras_status()`（可选但卡片体验需要）
  5. 门禁：沿用 `webuiAllowRemotePackageInstall` 语义或仅允许本地浏览器请求；**审计日志**
  6. 测试：路径校验、门禁、幂等
- 代价：新增一处 **`ws_http.py` 改动**（fork 冲突高发文件，需按 `# FORK-HOOK` 约定标注维护）；总计约 100 行 + 测试
- 收益：动作固定、可审计、不经 LLM、可回状态给 UI

**E. 卡片 → prompt 让 agent 装（零后端版）**

- 做法（复用现有卡片机制）：
  1. 卡片点击 → **预填输入框**（扩展已有 `_applyInputValue()` 预填先例，用于草稿/历史导航），而非直接发送
  2. 用户在输入框里确认/修改 tarball 路径后手动发送
  3. 该消息进对话 → agent 用**现有 `exec` 工具**执行安装（解压 + 跑 `install-extras.sh`）
  4. agent 在对话里回报结果
- nanobot 侧：**零改动**
- 扩展侧：卡片数据 + i18n + "预填而非发送"分支 + `isTrusted` 校验（小改动）
- **关键缓解点**：选"预填"而非"直接发送"后，页面合成点击只能改输入框内容，**仍需用户手动点发送**，天然消解了"任意页面诱发安装"的风险
- 约束（须在文档注明）：
  1. agent 的 `exec` 受 `restrict_to_workspace` 约束——extras 包若在 workspace 之外，Restricted 模式下会被拦截，需 Full Access 或把包放进 workspace
  2. 经 LLM 解释，**动作不确定**（可能读错路径、反问、甚至虚报成功）
  3. **无状态接口**：装没装成功只能靠对话输出或手动验证（D 的 status 接口能解决这点）
  4. 安装器幂等 → 重复执行安全
- 风险：中高（等同 C 类"agent 执行命令"，但由用户手动点发送、且路径固定可大幅收窄）

**D 与 E 的取舍**

| 维度 | E（prompt → agent） | D（卡片 → mutation） |
|---|---|---|
| nanobot 改动 | **零** | `ws_http.py` +~100 行（新增 FORK-HOOK） |
| 扩展改动 | 小 | 中（mutation 调用 + 状态查询 + 确认） |
| 动作确定性 | 低（经 LLM） | 高（固定动作） |
| 可审计 / 可回状态 | 否 | 是 |
| 前置条件 | `exec` 可用 + 权限足够 | 门禁通过 |
| 风险 | 中高 | 中 |

**决策**：本次只交付 `installer.py` + `.sh` 薄包装（手动路径）。若将来要做扩展卡片：**优先 E**（零 nanobot 改动、预填已消解主要风险），需要"确定性 + 可审计 + 状态回显"时再升级到 **D**。A/B/C 与 D/E 均待需求触发，各自另立议题（B/D 涉及新 API 与门禁，须含安全评审）。
