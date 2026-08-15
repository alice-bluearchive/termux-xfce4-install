# 常见问题排查 (Troubleshooting)

## 1. Termux-X11 启动后黑屏

**可能原因：**
- Termux-X11 APK 未安装或版本过旧
- `DISPLAY` 环境变量未正确设置

**解决方案：**
```bash
# 确认 APK 已安装
pm list packages | grep termux.x11

# 手动设置 DISPLAY 后启动
export DISPLAY=:0
termux-x11 :0 &
```

## 2. 无法输入中文

**可能原因：**
- fcitx5 未自动启动
- 环境变量未注入

**解决方案：**
```bash
# 在容器内手动启动 fcitx5
proot-distro login debian -- fcitx5 -d

# 确认环境变量
echo $GTK_IM_MODULE  # 应输出 fcitx
echo $XMODIFIERS     # 应输出 @im=fcitx
```

## 3. 没有声音

**可能原因：**
- Termux 宿主的 PulseAudio 未启动
- 容器内的 PulseAudio 配置指向错误地址

**解决方案：**
```bash
# 宿主端
pulseaudio --start --exit-idle-time=-1

# 容器内确认配置
cat /etc/pulse/client.conf
# 确保有: default-server = 127.0.0.1
```

## 4. 安装过程中断网/失败

**解决方案：**
```bash
# 重新运行安装脚本，已安装的部分会自动跳过
bash install.sh

# 或手动在容器内执行
proot-distro login debian -- apt install -y xfce4 xfce4-goodies
```

## 5. `proot-distro` 命令找不到

**原因：** Termux 基础包未安装

**解决方案：**
```bash
pkg update -y
pkg install -y proot-distro
```

## 6. 存储空间不足

**解决方案：**
```bash
# 清理 apt 缓存
proot-distro login debian -- apt clean
proot-distro login debian -- apt autoremove -y

# 查看各容器大小
du -sh $PREFIX/var/lib/proot-distro/installed-rootfs/*
```

## 7. 启动桌面后闪退

**可能原因：**
- dbus 未启动
- `.xinitrc` 权限不对

**解决方案：**
```bash
# 在容器内手动测试
proot-distro login debian -- dbus-launch xfce4-session

# 确认文件权限
proot-distro login debian -- ls -la /root/.xinitrc
# 应显示 -rwxr-xr-x
```

## 8. GitHub 上 clone 下来的脚本无法执行

**原因：** 换行符被转换为 CRLF

**解决方案：**
```bash
# 安装 dos2unix
pkg install -y dos2unix

# 转换所有脚本
cd termux
dos2unix install.sh xfce4.sh verify.sh start
chmod +x install.sh xfce4.sh verify.sh start
```

## 9. 如何切换不同发行版

```bash
# 查看已安装的容器
proot-distro list

# 安装新的
proot-distro install ubuntu

# 修改 start 脚本中的 DISTRO 变量，或重新运行 install.sh 选择
```

## 10. 如何完全卸载

```bash
# 删除容器
proot-distro remove debian

# 删除宿主包
pkg uninstall -y proot-distro termux-x11-nightly pulseaudio

# 删除仓库
rm -rf ~/termux-xfce4-install
```
