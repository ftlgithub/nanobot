# 05 — 断网端到端验证

**What to build:** 在断网环境证明 extras 真实可用：主包 + extras 装完后，CLI 能调起、skill 可见且名字正确无重复、MCP 能启动列 tools、路径已改写，且主包原有功能未回归。

**Blocked by:** 04 — `build-extras.sh` + 发版记录

**Status:** ready-for-agent

- [ ] Linux：docker 容器（`--platform linux/amd64 --network none`）装主包 + extras，脚本退出码 0
- [ ] macOS：干净 HOME 装主包 + extras，脚本退出码 0
- [ ] 幂等：同一环境再跑一次 extras，结果一致、无重复条目
- [ ] `run_cli_app` 三个 App（`dct-north-cli`/`chart`/`cli-anything-asset-historical-data`）均可调起并返回结果
- [ ] `SkillsLoader.list_skills()` 含 6 个预期名；`cli-app-dct-north-cli` 存在且**无重复**（无 `dct-north-cli` 残留、无 `cli-app-dct-north-cli` 双份）
- [ ] MCP `fastgpt-knowledge` 能启动并列出 tools（**不验**内网 API 连通性）
- [ ] 路径校验：`installed.json` 无开发机绝对路径；MCP `command` 指向自带 Python
- [ ] 主包冒烟回归：bootstrap → 建会话 → 删会话 → health 全过
- [ ] 记录验证证据到 `RELEASES*.md`（或 extras 章节）