# termux/

本目录包含所有在 Termux 环境下运行的脚本。

## 文件说明

### `install.sh`
**运行位置**：Termux 宿主环境（直接在 Termux 里执行）

主要完成以下工作：
1. 更新 Termux 包管理器
2. 安装 `proot-distro`、`termux-x11-nightly`、`pulseaudio`、`wget`、`curl` 等基础包
3. 通过 `proot-distro` 安装 Debian 容器
4. 将 `xfce4.sh` 复制到容器内
5. 在容器内执行 `xfce4.sh` 完成桌面安装
6. 配置宿主环境变量和别名

### `xfce4.sh`
**运行位置**：proot 容器内部（由 `install.sh` 自动调用，也可手动执行）

主要完成以下工作：
1. 更新 apt 源，安装 XFCE4 桌面及插件
2. 安装中文字体（文泉驿、Noto CJK）
3. 安装中文输入法（fcitx5）
4. 安装常用软件（Firefox ESR、文件管理器、终端等）
5. 配置 D-Bus、PulseAudio 音频转发
6. 设置 `~/.xinitrc` 和 `~/.xsession`

### `verify.sh`
**运行位置**：Termux 宿主环境

验证以下内容：
- [x] Termux 基础包是否安装
- [x] proot-distro 容器是否存在
- [x] 容器内 XFCE4 是否安装成功
- [x] Termux-X11 是否可用
- [x] PulseAudio 是否正常运行
- [x] 中文字体是否可用

### `start`
**运行位置**：Termux 宿主环境

启动流程：
1. 启动 PulseAudio 音频服务
2. 启动 Termux-X11 显示服务
3. 登录 proot 容器并启动 `xfce4-session`

## 使用方式

```bash
# 一键安装（推荐）
bash install.sh

# 验证安装
bash verify.sh

# 启动桌面
./start
```

## 注意事项

- 所有脚本必须以 **LF** 换行符保存（不要用 Windows 记事本编辑）
- 脚本需要有执行权限：`chmod +x *.sh start`
- 首次运行 `install.sh` 需要交互确认（输入 y/n）
- 建议在 F-Droid 版 Termux 上运行，Google Play 版可能有兼容性问题
