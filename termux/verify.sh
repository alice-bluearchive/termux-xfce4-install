#!/data/data/com.termux/files/usr/bin/bash
###############################################################################
# verify.sh — 安装完成后验证脚本
# 运行位置：Termux 宿主环境
# 检查宿主和容器内的关键组件是否正确安装
###############################################################################

# ============ 颜色定义 ============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ============ 工具函数 ============
PASS=0
FAIL=0
WARN=0

check_pass() {
    echo -e "  ${GREEN}✓ PASS${NC} — $*"
    PASS=$((PASS + 1))
}

check_fail() {
    echo -e "  ${RED}✗ FAIL${NC} — $*"
    FAIL=$((FAIL + 1))
}

check_warn() {
    echo -e "  ${YELLOW}⚠ WARN${NC} — $*"
    WARN=$((WARN + 1))
}

section() {
    echo
    echo -e "${CYAN}${BOLD}━━━ $* ━━━${NC}"
}

# ============ 检测发行版 ============
detect_distro() {
    if proot-distro list 2>/dev/null | grep -q "debian.*installed"; then
        DISTRO="debian"
    elif proot-distro list 2>/dev/null | grep -q "ubuntu.*installed"; then
        DISTRO="ubuntu"
    elif proot-distro list 2>/dev/null | grep -q "archlinux.*installed"; then
        DISTRO="archlinux"
    else
        DISTRO=""
    fi
}

