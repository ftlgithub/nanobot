---
labels: [ready-for-agent]
---

# Spec: nanobot 离线安装包（tarball 自包含）

## Problem Statement

内部服务器（Linux x64 内网机）与部分 macOS 机器在**安装阶段无法联网**，无法用常规 `pip install` / `uv sync` 拉取依赖。现有安装路径（`install.sh`、PyPI wheel、GitHub release TUI 下载）全部假设安装时有网。需要一个解压即装、不联网的离线包，且装完的实例要保留 fork 特性（用户映射/CORS/导航/错误掩蔽）与网关+WebUI 能力。

## Solution

构建**平台相关的 tarball 自包含包**（macOS arm64 与 Linux x64 glibc 2.17+ 各一份）：包内自带独立 Python 解释器（新建的瘦生产环境，非 1.7G 开发环境）、按已验证环境冻结版本的 wheelhouse、预构建的 WebUI 前端、预置的 TUI 原生二进制、以及一键 `install.sh`。安装过程零网络；运行时 LLM 走云端或本地已部署模型（纯配置）。

## User Stories

1. As a 运维工程师, I want to 在无网 Linux x64 服务器上解压安装 nanobot, so that 内网环境能跑起网关服务。
2. As a 运维工程师, I want to 在无网 macOS arm64 上解压安装 nanobot, so that 苹果设备也能离线部署。
3. As a 运维工程师, I want to 安装过程不访问任何外部网络, so that 防火墙/代理缺失时也能装完。
4. As a 运维工程师, I want to 一条命令完成安装（`./install.sh`）, so that 不需要手动配 Python/依赖/入口。
5. As a 运维工程师, I want to 包内自带 Python 解释器, so that 目标机无需预装 conda/系统 Python。
6. As a 运维工程师, I want to 依赖版本与已验证环境一致, so that 离线装出的行为与线上验证过的行为相同。
7. As a 扩展用户, I want to 离线装出的网关支持 Chrome 扩展跨域直连, so that 现有扩展不改就能用。
8. As a 扩展用户, I want to 离线装出的实例保留用户会话映射, so that 按用户过滤会话继续工作。
9. As a 扩展用户, I want to 离线装出的实例保留导航事件与错误掩蔽, so that 扩展行为与线上一致。
10. As a 终端用户, I want to 离线时裸 `nanobot` 命令能进 TUI, so that 不因 GitHub 下载失败而不可用。
11. As a 终端用户, I want to `nanobot gateway` 在离线机上正常启动网关+WebUI, so that 浏览器工作台可用。
12. As a 模型配置员, I want to 安装后可将模型指向云端或本地已部署的 OpenAI 兼容端点, so that 运行时不断网也能对话（安装离线≠运行离线）。
13. As a fork maintainer, I want to 离线包打的是当前 fork main（含 fork 特性）, so that 离线实例与线上行为一致。
14. As a fork maintainer, I want to 打包过程可复现（同输入→同输出）, so that 问题可追溯、包可重打。
15. As a fork maintainer, I want to 在干净环境验证包（bootstrap→建会话→删会话→health 全链路）, so that 发版前确认包真实可用。

## Implementation Decisions

- **目标平台**：macOS arm64、Linux x64（glibc 2.17+，与上游 TUI 分发对齐）；两平台分别构建，不做通用包。
- **Python 底座**：包内自带独立解释器（standalone cpython 或等价），**新建瘦生产环境**（仅 `pyproject` dependencies，无 dev/test 依赖），不用现有 1.7G/467 包的 nanobot-312 开发环境。
- **版本来源**：当前 fork main；第三方依赖按已验证环境冻结精确版本。
- **包内容**：独立 Python + wheelhouse（双平台各自的 wheels）+ 预构建 WebUI 前端（打包机用 bun 构建）+ 预置 TUI 原生二进制（darwin-arm64、linux-x64 放 `nanobot/tui/bin/`，避免运行时去 GitHub 下载）+ `install.sh`。
- **渠道依赖**：仅 websocket（零额外依赖）；其他渠道以后有网再按名选装。
- **模型**：不打包任何模型权重；本地模型通过 OpenAI 兼容端点配置接入（文档说明）。
- **技术说明**：TUI 启动优先用包内 `nanobot/tui/bin/<asset>`，缺失才下载——预置即满足离线；WebUI 的 `nanobot/web/dist` 在打包机预构建后随包发布。
- **安装契约**：`install.sh` 幂等、可重跑；安装目录自包含、可整体搬迁；退出码 0 表示成功。

## Testing Decisions

- **测试 seam（单一最高层）**：干净环境中解压安装后的**网关 WS/REST 对外接口**——与既有端到端脚本模式一致：`bootstrap` 拿 token → 建会话 → 发消息 → mutation 删除 → `/health` 断言，外加 `install.sh` 退出码为 0。
- **冒烟盲区补救（导入横扫）**：主链路只覆盖主路径，懒加载/分支路径缺包测不出。验收加两步（仍是行为断言，不断言文件清单）：① 安装必须用 `pip install --no-index`，让 pip 对声明依赖做完整性校验；② 装完后 `import` 全部顶层模块并 `discover` 全部 channel/tool 入口（websocket 范围内很小），暴露懒加载缺包。
- **什么是好的测试**：只断言外部可观察行为（端口监听、HTTP 状态、WS 事件、响应体），不测 wheelhouse 内部文件清单等实现细节。
- **将要测试的模块**：安装脚本（冒烟）、网关启动、bootstrap/CORS、会话 CRUD、mutation 删除、health 语义。
- **测试的 prior art**：`.scratch/sync-upstream-v0.3.5/spec.md` 确立的端到端脚本模式（bootstrap→WS→mutation→断言）；`tests/fork/` 纯函数测试风格不适用本包（包测试是黑盒）。
- **回归基线**：干净环境全链路一次通过；任一步失败即包不合格。

## Out of Scope

- 不打包任何 LLM 模型权重（运行时模型走云端或外部署端点）。
- 不支持 macOS x64、Windows、Linux arm64（超出本次两平台范围）。
- 不预装 websocket 之外的渠道依赖。
- 不做增量升级/热更新机制（首次交付只做全新安装；升级策略另议）。
- 不改变 fork 代码本身（打包只消费当前 main，不改业务逻辑）。
- 不处理目标机已有 Python/conda 冲突（包自带解释器，隔离安装）。
- 不预装第三方 CLI App（如 dct-north-cli、pm2）：其 `entry_point` 为机器绝对路径，需"发行包＋路径重写＋种子 installed.json"独立方案；待服务端用例确认后另起需求。

## Further Notes

- 打包机就是本机（有 bun/node，可构建 WebUI；可联网拉取 wheels 与 TUI 二进制）。
- Linux x64 的 wheels 必须在 manylinux 兼容前提下选型；glibc 2.17 是下限。
- 若后续出现 v0.3.5.x hotfix，先同步代码再重打包（版本冻结点随代码走）。
- 包体积主要由独立 Python + wheels + TUI 二进制决定；瘦环境是控制体积的关键（不用 1.7G 开发环境）。
- 本 spec 只定"装什么、怎么验"，具体构建脚本实现另起 ticket。