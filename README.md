# ImmortalWrt for CMCC XR30 (ubootmod)

[![Build](https://github.com/RSxiaoyu/immortalwrt-xr30/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/RSxiaoyu/immortalwrt-xr30/actions/workflows/build.yml)

专为 **中国移动 CMCC XR30** 打造的纯粹上游 ImmortalWrt 25.12 固件构建仓库。

基于官方 **ImageBuilder (镜像生成器)** 架构重构，跳过冗长的工具链与内核重复编译，**2 分钟极速打包出炉**，100% 享受官方稳定内核与预编译软件源生态。

## 特性
- **构建机制**：官方 ImageBuilder 引擎打包，2 分钟全速直出，零编译报错风险。
- **架构**：全合一 FIT 单镜像 (`sysupgrade.itb`)，原生 `fitblk` 挂载。
- **直通**：专为 `ubootmod` 打造，废除 NMBM，原生 MTD/UBI 直通（UBI 卷空间 122.5MB，可用磁盘 90MB+）。
- **硬件**：精准注入 XR30 专用 DTB，红白状态灯、WPS/Mesh 按键、独立千兆 WAN/LAN、USB 3.0 完全校准，完整启用 512MB DDR4。
- **存储扩展**：内置 USB 3.0 (UAS 加速) 及 ext4/vfat/exFAT 自动挂载。
- **性能**：Linux 6.12 + DSA 架构 + WED 硬件加速 + MTK PPE 硬件流量分载 + Packet Steering 多核分发 + BBR 拥塞控制。
- **透明代理**：内置 ImmortalWrt 官方 [HomeProxy](https://github.com/immortalwrt/homeproxy)（sing-box 内核，插件全量生成配置，订阅即节点源），与固件同源同版本，免第三方 feed。
- **扩展与终端**：内置 TTYD 网页终端与 Argon 现代主题。
- **免维护**：每周一凌晨定时同步 ImmortalWrt 官方源最新版（含 HomeProxy / sing-box / 内核）。

## 硬件规格
| 项 | 规格 |
| :--- | :--- |
| **SoC** | MediaTek MT7981B (双核 Cortex-A53 @ 1.3GHz) |
| **内存 / 闪存** | 512MB DDR4 / 128MB SPI-NAND (GD5F1GM7) |
| **网口 / USB** | 1 × GE WAN, 3 × GE LAN (MT7531AE 交换芯片直通) / 1 × USB 3.0 |
| **无线** | 2.4G (574M) + 5G (2402M @ 160MHz), mt76 开源驱动 |

## 刷写与使用
1. **升级固件**：在 [bl-mt798x-xr30](https://github.com/RSxiaoyu/bl-mt798x-xr30) U-Boot Web 恢复控制台 (`192.168.1.1`) 直接上传 `*sysupgrade.itb` 刷入；或在运行系统中执行 `sysupgrade -n *.itb`。
2. **默认管理**：`192.168.1.1` ｜ 用户名：`root` ｜ 默认无密码。
3. **HomeProxy 代理**：LuCI → 服务 → HomeProxy，填入订阅即可使用；sing-box 由官方源随固件提供。
