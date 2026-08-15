# termux-xfce4-install

Termux 下一键安装 proot 容器 + XFCE4 桌面环境，附带完整安装、配置、验证、启动脚本。

## 📁 目录结构

```
termux-xfce4-install/
├── README.md                  # 本文件，项目总览
├── LICENSE                     # 开源协议
├── .gitignore                  # Git 忽略规则
├── termux/
│   ├── README.md               # termux 目录说明
│   ├── install.sh              # 在 Termux 宿主环境中安装所有依赖
│   ├── xfce4.sh                # 在 proot 容器内安装并配置 XFCE4
│   ├── verify.sh               # 安装完成后验证各项功能
│   └── start                   # 启动 XFCE4 桌面会话
└── docs/
    ├── screenshots/            # 截图存放
    └── troubleshooting.md      # 常见问题排查
```

## 📋 环境要求

| 要求 | 说明 |
|------|------|
| Termux | 从 [F-Droid](https://f-droid.org/en/packages/com.termux/) 安装（非 Google Play 版） |
| Termux-X11 | 安装 [Termux-X11 APK](https://github.com/termux/termux-x11/releases) |
| 存储空间 | 至少 2GB 可用空间 |
| 网络 | 能正常访问软件源 |

## 🚀 快速开始

```bash
# 1. 克隆本仓库
git clone https://github.com/alice-bluearchive/termux-xfce4-install.git
cd termux-xfce4-install/termux

# 2. 在 Termux 中运行安装脚本（需要交互确认）
bash install.sh

# 3. 安装完成后验证
bash verify.sh

# 4. 启动桌面
./start
```

## 📜 脚本说明

| 脚本 | 运行位置 | 功能 |
|------|----------|------|
| `install.sh` | Termux 宿主 | 安装 proot-distro、Termux-X11、PulseAudio 等宿主依赖，并创建 Debian 容器 |
| `xfce4.sh` | proot 容器内 | 在 Debian 容器中安装 XFCE4 桌面、中文字体、输入法、主题等完整配置 |
| `verify.sh` | Termux 宿主 | 检查宿主和容器内的关键组件是否安装正确 |
| `start` | Termux 宿主 | 启动 PulseAudio → Termux-X11 → 登录容器并拉起 xfce4-session |

## 🛠️ 支持的容器发行版

- Debian 12（默认）
- Ubuntu 24.04
- Arch Linux（实验性）

## ❓ 常见问题

详见 [docs/troubleshooting.md](docs/troubleshooting.md)

## 📄 License

MIT License
