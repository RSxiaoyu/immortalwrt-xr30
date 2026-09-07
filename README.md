# ImmortalWrt 25.12 for CMCC XR30

[![Build ImmortalWrt for CMCC XR30](https://github.com/RSxiaoyu/immortalwrt-xr30/actions/workflows/build.yml/badge.svg)](https://github.com/RSxiaoyu/immortalwrt-xr30/actions/workflows/build.yml)

专为**中国移动 CMCC XR30** 路由器打造的现代化、极简、高性能 ImmortalWrt 25.12 固件自动构建仓库。

---

## 🌟 设计原则

- **极简工程**：拒绝成百上千行的冗余脚本与过度包装。仅保留必要的设备树与极简差异配置（`diffconfig`）。
- **完全对齐上游**：深度跟随 [ImmortalWrt 25.12](https://github.com/immortalwrt/immortalwrt/tree/openwrt-25.12) 主线，默认采用 Linux 6.12 内核、标准 DSA 架构、mt76 开源驱动与 WED 硬件加速。
- **现代化 All-in-FIT (.itb)**：采用与官方架构一致的 FIT 单镜像标准，内核与 SquashFS 根系统全合一，通过 `fitblk` 自动挂载 UBI `fit` 卷。
- **零环境依赖**：专用的设备树直接内建 SPI-NAND 与闪存分区定义，并在设备树中硬编码 `root=/dev/fit0 rootwait`。即便 XR30 硬件层写保护锁定 U-Boot 环境变量区，也能零配置直接启动。
- **物理拓扑精准对齐**：
  - **网络接口**：独立千兆 WAN 口 (`gmac1`)，物理 LAN1-3 精准对应 MT7531 交换机端口。
  - **LED 状态灯**：XR30 真实机身红白双色状态灯映射（红灯 `GPIO 35`，白灯 `GPIO 34`）。
- **自动化追踪**：GitHub Actions 周期性比对上游 commit，有更新时自动触发构建并发布 Release。

---

## 硬件规格

| 项目 | 规格参数 |
| :--- | :--- |
| **SoC** | MediaTek MT7981B (Filogic 820, 双核 Cortex-A53 @ 1.3GHz) |
| **内存** | 256MB DDR3 |
| **闪存** | 128MB SPI-NAND (GigaDevice `GD5F1GM7UEYIG`) |
| **交换机芯片** | MediaTek MT7531AE |
| **无线芯片** | MT7981 2.4G (2x2 AX 574Mbps) + 5G (3x3 AX 2402Mbps @ 160MHz) |
| **接口** | 1 × GE WAN, 3 × GE LAN, 1 × Reset, 1 × Mesh |

---

## 📦 固件下载与刷写

前往 [Releases 页面](https://github.com/RSxiaoyu/immortalwrt-xr30/releases) 下载最新固件：

- `*squashfs-sysupgrade.itb`：常规升级镜像。
- `*initramfs-recovery.itb`：内存救援恢复镜像。

### 刷写方式

#### 1. 运行中系统 / Initramfs 下升级
通过 SCP 上传 `sysupgrade.itb` 至路由器的 `/tmp` 目录，执行：
```bash
sysupgrade -n /tmp/*squashfs-sysupgrade.itb
```

#### 2. U-Boot Web 恢复控制台
在 U-Boot Web 页面（通常为 `192.168.1.1`）选择 `*squashfs-sysupgrade.itb` 直接上传刷入。

---

## ⚙️ 默认系统信息

- **管理地址**：`192.168.1.1`
- **用户名**：`root`
- **默认密码**：无（首次登录无需输入密码）
- **默认主题**：Argon
- **Wi-Fi**：首次启动默认开启，SSID 为 `ImmortalWrt-2.4G` / `ImmortalWrt-5G`，无密码。

---

## 📄 许可协议

本项目遵循 [GPL-2.0](LICENSE) 许可协议。
固件上游源码归 [ImmortalWrt 项目组](https://github.com/immortalwrt/immortalwrt) 所有。
