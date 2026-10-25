# ImmortalWrt for CMCC XR30

[![Build](https://github.com/RSxiaoyu/immortalwrt-xr30/actions/workflows/build.yml/badge.svg)](https://github.com/RSxiaoyu/immortalwrt-xr30/actions/workflows/build.yml)

基于CMCC RAX3000M的ImageBuilder修改设备树实现快速编译原生ImmortalWrt固件。

修改 [OpenWrt-momo](https://github.com/nikkinikki-org/OpenWrt-momo) 实现 `mixin.json` 订阅覆写、聚合。

## 软件包
Argon 主题、TTYD 终端、momo (Sing-box)

## 分支
- `snapshot` 自动触发
- `25.12` 手动触发

## 相关项目
1. DHCP U-boot [bl-mt798x-xr30](https://github.com/RSxiaoyu/bl-mt798x-xr30) 
2. [过时] 闭源版 [immortalwrt-xr30-mtk](https://github.com/RSxiaoyu/immortalwrt-xr30-mtk)

## 开发原则
```
- 追求极致前沿、高性能、现代化、简洁、优雅，技术洁癖。
- 倾向社区已有高认可度、高性能项目，尽量避免生成代码/配置。如需生成，尽量参考社区高认可度项目。
- 尽可能少写代码/配置，尽量依赖默认/原生/缺省行为。
```

