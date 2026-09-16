# packaging/ — nanobot 离线安装包构建区

给无网机器用的自包含 tarball 在这里组装。构建机需联网，产物安装零网络。

## 目录结构

| 路径 | 说明 | 进 git？ |
|---|---|---|
| `build.sh` | 一键双平台构建脚本（`./packaging/build.sh [macos\|linux\|all]`） | ✅ |
| `install.sh` | 装机脚本模板，随 tarball 发布 | ✅ |
| `locks/` | 双平台依赖锁（`requirements-*.txt`）＋说明 | ✅ |
| `tui-binaries/README.md` | TUI 二进制来源＋sha256（manifest） | ✅ |
| `RELEASES.md` / `RELEASES.zh-CN.md` | 发版记录（包名/sha/验证/限制，中英） | ✅ |
| `INSTALL.zh-CN.md` | 用户侧安装使用文档（随 tarball 发布） | ✅ |
| `build/` | 构建输出（tarball、wheelhouse、解包目录） | ❌（173MB＋，git-ignored） |
| `nanobot/tui/bin/`（仓库根下，非本目录） | TUI 二进制落盘处 | ❌（仅 `.gitkeep` 入库） |

## 构建流程

```
1. 前置校验：WebUI dist 新鲜、TUI zips 就位
2. 独立 Python（mac: uv 管理版；linux: python-build-standalone）
3. wheelhouse：按 locks/ 用 --platform 限定下载（Linux 限 manylinux2014）
4. 主包 wheel + TUI 解压 + install.sh + requirements.txt + 安装说明
5. tar + sha256 → packaging/build/<平台>/
```

详见各阶段文档：`locks/README.md`（依赖策略）、`tui-binaries/README.md`
（二进制来源）、`RELEASES.md`（发版清单）。

## 验证

构建产物必须过：干净环境安装（`install.sh` 退出码 0）＋全链路冒烟
（bootstrap → 建会话 → 发消息 → mutation 删除 → health）＋导入横扫。
macOS 用干净 HOME，Linux 用 docker 断网容器。历史验证记录见
`RELEASES.md`／`.scratch/offline-installer/issues/05-*`。
