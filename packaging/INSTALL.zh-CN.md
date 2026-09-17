# nanobot 离线安装包 — 安装使用文档

适用版本：v0.3.5（fork main，含用户映射/CORS/导航/错误掩蔽特性）
适用平台：macOS arm64、Linux x64（glibc 2.17+）

---

## 1. 安装前确认

| 检查项 | 要求 |
|---|---|
| 操作系统 | macOS arm64，或 glibc ≥ 2.17 的 Linux x64（`ldd --version` 查看） |
| 磁盘空间 | ≥ 1 GB（macOS 包约 91MB，Linux 包约 203MB，解压后更大） |
| 网络 | **安装全程无需网络**（这正是离线包的意义） |
| Python | **无需预装**（包内自带独立 Python 3.12） |
| 模型 | 安装时不需要；运行时需要云端 LLM 或本地已部署的 OpenAI 兼容端点 |

选对平台包：`nanobot-offline-macos-arm64-v0.3.5.tar.gz` 或
`nanobot-offline-linux-x64-v0.3.5.tar.gz`，用随附 SHA256SUMS 校验：

```bash
shasum -a 256 -c SHA256SUMS   # macOS
sha256sum -c SHA256SUMS       # Linux
```

## 2. 安装步骤

```bash
# 1. 解压（任意目录，以 /opt 为例）
tar -xzf nanobot-offline-<平台>-v0.3.5.tar.gz -C /opt/

# 2. 一键安装（默认装到 $HOME/nanobot-offline；可传参指定目录）
bash /opt/nanobot-offline/install.sh ~/nanobot-offline

# 3. 加入 PATH（建议写入 ~/.zshrc 或 ~/.bashrc）
export PATH="$HOME/nanobot-offline/bin:$PATH"

# 4. 验证
nanobot --version   # 应输出 🐈 nanobot v0.3.5
```

安装过程说明：脚本把自带 Python 拷到目标目录，用包内 wheelhouse
离线装完 89 个锁定依赖，再装入 TUI 二进制，最后自检（版本号＋核心
模块导入）。全程不访问网络；任一步失败则报错退出，不会留半截环境
（可删目录重装）。

## 3. 首次配置

### 3.1 配置文件

首次启动网关会自动引导，也可手写最小配置 `~/.nanobot/config.json`：

```json
{
  "gateway": {"host": "127.0.0.1", "port": 18790},
  "channels": {"websocket": {"enabled": true, "host": "127.0.0.1", "port": 8765}}
}
```

### 3.2 配置模型（二选一）

**方式 A：云端 LLM**——在 `nanobot webui` 的 Settings → Models 里填
provider 与 key，或直接写配置文件。

**方式 B：本地已部署模型**——把模型的 OpenAI 兼容地址（如
`http://内网IP:端口/v1`）配成 OpenAI 兼容 provider 即可，网关本身不需
要模型权重（离线包不含任何模型）。

### 3.3 Chrome 扩展对接（可选）

扩展连网关的 WebSocket 地址（如 `ws://127.0.0.1:8765`），跨域已默认
放行（`Access-Control-Allow-Origin: *`）。扩展侧无需改动。

## 4. 启动与日常使用

```bash
# 前台启动网关（首次建议前台，观察日志）
nanobot gateway --foreground --port 18790 \
  --workspace ~/.nanobot/workspace \
  --config ~/.nanobot/config.json

# 健康检查（WebSocket 频道运行中返回 200；未运行返回 503，属 v0.3.5 新语义）
curl http://127.0.0.1:18790/health

# 后台常驻（二选一）
nanobot gateway --background
# 或终端里 /detach（TUI 内）
```

常用命令：

| 命令 | 用途 |
|---|---|
| `nanobot` | 原生终端 TUI（离线可用，二进制已预置） |
| `nanobot --classic` | 旧式 Python 交互提示 |
| `nanobot -m "你好"` | 单次问答（连通性速测） |
| `nanobot gateway` | 启动网关 |
| `nanobot webui` | 启动网关＋打开浏览器工作台 |

## 5. 验证安装是否成功

```bash
# 1. 版本与模块
nanobot --version
# 2. 会话接口（需先拿到 token：打开 WebUI 或调 /webui/bootstrap）
curl http://127.0.0.1:8765/webui/bootstrap
# 3. 健康
curl http://127.0.0.1:18790/health
```

完整行为验证（建会话→发消息→删会话→health）见发版记录
`packaging/RELEASES.zh-CN.md`。

## 6. 常见问题

