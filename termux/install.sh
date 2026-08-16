#!/data/data/com.termux/files/usr/bin/bash
###############################################################################
# install.sh — Termux 宿主环境安装脚本
# 功能：安装宿主依赖 + 创建 proot 容器 + 调用 xfce4.sh 配置桌面
#      增强：支持使用用户本地 rootfs（目录或 tar 包）安装，并用 dialog 提供
#      基于 GUI 的选择和输入（上下方向键选择、输入路径）。
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

# 交互确认（回退到文本交互）
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

# 使用 dialog 显示菜单（如果可用），否则回落到文本输入
dialog_menu() {
    # $1 = title, $2 = prompt, followed by pairs: tag item ...
    if command -v dialog >/dev/null 2>&1; then
        local tmp
        tmp=$(mktemp)
        dialog --title "$1" --menu "$2" 15 60 6 "$@" 2>"$tmp" || true
        local res
        res=$(cat "$tmp" 2>/dev/null || echo "")
        rm -f "$tmp"
        echo "$res"
    else
        # 简单回退：打印选项并读取数值（读取第一个参数作为选择）
        echo "$2"
        shift 2
        local i=1
        local tags=()
        while [ "$#" -gt 0 ]; do
            tags+=("$1")
            echo "$1) $2"
            shift 2
            i=$((i+1))
        done
        read -r -p "输入选项: " choice
        echo "$choice"
    fi
}

# 使用 dialog 输入框获取文本
dialog_inputbox() {
    # $1 = title, $2 = prompt, $3 = default
    if command -v dialog >/dev/null 2>&1; then
        local tmp
        tmp=$(mktemp)
        dialog --title "$1" --inputbox "$2" 8 60 "$3" 2>"$tmp" || true
        local res
        res=$(cat "$tmp" 2>/dev/null || echo "")
        rm -f "$tmp"
        echo "$res"
    else
        read -r -p "$2" res
        echo "$res"
    fi
}

