#!/bin/sh
# apply.sh <openwrt tree>: apply this kit's patches in order and add its diffconfig to the tree's .config.
# The checksums of the applied patches go to .kit-applied in the tree: a patch that the other kit applied
# already (the EA6900 board patch is in both) is skipped, so both kits can go into one tree, in either order.
# Then: ./scripts/feeds update -a && ./scripts/feeds install -a && make defconfig && make
set -e
T=${1:?usage: apply.sh <openwrt tree>}
K=$(cd "$(dirname "$0")" && pwd)
cd "$T"
touch .kit-applied
for p in "$K"/patches/*.patch; do
	n=$(basename "$p")
	s=$(sha256sum < "$p" | cut -d" " -f1)
	if grep -q "^$s " .kit-applied; then
		echo "skipping $n: already applied"
		continue
	fi
	echo "applying $n"
	patch -p1 --forward < "$p"
	echo "$s $n" >> .kit-applied
done
touch .config
while IFS= read -r l; do
	grep -qxF "$l" .config || echo "$l" >> .config
done < "$K/diffconfig"
echo "done: now ./scripts/feeds update -a && ./scripts/feeds install -a && make defconfig && make -j\$(nproc)"
