#!/data/data/com.termux/files/usr/bin/bash
###############################################################################
# install.sh — Termux 宿主环境安装脚本（dialog UI 修复版）
###############################################################################

set -e
export TERM=dumb   # Termux 下 dialog 最稳

# ============ 颜色 ============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============ 工具 ============
log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "${CYAN}[STEP]${NC} $*"; }

check_termux() {
    if [ -z "$PREFIX" ] || [ ! -d "/data/data/com.termux/files/usr" ]; then
        log_error "仅支持 Termux！"
        exit 1
    fi
}

ensure_dialog() {
    if ! command -v dialog >/dev/null 2>&1; then
        pkg install -y dialog
    fi
}

# 强制 dialog 走 tty + stdout（关键）
dialog_menu() {
    exec 2>/dev/tty
    dialog --clear --title "$1" \
        --menu "$2" 15 60 6 "${@:3}" \
        --stdout
}

dialog_input() {
    exec 2>/dev/tty
    dialog --clear --title "$1" \
        --inputbox "$2" 10 70 "$3" \
        --stdout
}

prepare_local_rootfs() {
    local p="$1"
    if [ -z "$p" ]; then return 1; fi
    p=$(eval echo "$p")
    if [ -f "$p" ]; then
        local d="$HOME/.local_rootfs/$(basename "${p%.*}")_$(date +%s)"
        mkdir -p "$d"
        tar -xf "$p" -C "$d"
        echo "$d"
    elif [ -d "$p" ]; then
        echo "$p"
    else
        return 1
    fi
}

# ============ 主流程 ============
main() {
    check_termux
    ensure_dialog

    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════╗"
    echo "║     Termux XFCE4 Desktop Installer    ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"

    log_step "更新 Termux..."
    pkg update -y && pkg upgrade -y

    log_step "安装宿主依赖..."
    pkg install -y proot-distro termux-x11-nightly pulseaudio \
        wget curl git vim dialog tsu

    # ===== 安装方式 =====
    method=$(dialog_menu "安装方式" "选择安装来源" \
        1 "Remote (proot-distro 网络镜像)" \
        2 "Local (本地 rootfs / tar)")

    method=${method:-1}

    if [ "$method" = "1" ]; then
        INSTALL=remote
        distro=$(dialog_menu "发行版" "选择容器系统" \
            1 "Debian 12（推荐）" \
            2 "Ubuntu 24.04" \
            3 "Arch Linux")

        case "$distro" in
            1) DISTRO=debian ;;
            2) DISTRO=ubuntu ;;
            3) DISTRO=archlinux ;;
            *) DISTRO=debian ;;
        esac

        log_info "安装 $DISTRO ..."
        proot-distro install "$DISTRO"
        ROOTFS=$(proot-distro rootfs "$DISTRO")
    else
        INSTALL=local
        path=$(dialog_input "本地 rootfs" "输入目录或 tar 路径" "")
        [ -z "$path" ] && exit 1
        ROOTFS=$(prepare_local_rootfs "$path") || {
            log_error "rootfs 准备失败"; exit 1;
        }
        DISTRO="local-$(basename "$ROOTFS")"
    fi

    # ===== 复制 xfce4.sh =====
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    XFCE="$SCRIPT_DIR/xfce4.sh"

    if [ ! -f "$XFCE" ]; then
        log_error "xfce4.sh 不存在！"
        exit 1
    fi

    mkdir -p "$ROOTFS/root"
    cp "$XFCE" "$ROOTFS/root/xfce4.sh"
    chmod +x "$ROOTFS/root/xfce4.sh"

    # ===== 容器内执行 =====
    log_step "在容器内安装 XFCE4（可能需要几分钟）..."
    if [ "$INSTALL" = "remote" ]; then
        proot-distro login "$DISTRO" -- bash /root/xfce4.sh
    else
        proot -0 -S "$ROOTFS" /bin/bash /root/xfce4.sh
    fi

    # ===== 宿主环境 =====
    grep -q "Termux XFCE4" "$HOME/.bashrc" 2>/dev/null || cat >> "$HOME/.bashrc" << 'EOF'

# Termux XFCE4
export DISPLAY=:0
export PULSE_SERVER=127.0.0.1
alias start-desktop='bash $HOME/start'
alias stop-desktop='pkill -f termux-x11'
EOF

    chmod +x "$SCRIPT_DIR/start" 2>/dev/null || true

    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════╗"
    echo "║         ✅ 安装完成！                 ║"
    echo "╠══════════════════════════════════════╣"
    echo "║  ./start 启动桌面                     ║"
    echo "║  首次请先打开 Termux-X11 App          ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
}

main