# ============ 主流程 ============
main() {
    clear
    echo -e "${BLUE}${BOLD}"
    cat << 'EOF'
╔════════════════════════════════════════════════════════╗
║              Termux XFCE4 安装验证工具                 ║
╚════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo

    # ===== 1. Termux 基础环境 =====
    section "1. Termux 宿主环境"

    if [ -n "$PREFIX" ] && [ -d "/data/data/com.termux/files/usr" ]; then
        check_pass "Termux 环境检测通过"
    else
        check_fail "非 Termux 环境"
    fi

    if command -v pkg >/dev/null 2>&1; then
        check_pass "pkg 包管理器可用"
    else
        check_fail "pkg 不可用"
    fi

    if [ -w "$HOME" ]; then
        check_pass "HOME 目录可写"
    else
        check_fail "HOME 目录不可写"
    fi

    # ===== 2. 宿主关键包 =====
    section "2. 宿主关键软件包"

    local host_pkgs=("proot-distro" "termux-x11-nightly" "pulseaudio" "wget" "curl" "git")
    for pkg_name in "${host_pkgs[@]}"; {
        if command -v "$pkg_name" >/dev/null 2>&1 || dpkg -l "$pkg_name" 2>/dev/null | grep -q "^ii"; then
            check_pass "$pkg_name 已安装"
        else
            check_fail "$pkg_name 未安装"
        fi
    }

    # ===== 3. proot 容器 =====
    section "3. proot-distro 容器"

    if command -v proot-distro >/dev/null 2>&1; then
        check_pass "proot-distro 可用"

        detect_distro
        if [ -n "$DISTRO" ]; then
            check_pass "检测到已安装的容器: $DISTRO"
        else
            check_fail "未检测到已安装的 proot 容器"
            DISTRO=""
        fi
    else
        check_fail "proot-distro 不可用"
        DISTRO=""
    fi

    # ===== 4. 容器内检查 =====
    if [ -n "$DISTRO" ]; then
        section "4. 容器内 XFCE4 组件 ($DISTRO)"

        # 检查 xfce4 是否安装
        if proot-distro login "$DISTRO" -- dpkg -l xfce4 2>/dev/null | grep -q "^ii"; then
            check_pass "XFCE4 桌面已安装"
        else
            check_fail "XFCE4 桌面未安装"
        fi

        # 检查 xfce4-session
        if proot-distro login "$DISTRO" -- command -v xfce4-session 2>/dev/null; then
            check_pass "xfce4-session 可用"
        else
            check_fail "xfce4-session 不可用"
        fi

        # 检查 xfce4-terminal
        if proot-distro login "$DISTRO" -- command -v xfce4-terminal 2>/dev/null; then
            check_pass "xfce4-terminal 可用"
        else
            check_warn "xfce4-terminal 未安装"
        fi

        # 检查 Thunar
        if proot-distro login "$DISTRO" -- command -v thunar 2>/dev/null; then
            check_pass "Thunar 文件管理器可用"
        else
            check_warn "Thunar 未安装"
        fi

        # 检查 fcitx5
        if proot-distro login "$DISTRO" -- command -v fcitx5 2>/dev/null; then
            check_pass "fcitx5 输入法已安装"
        else
            check_warn "fcitx5 输入法未安装"
        fi

        # 检查中文字体
        if proot-distro login "$DISTRO" -- fc-list :lang=zh 2>/dev/null | grep -q "."; then
            check_pass "中文字体可用"
        else
            check_warn "未检测到中文字体"
        fi

        # 检查 Firefox
        if proot-distro login "$DISTRO" -- command -v firefox-esr 2>/dev/null; then
            check_pass "Firefox ESR 已安装"
        else
            check_warn "Firefox ESR 未安装"
        fi

        # 检查 PulseAudio
        if proot-distro login "$DISTRO" -- command -v pulseaudio 2>/dev/null; then
            check_pass "PulseAudio 已安装"
        else
            check_warn "PulseAudio 未安装"
        fi

        # 检查 dbus
        if proot-distro login "$DISTRO" -- command -v dbus-daemon 2>/dev/null; then
            check_pass "D-Bus 已安装"
        else
            check_fail "D-Bus 未安装"
        fi

        # 检查启动脚本
        if proot-distro login "$DISTRO" -- [ -x /usr/local/bin/start-xfce4-desktop ] 2>/dev/null; then
            check_pass "容器内启动脚本存在且可执行"
        else
            check_fail "容器内启动脚本缺失"
        fi

        # 检查 .xinitrc
        if proot-distro login "$DISTRO" -- [ -f /root/.xinitrc ] 2>/dev/null; then
            check_pass "~/.xinitrc 存在"
        else
            check_warn "~/.xinitrc 不存在"
        fi
    fi

    # ===== 5. Termux-X11 =====
    section "5. Termux-X11 显示服务"

    if command -v termux-x11 >/dev/null 2>&1; then
        check_pass "Termux-X11 命令可用"
    else
        check_fail "Termux-X11 命令不可用（请确认已安装 termux-x11-nightly）"
    fi

    # 检查 termux-x11.apk 是否已安装（通过 pm 命令）
    if pm list packages 2>/dev/null | grep -q "com.termux.x11"; then
        check_pass "Termux-X11 APK 已安装"
    else
        check_warn "Termux-X11 APK 未检测到（请确保 Android 端已安装）"
    fi

    # ===== 6. 启动脚本 =====
    section "6. 启动脚本"

    local script_dir
    script_dir="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$PWD")")"

    if [ -x "$script_dir/start" ]; then
        check_pass "start 脚本存在且可执行"
    else
        check_fail "start 脚本不可执行（请运行 chmod +x start）"
    fi

    # ===== 7. 网络与存储 =====
    section "7. 网络与存储"

    if ping -c 1 -W 3 deb.debian.org >/dev/null 2>&1 || ping -c 1 -W 3 archive.ubuntu.com >/dev/null 2>&1; then
        check_pass "网络连接正常"
    else
        check_warn "无法访问软件源（可能网络受限）"
    fi

    local free_space
    free_space=$(df -h "$HOME" | awk 'NR==2{print $4}')
    echo -e "  ${CYAN}INFO${NC} — HOME 可用空间: $free_space"

    # ===== 汇总 =====
    echo
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  验证结果汇总:${NC}"
    echo -e "  ${GREEN}通过: $PASS${NC}"
    echo -e "  ${RED}失败: $FAIL${NC}"
    echo -e "  ${YELLOW}警告: $WARN${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo

    if [ "$FAIL" -eq 0 ]; then
        echo -e "${GREEN}${BOLD}  🎉 所有关键检查通过！可以运行 ./start 启动桌面。${NC}"
    else
        echo -e "${RED}${BOLD}  ⚠️  存在 $FAIL 项失败，请修复后重试。${NC}"
        echo -e "${YELLOW}  提示: 重新运行 bash install.sh 可修复大部分问题${NC}"
    fi
    echo

    exit $FAIL
}

main "$@"
