#!/usr/bin/env bash
# =============================================================================
# nanobotctl — nanobot 快捷管理脚本
# 自动激活 conda nanobot-312 环境，管理 Gateway 生命周期
# =============================================================================
set -euo pipefail

APP_NAME="nanobot"
CONDA_ENV="nanobot-312"
CONDA_BIN="/opt/anaconda3/bin/conda"
NANOBOT_DIR="$HOME/Documents/workspace/ai-model/nanobot"
CONFIG_FILE="$HOME/.nanobot/config.json"
WORKSPACE_DIR="$HOME/.nanobot/workspace"
GATEWAY_PORT="${NANOBOT_PORT:-18790}"
# 所有 gateway 子命令的公共参数（保证 state/log 文件名一致）
GATEWAY_ARGS=(--config "$CONFIG_FILE" --workspace "$WORKSPACE_DIR")
GATEWAY_URL="http://127.0.0.1:${GATEWAY_PORT}"

# ── 颜色 ──────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── 工具函数 ──────────────────────────────────────────────────────────────────

info()  { echo -e "${CYAN}${BOLD}ℹ${NC} $*"; }
ok()    { echo -e "${GREEN}${BOLD}✔${NC} $*"; }
warn()  { echo -e "${YELLOW}${BOLD}⚠${NC} $*"; }
err()   { echo -e "${RED}${BOLD}✘${NC} $*" >&2; }
header(){ echo -e "\n${BOLD}━━━ $* ━━━${NC}"; }

# 在 conda 环境中执行一条命令
conda_run() {
    "$CONDA_BIN" run --no-capture-output -n "$CONDA_ENV" "$@"
}

# gateway 子命令包装（自动带入 --config / --workspace，保证 state/log 文件名一致）
gateway_cmd() {
    conda_run nanobot gateway "$@" "${GATEWAY_ARGS[@]}"
}

# 检查 conda 环境是否可用
check_conda() {
    if ! "$CONDA_BIN" info --envs 2>/dev/null | grep -q "^${CONDA_ENV}\b"; then
        err "Conda 环境 '${CONDA_ENV}' 不存在"
        info "可用环境:"
        "$CONDA_BIN" info --envs 2>/dev/null | grep -v "^#" | grep -v "^$" || true
        exit 1
    fi
}

# 检查 nanobot CLI 是否可用
check_nanobot() {
    if ! conda_run which nanobot &>/dev/null; then
        err "在 conda '${CONDA_ENV}' 中找不到 'nanobot' 命令"
        info "尝试重新安装: cd ${NANOBOT_DIR} && pip install -e ."
        exit 1
    fi
}

# ── 子命令 ────────────────────────────────────────────────────────────────────

cmd_start() {
    header "启动 ${APP_NAME} Gateway"

    # 检查是否真正在运行（status exit code 不可靠，需要解析输出）
    local status_output
    status_output=$(gateway_cmd status 2>/dev/null)
    if echo "$status_output" | grep -q "Running: yes"; then
        warn "Gateway 已在运行中"
        echo "$status_output"
        echo ""
        info "如需重启请执行: ${0##*/} restart"
        exit 0
    fi

    info "激活 conda 环境: ${CONDA_ENV}"
    info "配置文件: ${CONFIG_FILE}"
    info "启动 Gateway (端口 ${GATEWAY_PORT})..."

    # nanobot gateway --background 会自动处理 daemon 化
    # 但 conda 的环境变量需要先激活
    # 我们通过 conda_run 来保证环境正确
    conda_run nanobot gateway --background \
        --config "$CONFIG_FILE" \
        --port "$GATEWAY_PORT" \
        --workspace "$HOME/.nanobot/workspace"

    # 等待进程启动
    sleep 2

    if gateway_cmd status &>/dev/null; then
        ok "Gateway 启动成功"
        cmd_urls
    else
        err "Gateway 启动失败，请查看日志检查原因"
        info "日志: ${0##*/} logs"
        exit 1
    fi
}

