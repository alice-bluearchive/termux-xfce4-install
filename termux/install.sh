#!/data/data/com.termux/files/usr/bin/bash
###############################################################################
# install.sh — Termux 宿主环境安装脚本
# 功能：安装宿主依赖 + 创建 proot 容器 + 调用 xfce4.sh 配置桌面
###############################################################################

set -e

# ============ 颜色定义 ============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============ 工具函数 ============
log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "${CYAN}[STEP]${NC} $*"; }

# 检查是否为 Termux 环境
check_termux() {
    if [ -z "$PREFIX" ] || [ ! -d "/data/data/com.termux/files/usr" ]; then
        log_error "本脚本只能在 Termux 环境中运行！"
        log_error "请从 F-Droid 安装 Termux: https://f-droid.org/en/packages/com.termux/"
        exit 1
    fi
}

# 交互确认
confirm() {
    local prompt="$1"
    local default="${2:-y}"
    local answer
    if [ "$default" = "y" ]; then
        read -r -p "$prompt [Y/n] " answer
        answer="${answer:-y}"
    else
        read -r -p "$prompt [y/N] " answer
        answer="${answer:-n}"
    fi
    case "$answer" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        *) return 1 ;;
    esac
}

# ============ 主流程 ============
main() {
    clear
    echo -e "${BLUE}"
    cat << 'EOF'
╔════════════════════════════════════════════════════════╗
║          Termux XFCE4 Desktop Installer                ║
║          ───────────────────────────────────           ║
║          一键安装 proot 容器 + XFCE4 桌面              ║
╚════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo

    # Step 0: 环境检查
    log_step "检查运行环境..."
    check_termux
    log_info "Termux 环境检测通过 ✓"
    echo

    # Step 1: 更新 Termux 包
    log_step "更新 Termux 软件包..."
    pkg update -y
    pkg upgrade -y
    log_info "Termux 软件包更新完成 ✓"
    echo

    # Step 2: 安装宿主依赖
    log_step "安装宿主环境依赖包..."
    local host_packages=(
        "proot-distro"
        "termux-x11-nightly"
        "pulseaudio"
        "wget"
        "curl"
        "git"
        "vim"
        "nanorc"
        "dialog"
        "tsu"
    )

    for pkg_name in "${host_packages[@]}"; do
        log_info "安装: $pkg_name"
        pkg install -y "$pkg_name" || log_warn "$pkg_name 安装失败，继续..."
    done
    log_info "宿主依赖安装完成 ✓"
    echo

    # Step 3: 选择发行版
    echo -e "${YELLOW}请选择要安装的容器发行版:${NC}"
    echo "  1) Debian 12（推荐）"
    echo "  2) Ubuntu 24.04"
    echo "  3) Arch Linux（实验性）"
    read -r -p "输入选项 [1-3] (默认 1): " distro_choice
    distro_choice="${distro_choice:-1}"

    case "$distro_choice" in
        1) DISTRO="debian" ;;
        2) DISTRO="ubuntu" ;;
        3) DISTRO="archlinux" ;;
        *)  log_warn "无效选项，默认使用 Debian"; DISTRO="debian" ;;
    esac
    log_info "选择的发行版: $DISTRO"
    echo

    # Step 4: 安装 proot 容器
    log_step "通过 proot-distro 安装 $DISTRO 容器..."
    proot-distro install "$DISTRO"
    log_info "$DISTRO 容器安装完成 ✓"
    echo

    # Step 5: 复制 xfce4.sh 到容器内
    log_step "复制桌面配置脚本到容器内..."
    local script_dir
    script_dir="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$PWD")")"
    local xfce4_script="$script_dir/xfce4.sh"

    if [ ! -f "$xfce4_script" ]; then
        log_error "找不到 xfce4.sh 脚本: $xfce4_script"
        log_error "请确保 xfce4.sh 与 install.sh 在同一目录"
        exit 1
    fi

    # 使用 proot-distro 的 rootfs 路径
    local container_home
    container_home="$(proot-distro rootfs "$DISTRO" 2>/dev/null)/root"
    mkdir -p "$container_home"
    cp "$xfce4_script" "$container_home/xfce4.sh"
    chmod +x "$container_home/xfce4.sh"
    log_info "xfce4.sh 已复制到容器 ~/xfce4.sh ✓"
    echo

    # Step 6: 在容器内执行 xfce4.sh
    log_step "在 $DISTRO 容器内安装 XFCE4 桌面（这可能需要几分钟）..."
    echo
    proot-distro login "$DISTRO" -- bash /root/xfce4.sh
    log_info "容器内 XFCE4 桌面安装完成 ✓"
    echo

    # Step 7: 配置宿主启动环境
    log_step "配置宿主环境..."

    # 写入 ~/.bashrc 追加内容
    local bashrc_append
    bashrc_append=$(cat << BASHRC_EOF

# ===== Termux XFCE4 Desktop =====
export DISPLAY=:0
export PULSE_SERVER=127.0.0.1

# 启动桌面别名
alias start-desktop='$script_dir/start'
alias stop-desktop='pkill -f termux-x11; pkill -f pulseaudio'
BASHRC_EOF
)

    if ! grep -q "Termux XFCE4 Desktop" "$HOME/.bashrc" 2>/dev/null; then
        echo "$bashrc_append" >> "$HOME/.bashrc"
        log_info "已添加启动别名到 ~/.bashrc ✓"
    else
        log_info "~/.bashrc 已配置，跳过 ✓"
    fi

    # 确保 start 脚本可执行
    chmod +x "$script_dir/start" 2>/dev/null || true
    chmod +x "$script_dir/verify.sh" 2>/dev/null || true
    echo

    # Step 8: 完成
    echo -e "${GREEN}"
    cat << 'EOF'
╔════════════════════════════════════════════════════════╗
║                  ✅ 安装完成！                         ║
╠════════════════════════════════════════════════════════╣
║                                                        ║
║  下一步:                                               ║
║    1. 运行验证:  bash verify.sh                       ║
║    2. 启动桌面:  ./start                              ║
║                                                        ║
║  注意: 首次启动前请确保 Termux-X11 App 已安装并打开    ║
╚════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

main "$@"
