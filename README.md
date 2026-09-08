# ImmortalWrt for CMCC XR30 (ubootmod)

[![Build](https://github.com/RSxiaoyu/immortalwrt-xr30/actions/workflows/build.yml/badge.svg)](https://github.com/RSxiaoyu/immortalwrt-xr30/actions/workflows/build.yml)

专为 **中国移动 CMCC XR30** 打造的纯粹上游 ImmortalWrt 25.12 固件构建仓库。

## 特性
- **架构**：全合一 FIT 单镜像 (`sysupgrade.itb`)，原生 `fitblk` 挂载。
- **直通**：专为 `ubootmod` 打造，废除 NMBM，原生 MTD/UBI 直通（UBI 卷空间 122.5MB，可用磁盘 90MB+）。
- **硬件**：精准映射红白状态灯、独立千兆 WAN/LAN、USB 3.0，完整启用 512MB DDR4。
- **性能**：Linux 6.12 + DSA 架构 + WED 硬件加速 + MTK PPE 硬件流量分载 + Packet Steering 多核分发 + BBR 拥塞控制。
- **透明代理环境**：原生内置 `kmod-dummy`, `kmod-nft-socket`, `kmod-nft-tproxy`, `kmod-tun`, `kmod-inet-diag`, `kmod-netlink-diag` 等全套代理内核模块，预置 [OpenWrt-momo](https://github.com/nikkinikki-org/OpenWrt-momo) 官方源。
- **扩展与终端**：内置 TTYD 网页终端、USB 3.0 (UAS 加速) 及 ext4/vfat/exFAT 自动挂载。

## 硬件规格
| 项 | 规格 |
| :--- | :--- |
| **SoC** | MediaTek MT7981B (双核 Cortex-A53 @ 1.3GHz) |
| **内存 / 闪存** | 512MB DDR4 / 128MB SPI-NAND |
| **网口 / USB** | 1 × GE WAN, 3 × GE LAN (MT7531AE) / 1 × USB 3.0 |
| **无线** | 2.4G (574M) + 5G (2402M @ 160MHz), mt76 开源驱动 |

## 刷写与使用
1. **升级固件**：在 [bl-mt798x-xr30](https://github.com/RSxiaoyu/bl-mt798x-xr30) U-Boot Web 恢复控制台 (`192.168.1.1`) 直接上传 `*sysupgrade.itb` 刷入；或在运行系统中执行 `sysupgrade -n *.itb`。
2. **默认管理**：`192.168.1.1` ｜ 用户名：`root` ｜ 默认无密码。
3. **Momo 安装**：固件已预埋所有内核模块与源公钥，开箱即用。在终端执行一条命令即可安装：
   ```bash
   opkg update && opkg install momo luci-app-momo
   ```