cmd_stop() {
    header "停止 ${APP_NAME} Gateway"
    if gateway_cmd stop; then
        ok "Gateway 已停止"
    else
        warn "Gateway 未在运行"
    fi
}

cmd_restart() {
    header "重启 ${APP_NAME} Gateway"
    # 使用 gateway 自带的 restart 先尝试
    if gateway_cmd restart 2>/dev/null; then
        ok "Gateway 重启成功"
        cmd_urls
        return
    fi

    # 如果 gateway restart 不可用，手动 stop + start
    warn "Gateway 未在运行，准备启动..."
    cmd_start
}

cmd_logs() {
    local follow=""
    local tail_lines=50
    local log_dir="$HOME/.nanobot/logs"

    # 解析参数
    for arg in "$@"; do
        case "$arg" in
            -f|--follow|follow) follow="-f" ;;
            -n|--tail) ;; # 由下一个参数处理
            *) tail_lines="$arg" ;;
        esac
    done

    # 直接读取日志文件，不依赖 nanobot gateway logs（默认 --follow 阻塞）
    if [[ ! -d "$log_dir" ]]; then
        err "日志目录不存在: ${log_dir}"
        exit 1
    fi

    local latest
    latest=$(ls -1t "$log_dir"/*.log 2>/dev/null | head -1)
    if [[ -z "$latest" ]]; then
        warn "未找到日志文件"
        return
    fi

    header "${APP_NAME} Gateway 日志"
    info "日志: ${latest}"
    echo ""

    if [[ "$follow" == "-f" ]]; then
        tail -f "$latest"
    else
        tail -n "$tail_lines" "$latest"
    fi
}

cmd_status() {
    header "${APP_NAME} 状态概览"

    # Gateway 状态
    echo -e "${BOLD}● Gateway${NC}"
    if gateway_cmd status &>/dev/null; then
        ok "Gateway 正在运行 (端口 ${GATEWAY_PORT})"
        gateway_cmd status
    else
        warn "Gateway 未运行"
    fi
    echo ""

    # Conda 环境
    echo -e "${BOLD}● Conda 环境${NC}"
    ok "环境: ${CONDA_ENV}"
    local python_version
    python_version=$(conda_run python --version 2>/dev/null || echo "N/A")
    info "  ${python_version}"
    local nanobot_version
    nanobot_version=$(conda_run nanobot --version 2>/dev/null | head -1 || echo "")
    [[ -n "$nanobot_version" ]] && info "  nanobot ${nanobot_version}"
    echo ""

    # 网络地址
    cmd_urls

    # 磁盘/内存 (简单)
    echo -e "${BOLD}● 系统资源${NC}"
    if command -v ps &>/dev/null; then
        local pid
        pid=$(gateway_cmd status 2>/dev/null | grep -Eo 'PID: [0-9]+' | awk '{print $2}' || true)
        if [[ -n "$pid" ]]; then
            info "Gateway PID: ${pid}"
            if command -v ps &>/dev/null; then
                ps -p "$pid" -o pid,%cpu,%mem,rss,command --no-headers 2>/dev/null || true
            fi
        fi
    fi
    echo ""
}

cmd_urls() {
    echo -e "${BOLD}● 访问地址${NC}"
    echo -e "  ${CYAN}WebUI:${NC}      http://localhost:${GATEWAY_PORT}"
    echo -e "  ${CYAN}API:${NC}        http://localhost:${GATEWAY_PORT}/v1/chat/completions"
    echo -e "  ${CYAN}API Keys:${NC}   http://localhost:${GATEWAY_PORT}/api-keys"
    echo -e "  ${CYAN}健康检查:${NC}   http://localhost:${GATEWAY_PORT}/health"
}

cmd_health() {
    header "健康检查"
    if command -v curl &>/dev/null; then
        if curl -sf "${GATEWAY_URL}/health" &>/dev/null; then
            ok "Gateway 响应正常 (${GATEWAY_URL})"
            curl -s "${GATEWAY_URL}/health" | python3 -m json.tool 2>/dev/null || curl -s "${GATEWAY_URL}/health"
        else
            err "Gateway 无响应 (${GATEWAY_URL})"
            info "请先启动: ${0##*/} start"
        fi
    else
        warn "未安装 curl，无法执行健康检查"
    fi
}

