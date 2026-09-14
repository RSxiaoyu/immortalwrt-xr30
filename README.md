# ImmortalWrt for CMCC XR30

[![Build](https://github.com/RSxiaoyu/immortalwrt-xr30/actions/workflows/build.yml/badge.svg)](https://github.com/RSxiaoyu/immortalwrt-xr30/actions/workflows/build.yml)

**中国移动 CMCC XR30** 专属纯净固件。

遵循 **Ponytail** 极简原则：官方 ImageBuilder 直出，零源码 fork、零整编开销，仅维护 62 行增量设备树，其余 100% 同步官方上游。

## 架构

| 组件 | 上游 | 适配实现 |
|---|---|---|
| 系统 / 内核 | [ImmortalWrt 官方](https://github.com/immortalwrt/immortalwrt) | 官方 ImageBuilder 直出，享受官方预编译生态 |
| 设备树 | 上游 RAX3000M (NAND) | 基底 DTB + [62 行增量 overlay](dts/mt7981b-cmcc-xr30-nand.dtso)，构建期 `fdtoverlay` 链式合成 |
| 网络 / 升级 | 上游 `02_network` / `platform.sh` | 构建期实时拉取，仅注入 `cmcc,xr30*` 四处必要匹配 (1 处网络 + 3 处升级) |
| 透明代理 | [OpenWrt-momo](https://github.com/nikkinikki-org/OpenWrt-momo) + [sing-box](https://github.com/SagerNet/sing-box) | 内置 GfS 风格 `mixin.json` 规则注入与旧版订阅语法自动迁移，Zashboard 仪表盘 |
| 引导链 | [bl-mt798x-xr30](https://github.com/RSxiaoyu/bl-mt798x-xr30) | ubootmod 架构，移除 NMBM，原生 MTD/UBI 直通 (卷空间 122.5MB) |

## 通道

| 分支 | 状态 | 上游基础 | 内核 | 构建策略 |
|---|---|---|---|---|
| `snapshot` (默认) | 前沿主线 | master 主干 (26.x) | Linux 6.18 | 每周一 04:00 (CST) 自动巡检 |
| `25.12` | 稳定正式 | openwrt-25.12 | Linux 6.12 | 按需 / 手动触发 |

Release tag 采用内容寻址（`25.12-r<rev>` / `snapshot-r<rev>`），上游无新内容时不重复发版。

## 特性与硬件

- **硬件**: MediaTek MT7981B (双核 A53 @ 1.3GHz) / 512MB DDR4 / 128MB SPI-NAND
- **网口**: 1× GE WAN (eth1) + 3× GE LAN (MT7531AE 直通) / 1× USB 3.0 (UAS + ext4/vfat/exFAT 自动挂载)
- **无线**: 2.4G 574M + 5G 2402M @ 160MHz (mt76 开源驱动)
- **加速**: MTK PPE 硬件流控 (HNAT) + Packet Steering 多核分发 + TCP BBR
- **界面**: LuCI (简体中文) + Argon 主题 + TTYD 网页终端

## 刷写

1. 在 [bl-mt798x-xr30](https://github.com/RSxiaoyu/bl-mt798x-xr30) Web 恢复控制台 (`192.168.1.1`) 上传 `*sysupgrade.itb` 刷入；或在运行系统中执行 `sysupgrade -n *.itb`
2. 后台：`192.168.1.1` ｜ 用户名：`root` ｜ 默认无密码
