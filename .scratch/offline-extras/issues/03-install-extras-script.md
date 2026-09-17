# 03 — 安装器：`installer.py`（逻辑）+ `install-extras.sh`（薄包装）

**What to build:** 离线目标机上一条命令把 CLI/Skill/MCP 装到位。安装逻辑放在 Python 安装器里（纯 stdlib，可单测），`.sh` 只做"定位自带 Python → 调用安装器"的薄引导。安装器负责：定位并校验主包 prefix 与 workspace、离线装 wheel、软链 CLI 入口、种子化 `installed.json`、投放 skill、merge MCP 配置。幂等可重跑。

**Blocked by:** 02 — extras 资产 staging + 预编内部 wheel

**Status:** ready-for-agent

**载体划分**
- [ ] `installer.py`（纯 stdlib，任意 Python 3 可跑）：承载全部安装逻辑
- [ ] `install-extras.sh`（~10 行）：定位目标主包的自带 Python → 以它调用 `installer.py`，透传参数与退出码（"找 Python"必须留在 shell）
- [ ] 手动路径保留：`.sh` 与直接 `python installer.py` 均可独立执行

**接口与校验**
- [ ] 接口：`install-extras.sh [<nanobot-prefix>] [<workspace>]`（等价 `--prefix/--workspace`）；传参优先，缺省自动探测（PATH 反推 prefix / config 读 workspace）
- [ ] prefix 下无 `python/bin` 等不合理情形时**报错退出**（不静默装错 Python）

**安装步骤**
- [ ] `pip install --no-index --no-deps` 两个 wheel 进 `<prefix>/python`
- [ ] 拷 `chart` 目录到数据目录 `<data>/cli-apps/chart/`
- [ ] 软链 3 个 CLI 入口到 `<prefix>/bin/`（该目录已在 PATH，满足 `run()` 的 `shutil.which`）
- [ ] 种子化 `<data>/cli-apps/installed.json`（3 个 App；`entry_point`/`entry_point_path` 指向新位置；**不调 install()**，避免删除 skill）
- [ ] 拷 6 个 skill 到 `<workspace>/skills/`
- [ ] 拷 MCP 目录到 `<data>/mcp/fastgpt-knowledge/`，merge `<data>/config.json` 的 `tools.mcpServers.fastgpt-knowledge`（`command` 改写为 `<prefix>/python/bin/python`，**先备份**，不改无关字段）
- [ ] 结束打印摘要与提示（PATH、MCP 需重载或重启网关）

**质量**
- [ ] 幂等：重复执行结果一致、无累积脏状态
- [ ] 单测（临时目录）：config merge 保留无关字段、探测拒绝逻辑、`installed.json` 无开发机绝对路径、重跑幂等