cmd_update() {
    header "更新 ${APP_NAME} 代码"

    if [[ ! -d "$NANOBOT_DIR" ]]; then
        err "仓库目录不存在: ${NANOBOT_DIR}"
        exit 1
    fi

    # 保存当前 git 状态
    pushd "$NANOBOT_DIR" >/dev/null
    local stash_needed=false
    if ! git diff --quiet || ! git diff --cached --quiet; then
        stash_needed=true
        warn "有未提交的修改，暂存中..."
        git stash push -m "nanobotctl auto-stash before update"
    fi

    info "拉取最新代码..."
    if ! git pull --rebase origin main; then
        err "Git pull 失败，请手动处理冲突"
        info "目录: ${NANOBOT_DIR}"
        popd >/dev/null
        exit 1
    fi

    if $stash_needed; then
        info "恢复暂存的修改..."
        git stash pop 2>/dev/null || warn "暂存恢复失败（可能冲突），请手动处理"
    fi
    popd >/dev/null

    # 重新安装包
    header "重新安装 ${APP_NAME} 包"
    info "执行: pip install -e ${NANOBOT_DIR}"
    conda_run pip install -e "$NANOBOT_DIR" -q
    ok "更新完成"

    # 如果有在运行则提示重启
    if gateway_cmd status &>/dev/null; then
        info "Gateway 正在运行，建议重启: ${0##*/} restart"
    fi
}

