#!/bin/bash
set -e

IB_DIR="$1"
DTB_FILE="$2"

if [ -z "$IB_DIR" ] || [ ! -d "$IB_DIR" ] || [ ! -f "$DTB_FILE" ]; then
    echo "Usage: $0 <ImageBuilder_Directory> <DTB_File>"
    exit 1
fi

cd "$IB_DIR"

# 1. 查找内核构建目录并注入 XR30 专用 DTB 到 RAX3000M 槽位
KDIR=$(find build_dir -type d -name "linux-mediatek_filogic" | head -n 1)
echo "Kernel build directory: $KDIR"

for dtb in "$KDIR"/*rax3000m*nand* "$KDIR"/*rax3000m*.dtb; do
    if [ -f "$dtb" ]; then
        echo "Injecting XR30 DTB into $dtb"
        cp -v "$DTB_FILE" "$dtb"
    fi
done

# 2. 注入 cmcc,xr30 与 cmcc,xr30-nand 到 supported_devices，避免 sysupgrade 校验拦截
TARGET_MK=$(find target/linux/mediatek/image -name "filogic.mk" 2>/dev/null || find . -name "filogic.mk" | head -n 1)
if [ -f "$TARGET_MK" ]; then
    echo "Hooking SUPPORTED_DEVICES in $TARGET_MK..."
    sed -i '/define Device\/cmcc_rax3000m/a \  SUPPORTED_DEVICES += cmcc,xr30 cmcc,xr30-nand' "$TARGET_MK"
fi

# 3. 注入 Momo 官方签名公钥
mkdir -p keys etc/apk/keys
curl -sL https://momomomo.pages.dev/public-key.pem -o keys/momo.pem
curl -sL https://momomomo.pages.dev/public-key.pem -o etc/apk/keys/momo.pem
curl -sL https://momomomo.pages.dev/key-build.pub -o keys/momo.pub

# 4. 将 Momo 官方预编译包直接下载并置入 ImageBuilder 的本地 packages/ 目录
mkdir -p packages
MOMO_URL="https://momomomo.pages.dev/SNAPSHOT/aarch64_cortex-a53/momo"

echo "Fetching Momo official precompiled packages..."
curl -sL "$MOMO_URL/momo-2026.06.03-r1.apk" -o packages/momo-2026.06.03-r1.apk || true
curl -sL "$MOMO_URL/luci-app-momo-1.2.1-r1.apk" -o packages/luci-app-momo-1.2.1-r1.apk || true
curl -sL "$MOMO_URL/luci-i18n-momo-zh-cn-26.167.13849~99aa8d9.apk" -o packages/luci-i18n-momo-zh-cn-26.167.13849~99aa8d9.apk || true

# 5. 下载并以标准 APK 命名置入 SagerNet 官方发布的最新正式版 sing-box v1.14.0
SINGBOX_VER="1.14.0"
echo "Fetching official SagerNet sing-box v${SINGBOX_VER} for aarch64_cortex-a53..."
curl -sL "https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VER}/sing-box_${SINGBOX_VER}_openwrt_aarch64_cortex-a53.apk" -o "packages/sing-box-${SINGBOX_VER}-r0.apk" || true
# 同样备选原始命名以防不同工具链索取
cp -v "packages/sing-box-${SINGBOX_VER}-r0.apk" "packages/sing-box_${SINGBOX_VER}_openwrt_aarch64_cortex-a53.apk" 2>/dev/null || true

ls -lh packages/

echo "XR30 DTB, supported devices, Momo, and Sing-box 1.14.0 staged successfully in ImageBuilder!"