# 将本地 rootfs（目录或 tar 包）准备到一个可 proot 使用的目录
prepare_local_rootfs() {
    local input_path="$1"
    if [ -z "$input_path" ]; then
        log_error "没有提供本地 rootfs 路径"
        return 1
    fi

    # 如果是文件（假定为 tar 包），则解压到 $HOME/.local_rootfs/<name>_<ts>
    if [ -f "$input_path" ]; then
        mkdir -p "$HOME/.local_rootfs"
        local base
        base=$(basename "$input_path")
        local name
        name="${base%.*}"
        local dest="$HOME/.local_rootfs/${name}_$(date +%s)"
        mkdir -p "$dest"
        log_info "检测到文件: $input_path，正在解压到 $dest ..."
        if tar -xf "$input_path" -C "$dest"; then
            log_info "解压完成: $dest"
            echo "$dest"
            return 0
        else
            log_error "解压失败: $input_path"
            return 2
        fi
    elif [ -d "$input_path" ]; then
        # 直接使用目录
        log_info "使用目录作为 rootfs: $input_path"
        echo "$input_path"
        return 0
    else
        log_error "指定路径既不是文件也不是目录: $input_path"
        return 3
    fi
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

    # Step 3: 选择安装方式（GUI 菜单：Remote 或 Local）
    log_step "选择安装方式..."
    # 使用 dialog 菜单：上下键选择
    install_choice=$(dialog_menu "安装方式" "请选择要使用的安装方式（上下键选择并回车确认）:" 1 "Remote (proot-distro) - 从网络镜像安装" 2 "Local (本地 rootfs) - 使用本地目录或 tar 包")
    install_choice=${install_choice:-1}

    if [ "$install_choice" = "1" ] || [ "$install_choice" = "Remote" ]; then
        INSTALL_METHOD="remote"
        # 选择发行版（同样使用 dialog 菜单）
        distro_choice=$(dialog_menu "选择发行版" "请选择要安装的容器发行版:" 1 "Debian 12（推荐）" 2 "Ubuntu 24.04" 3 "Arch Linux（实验性）")
        distro_choice=${distro_choice:-1}
        case "$distro_choice" in
            1|"1") DISTRO="debian" ;;
            2|"2") DISTRO="ubuntu" ;;
            3|"3") DISTRO="archlinux" ;;
            Debian|Ubuntu|Arch) # in case dialog returned the tag text
                if echo "$distro_choice" | grep -iq debian; then DISTRO="debian"; fi
                if echo "$distro_choice" | grep -iq ubuntu; then DISTRO="ubuntu"; fi
                if echo "$distro_choice" | grep -iq arch; then DISTRO="archlinux"; fi
                ;;
            *) log_warn "无效选项，默认使用 Debian"; DISTRO="debian" ;;
        esac
        log_info "选择的发行版: $DISTRO"

    else
        INSTALL_METHOD="local"
        # 让用户输入本地 rootfs 路径（目录或 tar 包），通过 dialog 输入框
        local_path=$(dialog_inputbox "本地 rootfs 路径" "请输入本地 rootfs 的路径（目录或 tar 包 .tar/.tar.gz/.tar.xz 等）：" "")
        # 允许用户通过回车取消
        if [ -z "$local_path" ]; then
            log_error "未提供本地 rootfs 路径，脚本退出。"
            exit 1
        fi
        # 展开 ~
        if echo "$local_path" | grep -q "^~"; then
            local_path="${local_path/#\u007f/$HOME}"
            # above is a safe in-place; simpler: expand
            local_path="$(eval echo $local_path)"
        fi
        log_info "本地 rootfs 路径: $local_path"
    fi
    echo

    # Step 4: 安装 proot 容器（远程或本地）
    if [ "$INSTALL_METHOD" = "remote" ]; then
        log_step "通过 proot-distro 安装 $DISTRO 容器..."
        proot-distro install "$DISTRO"
        log_info "$DISTRO 容器安装完成 ✓"
        container_rootfs_dir="$(proot-distro rootfs "$DISTRO" 2>/dev/null)"
    else
        log_step "使用本地 rootfs 安装容器..."
        prepared_dir=$(prepare_local_rootfs "$local_path")
        if [ $? -ne 0 ]; then
            log_error "准备本地 rootfs 失败，退出。"
            exit 1
        fi
        # prepared_dir 是可以直接作为 proot -S 的目录
        container_rootfs_dir="$prepared_dir"
        log_info "本地 rootfs 准备好: $container_rootfs_dir"
        # 尝试创建一个短别名名供后续使用
        DISTRO="local-$(basename "$container_rootfs_dir")"
    fi
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

    # 如果是 proot-distro 安装，使用其 rootfs 路径
    if [ "$INSTALL_METHOD" = "remote" ]; then
        # proot-distro rootfs 输出目录可能不以 / 结尾
        container_home="${container_rootfs_dir}/root"
        mkdir -p "$container_home"
        cp "$xfce4_script" "$container_home/xfce4.sh"
        chmod +x "$container_home/xfce4.sh"
        log_info "xfce4.sh 已复制到容器 ~/xfce4.sh ✓"
    else
        # 本地 rootfs：直接复制到该目录的 /root
        container_home="$container_rootfs_dir/root"
        mkdir -p "$container_home"
        cp "$xfce4_script" "$container_home/xfce4.sh"
        chmod +x "$container_home/xfce4.sh"
        log_info "xfce4.sh 已复制到本地 rootfs 的 /root/xfce4.sh ✓"
    fi
    echo

    # Step 6: 在容器内执行 xfce4.sh
    log_step "在容器内安装 XFCE4 桌面（这可能需要几分钟）..."
    echo
    if [ "$INSTALL_METHOD" = "remote" ]; then
        proot-distro login "$DISTRO" -- bash /root/xfce4.sh
    else
        # 使用 proot -S 启动本地 rootfs 并运行脚本
        if command -v proot >/dev/null 2>&1; then
            log_info "使用 proot 启动本地 rootfs 并运行 /root/xfce4.sh"
            proot -0 -S "$container_rootfs_dir" /bin/bash /root/xfce4.sh
        else
            log_error "系统中未找到 proot 命令，无法启动本地 rootfs。请先安装 proot 包。"
            exit 1
        fi
    fi
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