cmd_doctor() {
    header "环境诊断"

    echo -e "${BOLD}● Conda${NC}"
    if [[ -x "$CONDA_BIN" ]]; then
        ok "conda: ${CONDA_BIN}"
        info "版本: $("$CONDA_BIN" --version 2>/dev/null || echo "N/A")"
        if "$CONDA_BIN" info --envs 2>/dev/null | grep -q "^${CONDA_ENV}\b"; then
            ok "环境 '${CONDA_ENV}' 存在"
        else
            err "环境 '${CONDA_ENV}' 不存在"
        fi
    else
        err "conda 未找到 (预期路径: ${CONDA_BIN})"
    fi
    echo ""

    echo -e "${BOLD}● nanobot 包${NC}"
    if conda_run python -c "import nanobot; print(nanobot.__file__)" &>/dev/null; then
        ok "nanobot 可导入"
        info "路径: $(conda_run python -c "import nanobot; print(nanobot.__file__)")"
        info "版本: $(conda_run python -c "import nanobot; print(getattr(nanobot, '__version__', 'N/A'))" 2>/dev/null)"
    else
        err "nanobot 导入失败"
        info "请运行: cd ${NANOBOT_DIR} && pip install -e ."
    fi
    echo ""

    echo -e "${BOLD}● 配置${NC}"
    if [[ -f "$CONFIG_FILE" ]]; then
        ok "配置文件: ${CONFIG_FILE}"
    else
        err "配置文件不存在: ${CONFIG_FILE}"
    fi
    echo ""

    echo -e "${BOLD}● 仓库${NC}"
    if [[ -d "$NANOBOT_DIR/.git" ]]; then
        ok "仓库: ${NANOBOT_DIR}"
        info "分支: $(cd "$NANOBOT_DIR" && git branch --show-current 2>/dev/null)"
        info "最新提交: $(cd "$NANOBOT_DIR" && git log --oneline -1 2>/dev/null)"
        local ahead
        ahead=$(cd "$NANOBOT_DIR" && git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
        local behind
        behind=$(cd "$NANOBOT_DIR" && git rev-list --count origin/main..HEAD 2>/dev/null || echo 0)
        info "落后上游: ${ahead} 提交 | 领先上游: ${behind} 提交"
    else
        warn "仓库目录不存在或无 .git"
    fi
    echo ""

    echo -e "${BOLD}● Gateway${NC}"
    if gateway_cmd status &>/dev/null; then
        ok "Gateway 运行中"
        gateway_cmd status
    else
        warn "Gateway 未运行"
    fi
    echo ""

    echo -e "${BOLD}● 网络${NC}"
    if command -v curl &>/dev/null; then
        if curl -sf "${GATEWAY_URL}/health" &>/dev/null; then
            ok "Gateway HTTP 响应正常"
        else
            warn "Gateway HTTP 无响应（未运行或端口不对）"
        fi
    fi
    if command -v ss &>/dev/null; then
        if ss -tlnp 2>/dev/null | grep -q ":${GATEWAY_PORT} "; then
            ok "端口 ${GATEWAY_PORT} 监听中"
        fi
    elif command -v netstat &>/dev/null; then
        if netstat -an 2>/dev/null | grep -q "\.${GATEWAY_PORT} "; then
            ok "端口 ${GATEWAY_PORT} 监听中"
        fi
    fi
}

cmd_help() {
    echo -e "${BOLD}${APP_NAME}ctl — nanobot 快捷管理脚本${NC}"
    echo ""
    echo -e "用法: ${0##*/} ${CYAN}<command>${NC} [选项]"
    echo ""
    echo -e "${BOLD}核心命令${NC}"
    echo -e "  ${CYAN}start${NC}          启动 Gateway（后台守护进程）"
    echo -e "  ${CYAN}stop${NC}           停止 Gateway"
    echo -e "  ${CYAN}restart${NC}        重启 Gateway"
    echo -e "  ${CYAN}status${NC}         查看 Gateway 运行状态与概要"
    echo -e "  ${CYAN}logs${NC}          查看 Gateway 日志"
    echo -e "  ${CYAN}logs -f${NC}        跟踪日志输出"
    echo ""
    echo -e "${BOLD}运维命令${NC}"
    echo -e "  ${CYAN}update${NC}         拉取最新代码并重新安装 nanobot"
    echo -e "  ${CYAN}health${NC}         健康检查 — 探测 Gateway HTTP 是否正常"
    echo -e "  ${CYAN}doctor${NC}         环境诊断 — 检查 conda/nanobot/配置/仓库/网络"
    echo -e "  ${CYAN}urls${NC}           显示 WebUI 和 API 访问地址"
    echo ""
    echo -e "${BOLD}环境变量${NC}"
    echo -e "  ${YELLOW}NANOBOT_PORT${NC}  指定 Gateway 端口（默认 8765）"
    echo ""
    echo -e "${BOLD}示例${NC}"
    echo -e "  ${0##*/} start              # 启动"
    echo -e "  ${0##*/} stop               # 停止"
    echo -e "  ${0##*/} restart            # 重启"
    echo -e "  ${0##*/} status             # 状态"
    echo -e "  ${0##*/} logs -f            # 跟踪日志"
    echo -e "  ${0##*/} update             # 更新代码"
    echo -e "  ${0##*/} doctor             # 环境诊断"
    echo ""
}

# ── 主入口 ────────────────────────────────────────────────────────────────────

main() {
    if [[ $# -eq 0 ]]; then
        cmd_help
        exit 0
    fi

    local cmd="$1"
    shift 2>/dev/null || true

    case "$cmd" in
        start|stop|restart|status|update|health|doctor|urls)
            # 这些命令需要 conda 环境
            check_conda
            check_nanobot
            ;;
        logs)
            check_conda
            check_nanobot
            ;;
        help|--help|-h)
            cmd_help
            exit 0
            ;;
        *)
            err "未知命令: ${cmd}"
            echo ""
            cmd_help
            exit 1
            ;;
    esac

    case "$cmd" in
        start)   cmd_start ;;
        stop)    cmd_stop ;;
        restart) cmd_restart ;;
        status)  cmd_status ;;
        logs)    cmd_logs "$@" ;;
        update)  cmd_update ;;
        health)  cmd_health ;;
        doctor)  cmd_doctor ;;
        urls)    header "访问地址"; cmd_urls ;;
    esac
}

main "$@"
