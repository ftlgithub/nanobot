# 本地修改清单（origin/main..HEAD）

基于 commit: `f0680687`, `bfc1a695`, `4d9b91f4`

---

## 1. CORS 支持 — Chrome 扩展直连 bootstrap 端点

### 1a. `nanobot/webui/http_utils.py`

**修改**: 3 个函数 + 1 个常量

| 函数 | 变更 |
|------|------|
| `http_json_response()` | 新增 `cors_origin: str \| None = None` 参数；headers 构建由固定 `Headers([...])` 改为 `header_list` 列表 + 条件注入 `Access-Control-Allow-Origin` |
| `http_response()` | 同上，新增 `cors_origin` 参数；局部变量 `headers` 重命名为 `header_list` |
| `http_error()` | 新增 `*, cors_origin: str \| None = None` 参数，透传给 `http_response()` |
| — | 文件末尾新增 `CORS_ALLOW_ALL = "*"` 常量 |

### 1b. `nanobot/webui/ws_http.py`

**修改**: import + 4 处返回路径

| 位置 | 变更 |
|------|------|
| import | 新增 `CORS_ALLOW_ALL as _cors_all` |
| 401 返回 | `_http_error(401, "Unauthorized")` → `_http_error(401, "Unauthorized", cors_origin=_cors_all)` |
| 403 返回 | `_http_error(403, "bootstrap is localhost-only")` → `_http_error(403, "bootstrap is localhost-only", cors_origin=_cors_all)` |
| 429 返回 | `_http_response(...)` 增加 `cors_origin=_cors_all` |
| 200 返回 | `_http_json_response({...})` → `_http_json_response({...}, cors_origin=_cors_all)` |

**功能**: Chrome 扩展等浏览器环境可直接 fetch `http://localhost:8765/bootstrap` 获取 WebSocket token，不再被同源策略拦截。

---

## 2. Navigation 导航元数据通道

LLM 在回复中嵌入 `<!--NAV:{"key":"value",...}-->` 注释，系统自动解析为结构化元数据下发到 WebSocket 客户端，使 WebUI 可执行前端页面导航。

### 2a. `nanobot/agent/loop.py`

**新增 import**: `json`, `re`

**修改 1 — 流式响应阶段** (`_process_turn_result()`, 约 L924):

```python
# 原代码
await on_stream(result.final_content or "")
await on_stream_end(resuming=False)

# 新代码
_fc = result.final_content or ""
_nav_d = None
_nav_m = re.search(r'<!--NAV:(.*?)-->', _fc)        # 正则匹配 NAV 标记
if _nav_m:
    try:
        _nav_d = json.loads(_nav_m.group(1))         # 解析 JSON
        _fc = (_fc[:_nav_m.start()] + _fc[_nav_m.end():]).strip()  # 从正文剥离
    except json.JSONDecodeError:
        pass
await on_stream(_fc)                                 # 推流剥离后的正文
await on_stream_end(resuming=False)
if _nav_d:                                           # 有导航数据时
    await self.bus.publish_outbound(OutboundMessage(
        channel=msg.channel,
        chat_id=msg.chat_id,
        content="",
        metadata={"_navigation": _nav_d},             # 通过 bus 下发
    ))
```

**修改 2 — 最终响应构建** (`_build_outbound_message()`, 约 L1453):

```python
# 在 meta["latency_ms"] 赋值之后、return OutboundMessage 之前插入
nav_match = re.search(r'<!--NAV:(.*?)-->', final_content)
if nav_match:
    try:
        nav_data = json.loads(nav_match.group(1))
        meta["_navigation"] = nav_data
        final_content = (final_content[:nav_match.start()]
                         + final_content[nav_match.end():]).strip()
    except json.JSONDecodeError:
        pass
```

**功能**: LLM 在回复中嵌入 `<!--NAV:{"page":"..."}-->`，agent loop 自动识别、剥离、并通过消息总线以 metadata 形式下发。

---

### 2b. `nanobot/channels/base.py`

**新增方法** `send_navigation()` (位于 `send_typing()` 之后):

```python
async def send_navigation(self, chat_id: str, nav_data: dict[str, Any]) -> None:
    """Send a navigation command to the client.

    The default implementation is a no-op; WebSocket-based channels
    override this to dispatch a navigation event.
    """
```

**功能**: 在 `BaseChannel` 定义导航下发接口，默认空操作，各 channel 按需覆写。

---

### 2c. `nanobot/channels/manager.py`

**修改** `_on_message()` 方法，处理 `StreamEndEvent` 和 `StreamedResponseEvent` 中的 `_navigation`：

