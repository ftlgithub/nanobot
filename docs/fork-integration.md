# Fork Integration Guide

All fork-specific modifications that touch upstream files are marked with a
`# FORK-HOOK:` comment at the call site. The logic itself lives in
`nanobot/fork/` (the fork patch layer), which upstream never modifies. When a
rebase against upstream conflicts, search for these anchors to re-apply each
hook in the new upstream code.

## Fork patch layer

| Module | Provides |
|---|---|
| `nanobot/fork/navigation.py` | `parse_nav_marker(text)` — pure NAV marker parser |
| `nanobot/fork/llm_error.py` | `mask_llm_error(final_content)` — error text masking |
| `nanobot/fork/cors.py` | `CORS_ALLOW_ALL` constant, `cors_header(origin)` |
| `nanobot/fork/user_session.py` | re-export of the user↔session map singleton |
| `nanobot/fork/__init__.py` | public re-exports (`get_user_map`) |

## Hook inventory

Every hook id below must appear exactly once per call site in the codebase.

### NAV markers

| Hook id | File | Anchor | Purpose |
|---|---|---|---|
| `fork-nav-stream` | `nanobot/agent/loop.py` | `_nav_d, stream_content = parse_nav_marker(stream_content)` | Parse `<!--NAV:-->` from streamed final content before forwarding |
| `fork-nav-persist` | `nanobot/agent/loop.py` | `nav_data, final_content = parse_nav_marker(final_content)` | Parse NAV marker and inject `_navigation` into persisted message metadata |
| `fork-nav-send` | `nanobot/channels/manager.py` | `if msg.metadata.get("_navigation"): await channel.send_navigation(...)` (2 sites) | Dispatch navigation command on stream end / streamed response |
| `fork-nav-dispatch` | `nanobot/channels/websocket/runtime.py` | `if msg.metadata.get("_navigation"):` in `send_projected_message` | Emit `navigation` WS event before the text message |

### LLM error masking

| Hook id | File | Anchor | Purpose |
|---|---|---|---|
| `fork-err-mask` | `nanobot/agent/loop.py` | `result.final_content = mask_llm_error(result.final_content)` | Replace raw LLM error text with a user-friendly message |

### CORS

| Hook id | File | Anchor | Purpose |
|---|---|---|---|
| `fork-cors-constant` | `nanobot/webui/ws_http.py` | `from nanobot.fork.cors import CORS_ALLOW_ALL` | Source of the CORS allow-all origin |
| `fork-cors-bootstrap` | `nanobot/webui/ws_http.py` | `cors_origin=CORS_ALLOW_ALL` (4 sites in bootstrap flow) | Allow cross-origin access to the bootstrap endpoint for the Chrome extension |

### User session map

| Hook id | File | Anchor | Purpose |
|---|---|---|---|
| `fork-user-map-associate` | `nanobot/webui/inbound_commands.py` | `get_user_map().associate(user_id, webui_session_key(new_id))` | Bind a new WebSocket chat to its user on `new_chat` |
| `fork-user-map-filter` | `nanobot/webui/ws_http.py` | `get_user_map().filter_sessions(payload["sessions"], user_id)` | Filter session list by requesting user |
| `fork-user-map-dissociate` | `nanobot/webui/ws_http.py` | `get_user_map().dissociate(decoded_key)` | Drop the user binding when a persisted session is deleted |

### CLI app catalog (offline)

**Background — two data sources behind `get_app()`:**

| | 目录（catalog） | `installed.json` |
|---|---|---|
| 比喻 | 应用商店货架 | 本机已安装清单 |
| 位置 | 3 个远端 JSON（本地有 `*_registry_cache.json` 缓存副本） | 本机 `<data>/cli-apps/installed.json` |
| 内容 | 79 个**可装** App 描述（`name`/`display_name`/`category`/`entry_point`/`skill_md`/`version`…） | 本机**已装** App 记录（含安装路径、时间） |
| 注册表 | `harness` + `public`（必需，拉取失败即抛错）+ `extensions`（可选） | — |

`get_app()` 先逛商店（目录），找不到再看家里（`installed.json` 本地回退）。
内部 App（`dct-north-cli` 等）**只存在于家里、不在任何货架上**——
所以断网 + 无缓存时目录一崩，`get_app` 就到不了本地回退（下面这条 hook 修的正是这个）。

| Hook id | File | Anchor | Purpose |
|---|---|---|---|
| `fork-cli-apps-offline-catalog` | `nanobot/apps/cli/service.py` | `try: remote_apps = self.catalog(...) except Exception: remote_apps = []` in `get_app()` | Let a fully offline host (no registry cache, no network) resolve locally-installed CLI apps instead of raising before the local fallback |

## Rebase checklist

1. `git grep "FORK-HOOK:"` must return exactly the sites in this document.
2. For each hook id, find its new home in the rebased upstream function.
3. If upstream refactored the enclosing function (e.g. split, moved), move the
   hook call with it — the `nanobot/fork/` logic never changes.
4. If a hook id is missing after rebase, the upstream refactor deleted that
   code path; decide whether the fork behavior still applies.
5. `git rerere` replays previously resolved conflict hunks automatically.

## Behavior contract

These hooks must remain behavior-preserving across rebases:

- NAV marker: `<!--NAV:{json}-->` is stripped from content and dispatched as a
  `navigation` WS event; malformed markers leave text unchanged.
- Error masking: any `stop_reason == "error"` result shows the fixed message
  `模型服务暂时不可用，请稍后重试。` to users; raw error text is logged only.
- CORS: bootstrap endpoint responds with `Access-Control-Allow-Origin: *`.
- User map: `new_chat` binds `user_id`; session list filters by user; deleting
  a persisted session unbinds it.
- CLI app lookup: when the remote catalogs are unreachable (offline host with
  no cache), `get_app()` degrades to the locally-installed `installed.json`
  fallback instead of raising; a genuinely unknown name still raises 404.