# ImmortalWrt for CMCC XR30 (ubootmod)

[![Build](https://github.com/RSxiaoyu/immortalwrt-xr30/actions/workflows/build.yml/badge.svg)](https://github.com/RSxiaoyu/immortalwrt-xr30/actions/workflows/build.yml)

专为 **中国移动 CMCC XR30** 打造的纯粹上游 ImmortalWrt 25.12 固件构建仓库。

基于官方 **ImageBuilder (镜像生成器)** 架构重构，跳过冗长的工具链与内核重复编译，**1 分半钟极速打包出炉**，100% 享受官方稳定内核与预编译软件源生态。

## 特性
- **构建机制**：官方 ImageBuilder 引擎打包，1 分半钟全速直出，零编译报错风险。
- **架构**：全合一 FIT 单镜像 (`sysupgrade.itb`)，原生 `fitblk` 挂载。
- **直通**：专为 `ubootmod` 打造，废除 NMBM，原生 MTD/UBI 直通（UBI 卷空间 122.5MB，可用磁盘 90MB+）。
- **硬件**：精准注入 XR30 专用 DTB，红白状态灯、WPS/Mesh 按键、独立千兆 WAN/LAN 完全校准，完整启用 512MB DDR4。
- **性能**：Linux 6.12 + DSA 架构 + WED 硬件加速 + MTK PPE 硬件流量分载 + Packet Steering 多核分发 + BBR 拥塞控制。
- **透明代理**：开箱即用，出厂直接预集成 [OpenWrt-momo](https://github.com/nikkinikki-org/OpenWrt-momo) 最新版 + 官方最新正式版 **sing-box**，以及全套内核模块 (`kmod-dummy`, `kmod-nft-socket`, `kmod-nft-tproxy`, `kmod-tun`, `kmod-inet-diag`, `kmod-netlink-diag`)。
- **扩展与终端**：内置 TTYD 网页终端与 Argon 现代主题。
- **免维护**：每周一凌晨定时自动感知并同步 SagerNet sing-box、Momo 与 ImmortalWrt 最新版本。

## 硬件规格
| 项 | 规格 |
| :--- | :--- |
| **SoC** | MediaTek MT7981B (双核 Cortex-A53 @ 1.3GHz) |
| **内存 / 闪存** | 512MB DDR4 / 128MB SPI-NAND (GD5F1GM7) |
| **网口** | 1 × GE WAN, 3 × GE LAN (MT7531AE 交换芯片直通) |
| **无线** | 2.4G (574M) + 5G (2402M @ 160MHz), mt76 开源驱动 |

## 刷写与使用
1. **升级固件**：在 [bl-mt798x-xr30](https://github.com/RSxiaoyu/bl-mt798x-xr30) U-Boot Web 恢复控制台 (`192.168.1.1`) 直接上传 `*sysupgrade.itb` 刷入；或在运行系统中执行 `sysupgrade -n *.itb`。
2. **默认管理**：`192.168.1.1` ｜ 用户名：`root` ｜ 默认无密码。
3. **Momo 代理**：刷入开机后，Momo 与 Sing-box 已预装并就绪，进入 LuCI 菜单即可直接配置使用；后续亦支持在线热更新。