```python
elif isinstance(event, StreamEndEvent):
    await ChannelManager._send_stream_event(channel, msg, event)
    # ↓ 新增
    if msg.metadata.get("_navigation"):
        nav = msg.metadata["_navigation"]
        await channel.send_navigation(
            msg.chat_id,
            nav if isinstance(nav, dict) else {},
        )

elif isinstance(event, StreamedResponseEvent) and msg.metadata.get("_navigation"):
    # ↑ 新增条件分支，拦截带 _navigation 的 StreamedResponseEvent
    nav = msg.metadata["_navigation"]
    await channel.send_navigation(
        msg.chat_id,
        nav if isinstance(nav, dict) else {},
    )
```

**功能**: `ChannelManager` 在消息路由阶段检测 `_navigation` 元数据，分发到对应 channel 的 `send_navigation()` 方法。

---

### 2d. `nanobot/channels/websocket.py`

**修改 1 — `send()` 方法** (约 L918):

在 `_agent_name` 特殊处理后、`text = msg.content` 前插入：

```python
if msg.metadata.get("_navigation"):
    nav_data = msg.metadata["_navigation"]
    if conns:
        nav_payload: dict[str, Any] = {
            "event": "navigation",
            "chat_id": msg.chat_id,
            **nav_data,
        }
        raw_nav = json.dumps(nav_payload, ensure_ascii=False)
        for connection in conns:
            await self._safe_send_to(connection, raw_nav, label=" navigation ")
    if not msg.content:      # 纯导航消息（无正文）提前 return
        return
```

**修改 2 — 新增 `send_navigation()` 方法** (约 L1070):

```python
async def send_navigation(self, chat_id: str, nav_data: dict[str, Any]) -> None:
    """Send a navigation command to WebSocket clients."""
    conns = list(self._subs.get(chat_id, ()))
    if not conns:
        return
    nav_payload: dict[str, Any] = {
        "event": "navigation",
        "chat_id": chat_id,
        **nav_data,
    }
    raw_nav = json.dumps(nav_payload, ensure_ascii=False)
    for connection in conns:
        await self._safe_send_to(connection, raw_nav, label=" navigation ")
```

**功能**: WebSocket channel 将导航指令以 `{"event": "navigation", "chat_id": "...", ...}` JSON 格式发送给所有连接的客户端，WebUI 据此执行前端路由跳转。

---

## 3. CLI App Manager 本地安装回退

### `nanobot/apps/cli/service.py`

**修改** `_find_app()` 方法 (约 L575):

在 `for app in self.catalog(...)` 循环之后、`raise CliAppError(...)` 之前插入：

```python
# Fall back to locally-installed apps not in any remote catalog
installed = self._load_installed()
raw = installed.get(wanted)
if raw is not None:
    entry = raw if isinstance(raw, dict) else {}
    return {
        "name": str(wanted),
        "display_name": str(entry.get("display_name") or wanted),
        "description": str(entry.get("description") or ""),
        "category": str(entry.get("category") or "installed"),
        "entry_point": str(entry.get("entry_point") or ""),
        "_source": str(entry.get("source") or "local"),
        "version": str(entry.get("version") or "0.1.0"),
    }
```

**功能**: 当用户在远程 catalog 中找不到指定 CLI App 时，回退到本地已安装的 app 列表。支持运行本地安装但未在任何远程 catalog 注册的 App。

---

## 4. Code Analyzer Skill

### `nanobot/skills/code-analyzer/SKILL.md`（新文件, 183 行）

**内容结构**:
- YAML front matter（`name: code-analyzer`, 含 `nanobot` metadata）
- When to Use This Skill — 触发条件说明
- Workflow — 读取→分析→生成文档 三步骤
- Documentation Template — Markdown 文档模板
- Common Python Patterns to Explain — 常用语法模式速查表（类型注解、dataclass、异步等）
- Output Location — 输出到 `docs/` 目录
- Important Notes — 注意事项

**功能**: Agent 可用此 skill 对 Python 源码做语法教学级分析，生成结构化的中文文档。

---

## 文件变更统计

| 文件 | 变更类型 | 新增行 | 修改行 | 删除行 |
|------|----------|--------|--------|--------|
| `nanobot/webui/http_utils.py` | 修改 | 14 | 12 | 10 |
| `nanobot/webui/ws_http.py` | 修改 | 5 | 4 | 3 |
| `nanobot/agent/loop.py` | 修改 | 26 | 1 | 1 |
| `nanobot/channels/base.py` | 修改 | 7 | 0 | 0 |
| `nanobot/channels/manager.py` | 修改 | 14 | 0 | 0 |
| `nanobot/channels/websocket.py` | 修改 | 30 | 0 | 0 |
| `nanobot/apps/cli/service.py` | 修改 | 14 | 0 | 0 |
| `nanobot/skills/code-analyzer/SKILL.md` | **新建** | 183 | 0 | 0 |
| **源码合计** | | **293** | **17** | **14** |

*生成日期: 2026-07-03*
