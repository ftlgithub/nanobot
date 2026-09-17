# 01 — skill 改名对齐：`dct-north-cli` → `cli-app-dct-north-cli`

**What to build:** 开发机上该 CLI skill 的名称与产品约定（`_skill_name()` 产出的 `cli-app-*`）对齐，从而与已有的 `cli-app-chart`、`cli-app-cli-anything-asset-historical-data` 一致；extras 打包将以此新名为准。

**Blocked by:** None — can start immediately

**Status:** ready-for-agent

- [ ] 目录改名：`<workspace>/skills/dct-north-cli/` → `<workspace>/skills/cli-app-dct-north-cli/`
- [ ] 同步改 SKILL.md 的 `name:` 字段为 `cli-app-dct-north-cli`
- [ ] `SkillsLoader(workspace).list_skills()` 显示 `cli-app-dct-north-cli`，且**无重复条目**、无残留 `dct-north-cli`
- [ ] 确认无引用断裂：全库无 `$dct-north-cli` 形式引用；`run_cli_app(name="dct-north-cli")` 仍正常（app 名不变，仅 skill 名变）
- [ ] 注意：gitlab 仓库 `cloud-ops/dct-north-cli` **不改**（仓库未打包/暴露 SKILL.md 给 nanobot，改名对其无影响）