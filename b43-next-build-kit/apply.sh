#!/bin/sh
# apply.sh <openwrt tree>: apply the kit's patches in order and put the kit's diffconfig in place as .config.
# Then: ./scripts/feeds update -a && ./scripts/feeds install -a && make defconfig && make
set -e
T=${1:?usage: apply.sh <openwrt tree>}
K=$(cd "$(dirname "$0")" && pwd)
cd "$T"
for p in "$K"/patches/*.patch; do
	echo "applying $(basename "$p")"
	patch -p1 --forward < "$p"
done
cp "$K/diffconfig" .config
echo "done: now ./scripts/feeds update -a && ./scripts/feeds install -a && make defconfig && make -j\$(nproc)"
