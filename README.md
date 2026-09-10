# ImmortalWrt for CMCC XR30

[![Build](https://github.com/RSxiaoyu/immortalwrt-xr30/actions/workflows/build.yml/badge.svg)](https://github.com/RSxiaoyu/immortalwrt-xr30/actions/workflows/build.yml)

**中国移动 CMCC XR30**（MT7981B / 512MB DDR4 / 128MB SPI-NAND）专属固件。

设计原则：**上游优先，不 fork、不整编** —— 用官方 ImageBuilder 直接打包固件，本仓库只维护 XR30 必需的设备适配，其余一切跟随上游。

## 上游

| 组件 | 上游 | 本仓库的动作 |
|---|---|---|
| 系统 / 内核 / 软件包 | [ImmortalWrt 官方](https://github.com/immortalwrt/immortalwrt) | 用对应通道的 ImageBuilder 原样打包，零源码 fork |
| 设备适配 | 上游内置 CMCC RAX3000M（NAND） | 官方 DTB 为基底 + [62 行增量 overlay](dts/mt7981b-cmcc-xr30-nand.dtso)，构建时 fdtoverlay 合成 |
| 网络 / 升级脚本 | 上游 `02_network` / `platform.sh` | 构建时从上游实时拉取，仅注入 `cmcc,xr30*` 三处匹配项 |
| 透明代理 | [HomeProxy](https://github.com/immortalwrt/homeproxy)（ImmortalWrt 官方插件，sing-box 内核） | 随固件打包，与系统同源同版本 |
| Bootloader | [bl-mt798x-xr30](https://github.com/RSxiaoyu/bl-mt798x-xr30)（上游 [Yuzhii0718/bl-mt798x-dhcpd](https://github.com/Yuzhii0718/bl-mt798x-dhcpd)） | 独立仓库构建 |

## 构建通道

| 分支 | 上游 | 内核 | 构建方式 |
|---|---|---|---|
| `snapshot`（默认） | master 主干（26.x） | Linux 6.18 | 每周一 04:00（UTC+8）自动 |
| `main` | `openwrt-25.12` 稳定分支 | Linux 6.12 | 按需（push / 手动触发） |

Release tag 按上游版本号编址（如 `snapshot-r40943-1e53c0ae5a`）：同一上游内容的重复构建原地更新既有 Release，不产生重复条目。

## 固件内容

- LuCI（中文）+ Argon 主题 + TTYD 终端
- HomeProxy（sing-box）：订阅即节点源，插件全量生成配置
- USB 3.0 自动挂载（UAS / ext4 / vfat / exFAT）
- 默认启用：MTK PPE 硬件流量分载、Packet Steering、TCP BBR

## 硬件规格

| 项 | 规格 |
|---|---|
| SoC | MediaTek MT7981B（双核 Cortex-A53 @ 1.3GHz） |
| 内存 / 闪存 | 512MB DDR4 / 128MB SPI-NAND |
| 网口 / USB | 1× GE WAN（eth1）+ 3× GE LAN（MT7531AE）/ USB 3.0 |
| 无线 | 2.4G 574M + 5G 2402M @ 160MHz，mt76 开源驱动 |

## 刷写

1. [bl-mt798x-xr30](https://github.com/RSxiaoyu/bl-mt798x-xr30) U-Boot Web 恢复控制台（`192.168.1.1`）直接上传 `*sysupgrade.itb`；或在运行系统中 `sysupgrade -n *.itb`
2. 管理：`192.168.1.1` ｜ `root` ｜ 默认无密码（请自行修改）
