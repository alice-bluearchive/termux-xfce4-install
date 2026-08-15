#!/bin/bash
###############################################################################
# xfce4.sh — proot 容器内 XFCE4 桌面安装与配置脚本
# 运行位置：proot-distro 容器内部
# 由 install.sh 自动调用，也可手动在容器内执行
###############################################################################

set -e

# ============ 颜色定义 ============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "${CYAN}[STEP]${NC} $*"; }

# ============ 检测发行版 ============
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="$ID"
        DISTRO_VER="$VERSION_CODENAME"
    else
        log_error "无法检测发行版，/etc/os-release 不存在"
        exit 1
    fi
    log_info "检测到发行版: $DISTRO_ID ($DISTRO_VER)"
}

# ============ 配置软件源 ============
setup_sources() {
    log_step "配置软件源..."

    case "$DISTRO_ID" in
        debian|ubuntu)
            # 备份原有源
            cp /etc/apt/sources.list /etc/apt/sources.list.bak 2>/dev/null || true

            if [ "$DISTRO_ID" = "debian" ]; then
                cat > /etc/apt/sources.list << SOURCES_EOF
deb http://deb.debian.org/debian $DISTRO_VER main contrib non-free non-free-firmware
deb http://deb.debian.org/debian $DISTRO_VER-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security $DISTRO_VER-security main contrib non-free non-free-firmware
SOURCES_EOF
            elif [ "$DISTRO_ID" = "ubuntu" ]; then
                cat > /etc/apt/sources.list << SOURCES_EOF
deb http://archive.ubuntu.com/ubuntu/ $DISTRO_VER main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $DISTRO_VER-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ $DISTRO_VER-security main restricted universe multiverse
SOURCES_EOF
            fi
            ;;
        arch)
            # Arch Linux (pacman)
            log_info "Arch Linux 使用默认镜像源"
            ;;
        *)
            log_warn "未适配的发行版: $DISTRO_ID，尝试使用默认源"
            ;;
    esac
}

# ============ 安装 XFCE4 桌面 ============
install_xfce4() {
    log_step "更新软件包索引..."
    apt update -y

    log_step "安装 XFCE4 桌面环境（完整版）..."
    DEBIAN_FRONTEND=noninteractive apt install -y \
        xfce4 \
        xfce4-goodies \
        xfce4-terminal \
        xfce4-taskmanager \
        xfce4-power-manager \
        xfce4-notifyd \
        xfce4-whiskermenu-plugin \
        xfce4-pulseaudio-plugin \
        xfce4-netload-plugin \
        xfce4-systemload-plugin \
        xfce4-weather-plugin \
        thunar \
        thunar-archive-plugin \
        thunar-volman \
        gvfs \
        gvfs-backends

    log_info "XFCE4 桌面安装完成 ✓"
}

# ============ 安装中文字体 ============
install_chinese_fonts() {
    log_step "安装中文字体和输入法..."
    DEBIAN_FRONTEND=noninteractive apt install -y \
        fonts-wqy-zenhei \
        fonts-wqy-microhei \
        fonts-noto-cjk \
        fonts-noto-cjk-extra \
        fonts-dejavu \
        fonts-liberation \
        fcitx5 \
        fcitx5-chinese-addons \
        fcitx5-frontend-gtk3 \
        fcitx5-frontend-qt5 \
        fcitx5-config-qt \
        im-config

    # 配置默认语言
    locale-gen zh_CN.UTF-8 2>/dev/null || {
        echo "zh_CN.UTF-8 UTF-8" >> /etc/locale.gen
        locale-gen
    }
    update-locale LANG=zh_CN.UTF-8 2>/dev/null || true

    log_info "中文字体和输入法安装完成 ✓"
}

# ============ 安装常用软件 ============
install_apps() {
    log_step "安装常用软件..."
    DEBIAN_FRONTEND=noninteractive apt install -y \
        firefox-esr \
        mousepad \
        ristretto \
        viewnior \
        galculator \
        network-manager-gnome \
        blueman \
        xdg-utils \
        wget \
        curl \
        git \
        nano \
        vim \
        htop \
        neofetch \
        tree \
        unzip \
        zip \
        p7zip-full \
        sudo \
        dbus-x11 \
        x11-apps \
        mesa-utils

    log_info "常用软件安装完成 ✓"
}