| 现象 | 原因与处理 |
|---|---|
| `nanobot` 进不去 TUI | TUI 二进制按平台预置；确认下的是对应平台的包 |
| `/health` 返回 503 | WebSocket 频道未运行（v0.3.5 新语义），检查网关日志确认频道状态 |
| 旧会话找不到 | v0.3.5 起会话存于 `sessions/<workspace-id>/`，首次升级自动迁移；不要让新旧版本同时写同一 workspace |
| `dct-north-cli` 等 CLI App 调不到 | 离线包**不含**第三方 CLI App（其入口是机器绝对路径，随包无意义）；有需要另行部署 App 并登记 |
| `pip install` 报 externally-managed | 不要动包内 Python；所有依赖已装好，无需再装 |
| 磁盘不足 | 解压后 Linux 约 600MB＋、macOS 约 300MB＋，确保目标目录空间 |

## 7. 卸载与重装

```bash
# 停网关后直接删目录即可（自包含，无系统残留）
rm -rf ~/nanobot-offline
# 用户数据（会话/配置）在 ~/.nanobot，删目录不影响；要清数据另删 ~/.nanobot
```

## 8. 已知限制

- 仅 macOS arm64、Linux x64（glibc 2.17+）；无 Windows、无 Linux arm64 构建。
- 未预装 websocket 之外的渠道依赖；第三方 CLI App 需另行部署。
- Linux 侧 3 个编译包降级适配 manylinux2014（pillow 12.2.0、rapidfuzz 3.13.0、tiktoken 0.11.0），行为已验证兼容。

## 9. 全新安装（含 extras，独立于现有环境）

适用于：目标机已有 nanobot 在跑，但要另起一套完全隔离的实例（不同目录、不同端口、不同数据）。

### 9.1 规划

| 项 | 说明 | 示例 |
|---|---|---|
| 程序目录 | 主包安装位置 | `~/nanobot-offline` |
| 数据目录 | 配置/workspace/会话/MCP，全新 | `~/nanobot-fresh`（内含 `config.json`、`workspace/`） |
| 网关端口 | 避开现运行实例 | `18831`（现实例用 18790） |
| WS 端口 | 避开现运行实例 | `18832`（现实例用 8765） |

**铁律**：两个网关实例**禁止**共享 workspace（会话 JSONL + sqlite 并发写会坏），也**禁止**复用同一对端口。

### 9.2 安装主包

```bash
tar -xzf nanobot-offline-<平台>-v0.3.5.tar.gz
bash nanobot-offline/install.sh ~/nanobot-offline
export PATH="$HOME/nanobot-offline/bin:$PATH"
```

### 9.3 写全新配置

```bash
mkdir -p ~/nanobot-fresh/workspace
cat > ~/nanobot-fresh/config.json << 'EOF'
{
  "gateway": {"host": "127.0.0.1", "port": 18831},
  "channels": {"websocket": {"enabled": true, "host": "127.0.0.1", "port": 18832}}
}
EOF
```

provider/模型按 §3.2 另行配置（云端 key 或本地 OpenAI 兼容端点）。

### 9.4 安装 extras

```bash
tar -xzf nanobot-extras-v0.3.5.tar.gz
bash nanobot-extras-v0.3.5/install-extras.sh ~/nanobot-offline ~/nanobot-fresh/workspace
```

说明：
- 第二个参数是 workspace（skill 装到 `<workspace>/skills/`）；不传则自动探测，可能指到错误的 workspace，**多实例场景建议显式传参**
- 脚本幂等，可重跑；改写 `config.json` 前自动备份（`config.json.bak-<时间戳>`）
- `.sh` 只是薄包装，实际逻辑在包内 `installer.py`（`--dry-run` 可先演练）
- CLI 入口软链到 `<prefix>/bin`，该目录必须在 PATH 上，否则 `run_cli_app` 报 "not available on PATH"
- skill 按 workspace 存放：换 `--workspace` 启动的实例看不到，需对新 workspace 重跑一次

### 9.5 启动与验证

```bash
nanobot gateway --foreground --port 18831 \
  --workspace ~/nanobot-fresh/workspace \
  --config ~/nanobot-fresh/config.json
```

验证清单（全部通过才算成功）：
1. `curl http://127.0.0.1:18832/webui/bootstrap` → 200
2. WebSocket 建会话 → 发消息 → `session.delete` → `{"deleted":true}`
3. `curl http://127.0.0.1:18831/health` → `ok`
4. `run_cli_app` 调起三个 CLI（`dct-north-cli`、`cli-anything-asset-historical-data`、`chart`）
5. `list_skills` 含 6 个预期 skill，无重复
6. 网关日志出现 `MCP server 'fastgpt-knowledge': connected`（**MCP 需重启网关或 reload 才生效**，装完不重启看不到）

### 9.6 停止与清理

```bash
# 停网关（找到对应 --port 的进程后 kill，或用 gateway stop）
# 删程序与数据即完全卸载（自包含，无系统残留）
rm -rf ~/nanobot-offline ~/nanobot-fresh
```
