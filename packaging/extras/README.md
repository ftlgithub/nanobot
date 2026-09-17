# packaging/extras/ — nanobot 离线 Extras 包构建区

主包（`packaging/`）只装通用 nanobot；内部业务资产（CLI App / Skill / MCP）走**独立的
extras 包**，避免内部信息与凭据进入通用包。

## 目录

| 路径 | 说明 | 进 git？ |
|---|---|---|
| `stage-assets.sh` | 从本机源目录收集资产到 `assets/` | ✅ |
| `installer.py` | 安装器（纯 stdlib）：定位/装 wheel/软链/种子化/拷 skill/MCP merge | ✅ |
| `install-extras.sh` | 薄包装：定位主包自带 Python → 调用 `installer.py` | ✅ |
| `README.md`（本文件） | 流程与边界说明 | ✅ |
| `assets/` | 内部资产实际内容（含内网信息与凭据） | ❌ **gitignored** |
| `assets/SOURCES.md` | 资产清单与哈希（staging 时自动生成） | ❌（随 assets） |

> `assets/` 不入库的原因：内含内网 IP、设备 GUID、平台拓扑细节（skills）与 MCP api_key；
> 本仓库有 GitHub 远端，禁止推送这些内容。内容由 `stage-assets.sh` 从本机源目录重建。

## 流程

```
1. packaging/extras/stage-assets.sh          # 收集资产（需能访问本机源目录）
2. packaging/build-extras.sh                 # 组包 → nanobot-extras-<ver>.tar.gz
   （内含 assets/ + installer.py + install-extras.sh + 安装说明）
3. 目标机（断网）：tar -xzf ... && bash install-extras.sh <prefix> <workspace>
```

## 资产内容（类别）

- **wheels/**：内部 CLI 的预编 wheel（依赖 `click`/`rich`，均已在主包核心）
- **cli-apps/chart/**：本地脚本型 CLI App
- **skills/**：业务 skill（告警分析、动环监控、文档页，及 CLI 使用技能）
- **mcp/fastgpt-knowledge/**：本地 MCP server + 凭据

全部为纯 Python / markdown（无平台二进制）→ **单一包跨平台**。
`stage-assets.sh` 会在收集后校验这一点，并清理 `.git`/`__pycache__`/`*.pyc`/`.DS_Store`。

## 安装器行为要点

- **不调用**产品自带的 `install()`/`install_skill()`——实测它会删除 `workspace/skills/cli-app-*`
  并把 skill 挪进需启用的 plugins；改为**手工种子化 `installed.json`** + 直接投放 skill 文件。
- CLI 入口软链到 `<prefix>/bin`（已在 PATH），满足产品 `run()` 的 `shutil.which` 检查。
- MCP 配置以 merge 方式写入 `config.json`，`command` 改写为主包自带 Python，**写前备份**。
- 幂等：可重复执行。

设计与实测依据见 `.scratch/offline-extras/spec.md`。

## 验证

必须过：断网环境（Linux 容器 `--network none` + macOS 干净 HOME）装完主包 + extras 后，
脚本退出码 0 且幂等、三个 CLI 可 `run_cli_app` 调起、6 个 skill 可见无重复、
MCP 能启动并列出 tools、`installed.json` 无开发机绝对路径、主包冒烟回归通过。