# ============ 配置 D-Bus ============
configure_dbus() {
    log_step "配置 D-Bus..."
    mkdir -p /run/dbus
    dbus-uuidgen > /etc/machine-id 2>/dev/null || true

    # 创建 dbus 启动脚本
    cat > /usr/local/bin/start-dbus << DBUS_EOF
#!/bin/bash
mkdir -p /run/dbus
if [ ! -f /etc/machine-id ]; then
    dbus-uuidgen > /etc/machine-id
fi
if ! pgrep -x "dbus-daemon" > /dev/null; then
    dbus-daemon --system --fork
fi
DBUS_EOF
    chmod +x /usr/local/bin/start-dbus

    log_info "D-Bus 配置完成 ✓"
}

# ============ 配置 PulseAudio ============
configure_pulseaudio() {
    log_step "配置 PulseAudio 音频..."
    DEBIAN_FRONTEND=noninteractive apt install -y pulseaudio

    # 配置 PulseAudio 通过网络连接 Termux 宿主的 PulseAudio
    mkdir -p /etc/pulse
    cat > /etc/pulse/client.conf << PA_EOF
default-server = 127.0.0.1
autospawn = no
PA_EOF

    log_info "PulseAudio 配置完成 ✓"
}

# ============ 配置 X11 / 显示 ============
configure_x11() {
    log_step "配置 X11 显示环境..."

    # 安装 X11 基础包
    DEBIAN_FRONTEND=noninteractive apt install -y \
        xorg \
        xserver-xorg \
        x11-xserver-utils \
        xauth

    # 创建 .xinitrc
    cat > /root/.xinitrc << XINIT_EOF
#!/bin/bash
# 启动 fcitx5 输入法
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
fcitx5 -d &

# 启动 XFCE4
exec xfce4-session
XINIT_EOF
    chmod +x /root/.xinitrc

    # 创建 .xsession（和 .xinitrc 相同内容，兼容不同启动方式）
    cp /root/.xinitrc /root/.xsession
    chmod +x /root/.xsession

    log_info "X11 显示环境配置完成 ✓"
}

# ============ 配置主题美化 ============
configure_theme() {
    log_step "安装主题和图标..."
    DEBIAN_FRONTEND=noninteractive apt install -y \
        arc-theme \
        papirus-icon-theme \
        breeze-cursor-theme

    # 设置默认主题（写入 xfconf，首次启动后生效）
    mkdir -p /root/.config/xfce4/xfconf/xfce-perchannel-xml
    cat > /root/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml << XSETTINGS_EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Arc-Dark"/>
    <property name="IconThemeName" type="string" value="Papirus-Dark"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Noto Sans CJK SC 11"/>
    <property name="MonospaceFontName" type="string" value="DejaVu Sans Mono 11"/>
  </property>
  <property name="Xft" type="empty">
    <property name="DPI" type="int" value="96"/>
    <property name="Antialias" type="int" value="1"/>
    <property name="Hinting" type="int" value="1"/>
    <property name="HintStyle" type="string" value="hintslight"/>
    <property name="RGBA" type="string" value="rgb"/>
  </property>
</channel>
XSETTINGS_EOF

    log_info "主题美化配置完成 ✓"
}

# ============ 创建容器内的启动脚本 ============
create_container_start_script() {
    log_step "创建容器内启动脚本..."
    cat > /usr/local/bin/start-xfce4-desktop << START_EOF
#!/bin/bash
# 启动 D-Bus
start-dbus

# 设置显示和输入法环境变量
export DISPLAY=:0
export PULSE_SERVER=127.0.0.1
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx

# 启动 fcitx5
fcitx5 -d 2>/dev/null &

# 启动 XFCE4 会话
exec xfce4-session
START_EOF
    chmod +x /usr/local/bin/start-xfce4-desktop

    log_info "容器内启动脚本创建完成 ✓"
}

# ============ 清理 ============
cleanup() {
    log_step "清理无用包..."
    apt autoremove -y
    apt clean
    log_info "清理完成 ✓"
}

# ============ 主流程 ============
main() {
    echo -e "${BLUE}"
    cat << 'EOF'
╔════════════════════════════════════════════════════════╗
║       XFCE4 Desktop Setup (inside proot container)     ║
╚════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo

    detect_distro
    echo

    setup_sources
    echo

    # 更新包索引
    apt update -y
    echo

    install_xfce4
    echo

    install_chinese_fonts
    echo

    install_apps
    echo

    configure_dbus
    echo

    configure_pulseaudio
    echo

    configure_x11
    echo

    configure_theme
    echo

    create_container_start_script
    echo

    cleanup
    echo

    echo -e "${GREEN}"
    cat << 'EOF'
╔════════════════════════════════════════════════════════╗
║           ✅ 容器内 XFCE4 配置完成！                   ║
║                                                        ║
║   返回 Termux 宿主后运行:                              ║
║     ./start                                            ║
╚════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

main "$@"
