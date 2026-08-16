# rootfs 目录

本目录存放 **Debian Trixie (arm64) proot 离线镜像**，
供 `install` 脚本在无法访问 GitHub / proot-distro 官方源时使用。

## 当前内置镜像

- 文件名：`debian-trixie_arm64-rootfs.tar.xz`
- 大小：~87 MB
- 架构：aarch64 / arm64
- 来源：tmoe 构建，已验证可启动

## 脚本行为

1. 优先使用本目录下的 rootfs（离线安装，最快）
2. 不存在时尝试从 Release 下载
3. 仍失败则调用 tmoe 脚本兜底

## ⚠️ 注意事项

- **不要手动解压**
- 不要修改文件名（脚本靠它匹配）
- 更换版本时：
  1. 删除旧文件
  2. 放入新 `xxx.tar.xz`
  3. 更新 `install` 里的 `ROOTFS_NAME`（新版的install.sh支持本地安装和在线安装两种）

---

> 本目录存在 = 你的手机可以不联网装 Debian
