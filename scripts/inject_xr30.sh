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

# 2. 注入 Momo 软件源与公钥到 ImageBuilder (支持在固件打包期直接预装 Momo + Sing-box)
mkdir -p keys etc/apk/keys

cat << 'EOF' > keys/momo.pub
untrusted comment: Nikki
RWSrAXyIqregizvXvG9kJI/JoTkaCCPDy6CQrrVQ4IZ8Qgu+iWMql0UW
EOF

cat << 'EOF' > etc/apk/keys/momo.pem
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAETOwt83tzTFqyvjwimjuuvslR40t6
XnROMwxZsC0iQAr2hHjuXX8qyhf5WaD2Hd897+Gc1/+4W4DMqroNp5w2Dg==
-----END PUBLIC KEY-----
EOF

if [ -f repositories.conf ]; then
    echo "Current repositories.conf:"
    cat repositories.conf
    # 同时兼容 opkg 与 apk 格式的 feed 注入
    if grep -q "src/gz" repositories.conf; then
        echo "src/gz momo https://momomomo.pages.dev/SNAPSHOT/aarch64_cortex-a53/momo" >> repositories.conf
    else
        echo "https://momomomo.pages.dev/SNAPSHOT/aarch64_cortex-a53/momo/packages.adb" >> repositories.conf
    fi
fi

echo "XR30 DTB and Momo feeds successfully configured in ImageBuilder!"
