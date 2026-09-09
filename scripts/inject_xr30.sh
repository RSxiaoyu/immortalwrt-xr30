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
if [ -z "$KDIR" ] || [ ! -d "$KDIR" ]; then
    echo "Error: Kernel build directory not found!"
    exit 1
fi
echo "Kernel build directory: $KDIR"

HOOKED_COUNT=0
for dtb in "$KDIR"/*rax3000m*nand* "$KDIR"/*rax3000m*.dtb; do
    if [ -f "$dtb" ]; then
        echo "Injecting XR30 DTB into $dtb"
        cp -v "$DTB_FILE" "$dtb"
        HOOKED_COUNT=$((HOOKED_COUNT + 1))
    fi
done

if [ "$HOOKED_COUNT" -eq 0 ]; then
    echo "Error: No RAX3000M DTB slots found to hook in $KDIR!"
    exit 1
fi

# 2. 注入 cmcc,xr30 与 cmcc,xr30-nand 到 supported_devices，避免 sysupgrade 校验拦截
for mk in $(find target/linux/mediatek/image -name "*.mk" 2>/dev/null || find . -name "*.mk"); do
    if grep -q "define Device/cmcc_rax3000m" "$mk"; then
        echo "Hooking SUPPORTED_DEVICES in $mk..."
        sed -i '/define Device\/cmcc_rax3000m/a \  SUPPORTED_DEVICES += cmcc,xr30 cmcc,xr30-nand' "$mk"
    fi
done

# 3. 补丁 ImageBuilder 内部所有可能的 platform.sh 与 02_network
for f in $(find . -name "02_network" -o -name "platform.sh"); do
    if grep -q "cmcc,rax3000m" "$f" && ! grep -q "cmcc,xr30" "$f"; then
        echo "Pre-patching runtime file $f..."
        sed -i 's/cmcc,rax3000m\\|/cmcc,rax3000m\\|cmcc,xr30*\\|/g' "$f"
    fi
done

# 4. 注入 Momo 官方签名公钥
mkdir -p keys etc/apk/keys
curl -sL https://momomomo.pages.dev/public-key.pem -o keys/momo.pem
curl -sL https://momomomo.pages.dev/public-key.pem -o etc/apk/keys/momo.pem
curl -sL https://momomomo.pages.dev/key-build.pub -o keys/momo.pub

# 5. 自动查询并拉取 Momo 官方最新版本（完全免维护动态追踪）
mkdir -p packages
MOMO_URL="https://momomomo.pages.dev/SNAPSHOT/aarch64_cortex-a53/momo"
MOMO_JSON=$(curl -sL "$MOMO_URL/index.json")

MOMO_VER=$(echo "$MOMO_JSON" | jq -r '.packages["momo"] // empty')
LUCI_MOMO_VER=$(echo "$MOMO_JSON" | jq -r '.packages["luci-app-momo"] // empty')
LUCI_ZH_VER=$(echo "$MOMO_JSON" | jq -r '.packages["luci-i18n-momo-zh-cn"] // empty')

echo "Discovered upstream Momo versions: momo=$MOMO_VER, luci-app-momo=$LUCI_MOMO_VER, zh=$LUCI_ZH_VER"

if [ -n "$MOMO_VER" ]; then
    curl -sL "$MOMO_URL/momo-${MOMO_VER}.apk" -o "packages/momo-${MOMO_VER}.apk"
fi
if [ -n "$LUCI_MOMO_VER" ]; then
    curl -sL "$MOMO_URL/luci-app-momo-${LUCI_MOMO_VER}.apk" -o "packages/luci-app-momo-${LUCI_MOMO_VER}.apk"
fi
if [ -n "$LUCI_ZH_VER" ]; then
    curl -sL "$MOMO_URL/luci-i18n-momo-zh-cn-${LUCI_ZH_VER}.apk" -o "packages/luci-i18n-momo-zh-cn-${LUCI_ZH_VER}.apk"
fi

# 6. 自动查询并拉取 SagerNet 官方最新正式版 sing-box（带鉴权容错，完全免维护）
AUTH_HEADER=()
if [ -n "$GITHUB_TOKEN" ]; then
    AUTH_HEADER=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi

SINGBOX_TAG=$(gh release view --repo SagerNet/sing-box --json tagName --jq '.tagName' 2>/dev/null || true)
if [ -z "$SINGBOX_TAG" ]; then
    SINGBOX_TAG=$(curl -sL "${AUTH_HEADER[@]}" https://api.github.com/repos/SagerNet/sing-box/releases/latest | jq -r '.tag_name // "v1.14.0"')
fi
SINGBOX_VER="${SINGBOX_TAG#v}"
echo "Discovered upstream Sing-box latest release: v${SINGBOX_VER}"

SINGBOX_APK_URL="https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VER}/sing-box_${SINGBOX_VER}_openwrt_aarch64_cortex-a53.apk"
echo "Fetching: $SINGBOX_APK_URL"
curl -sL "$SINGBOX_APK_URL" -o "packages/sing-box-${SINGBOX_VER}-r0.apk" || true

ls -lh packages/

echo "XR30 DTB, supported devices, and latest upstream packages staged successfully in ImageBuilder!"
