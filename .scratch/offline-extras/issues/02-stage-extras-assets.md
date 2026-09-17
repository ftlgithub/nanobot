# 02 — extras 资产 staging + 预编内部 wheel

**What to build:** 离线 extras 包所需的全部素材集中到 `packaging/extras/assets/`，含可离线安装的内部 CLI wheel、`chart` 脚本目录、6 个 skill、MCP 目录，以及一份来源记录（供追溯）。

**Blocked by:** 01 — skill 改名对齐

**Status:** ready-for-agent

- [ ] `packaging/extras/assets/wheels/`：从本地源码预编 `dct-north-cli` 与 `cli-anything-asset-historical-data` 的 wheel（`--no-deps`，因依赖 click/rich 已在主包核心）
- [ ] `packaging/extras/assets/cli-apps/chart/`：拷贝 chart 脚本目录（纯 Python 脚本）
- [ ] `packaging/extras/assets/skills/`：6 个 skill 目录（`alert-analysis`、`dynamic-monitor`、`doc-page`、`cli-app-dct-north-cli`、`cli-app-chart`、`cli-app-cli-anything-asset-historical-data`），内容取自 workspace 实况（**非**仓库旧版）
- [ ] `packaging/extras/assets/mcp/fastgpt-knowledge/`：拷贝 MCP 目录（含 `server.py` + `config.json` 凭据）
- [ ] `packaging/extras/assets/SOURCES.md`：记录每项资产的来源路径/版本/sha256（wheel 与整体）
- [ ] 校验：`grep -r "\\.so$"` 无二进制 → 确认跨平台单包成立