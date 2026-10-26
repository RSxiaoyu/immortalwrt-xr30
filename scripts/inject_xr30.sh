#!/bin/bash
set -e

IB_DIR="$1"
DTSO_FILE="$2"

if [ -z "$IB_DIR" ] || [ ! -d "$IB_DIR" ] || [ ! -f "$DTSO_FILE" ]; then
    echo "Usage: $0 <ImageBuilder_Directory> <XR30_DTSO>"
    exit 1
fi

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$IB_DIR"

# 1. XR30 DTB = 上游 RAX3000M base DTB + 上游 NAND overlay + XR30 增量 overlay (fdtoverlay 链式应用)
#    ImageBuilder 不带 DTS 源码,直接复用上游已编译 DTB/DTBO,只维护增量。
#    生成后将满树写回 base/nand/me 三个槽位 (与既往已验证启动行为一致)。
KDIR=$(find build_dir -type d -name "linux-mediatek_filogic" | head -n 1)
if [ -z "$KDIR" ]; then
    echo "Error: Kernel build directory not found!"
    exit 1
fi
BASE_DTB=$(find "$KDIR" -name "image-*rax3000m.dtb" | head -n 1)
NAND_DTBO=$(find "$KDIR" -name "image-*rax3000m-nand.dtbo" | head -n 1)
if [ -z "$BASE_DTB" ] || [ -z "$NAND_DTBO" ]; then
    echo "Error: upstream RAX3000M base DTB / NAND DTBO not found in $KDIR!"
    exit 1
fi
echo "Base DTB: $BASE_DTB"
echo "NAND DTBO: $NAND_DTBO"

dtc -@ -I dts -O dtb -o /tmp/xr30.dtbo "$DTSO_FILE"
fdtoverlay -i "$BASE_DTB" -o /tmp/xr30-nand.dtb "$NAND_DTBO" /tmp/xr30.dtbo

HOOKED_COUNT=0
for dtb in "$KDIR"/*rax3000m*nand* "$KDIR"/*rax3000m*.dtb; do
    if [ -f "$dtb" ]; then
        echo "Injecting XR30 DTB into $dtb"
        cp /tmp/xr30-nand.dtb "$dtb"
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

# 3. 02_network / platform.sh 构建时从上游 master 实时拉取并注入 XR30 匹配项,
#    避免 vendored 整份拷贝随上游漂移。本 snapshot 分支与 master 同源。
FILIC_BASE="https://raw.githubusercontent.com/immortalwrt/immortalwrt/master/target/linux/mediatek/filogic/base-files"
mkdir -p "$REPO_DIR/files/etc/board.d" "$REPO_DIR/files/lib/upgrade"
curl -sLf --retry 3 "$FILIC_BASE/etc/board.d/02_network" -o "$REPO_DIR/files/etc/board.d/02_network"
curl -sLf --retry 3 "$FILIC_BASE/lib/upgrade/platform.sh" -o "$REPO_DIR/files/lib/upgrade/platform.sh"
for f in "$REPO_DIR/files/etc/board.d/02_network" "$REPO_DIR/files/lib/upgrade/platform.sh"; do
    awk '{print} /cmcc,rax3000m\|\\/{print "\tcmcc,xr30*|\\"}' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    chmod +x "$f"
done
# 自检: 02_network 1 处 + platform.sh 3 处
XR30_HOOKS=$(grep -c 'cmcc,xr30' "$REPO_DIR/files/etc/board.d/02_network" "$REPO_DIR/files/lib/upgrade/platform.sh" | awk -F: '{s+=$2} END{print s}')
if [ "$XR30_HOOKS" -ne 4 ]; then
    echo "Error: expected 4 XR30 hooks (1x 02_network, 3x platform.sh), got $XR30_HOOKS"
    exit 1
fi
echo "Injected $XR30_HOOKS XR30 hooks into generated board scripts."

# 4. 把 Nikki 签名公钥喂给 ImageBuilder 与本地固件 (校验本地 nikki apk 包)
mkdir -p etc/apk/keys "$REPO_DIR/files/etc/apk/keys"
curl -sLf --retry 3 "https://nikkinikki.pages.dev/public-key.pem" -o etc/apk/keys/nikki.pem
cp etc/apk/keys/nikki.pem "$REPO_DIR/files/etc/apk/keys/nikki.pem"

# 5. 自动查询并拉取 Nikki 官方最新全套组件（完全免维护动态追踪）
mkdir -p packages
NIKKI_URL="https://nikkinikki.pages.dev/openwrt-25.12/aarch64_cortex-a53/nikki"
NIKKI_JSON=$(curl -sLf --retry 3 "$NIKKI_URL/index.json" || true)

NIKKI_VER=$(echo "$NIKKI_JSON" | jq -r '.packages["nikki"] // empty')
LUCI_NIKKI_VER=$(echo "$NIKKI_JSON" | jq -r '.packages["luci-app-nikki"] // empty')
LUCI_ZH_VER=$(echo "$NIKKI_JSON" | jq -r '.packages["luci-i18n-nikki-zh-cn"] // empty')
MIHOMO_VER=$(echo "$NIKKI_JSON" | jq -r '.packages["mihomo-meta"] // empty')

echo "Discovered upstream Nikki versions: nikki=$NIKKI_VER, luci-app-nikki=$LUCI_NIKKI_VER, zh=$LUCI_ZH_VER, mihomo=$MIHOMO_VER"

if [ -n "$NIKKI_VER" ]; then
    curl -sLf --retry 3 "$NIKKI_URL/nikki-${NIKKI_VER}.apk" -o "packages/nikki-${NIKKI_VER}.apk"
fi
if [ -n "$LUCI_NIKKI_VER" ]; then
    curl -sLf --retry 3 "$NIKKI_URL/luci-app-nikki-${LUCI_NIKKI_VER}.apk" -o "packages/luci-app-nikki-${LUCI_NIKKI_VER}.apk"
fi
if [ -n "$LUCI_ZH_VER" ]; then
    curl -sLf --retry 3 "$NIKKI_URL/luci-i18n-nikki-zh-cn-${LUCI_ZH_VER}.apk" -o "packages/luci-i18n-nikki-zh-cn-${LUCI_ZH_VER}.apk"
fi
if [ -n "$MIHOMO_VER" ]; then
    curl -sLf --retry 3 "$NIKKI_URL/mihomo-meta-${MIHOMO_VER}.apk" -o "packages/mihomo-meta-${MIHOMO_VER}.apk"
fi

ls -lh packages/

echo "XR30 DTB overlay, supported devices, and latest upstream packages staged successfully in ImageBuilder!"
