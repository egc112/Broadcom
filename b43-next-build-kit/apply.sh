#!/bin/sh
# apply.sh <openwrt tree>: apply this kit's patches in order and add its diffconfig to the tree's .config.
# The checksums of the applied patches go to .kit-applied in the tree: a patch that the other kit applied
# already (the EA6900 board patch is in both) is skipped, so both kits can go into one tree, in either order.
# It works from the kit folder (patches/, diffconfig) and from a flat copy of both kits in one folder, where
# this script is <Kit>-kit-apply.sh next to <Kit>-<n>-*.patch and <Kit>-kit-diffconfig (Kit = B43 or Perf).
# Then: ./scripts/feeds update -a && ./scripts/feeds install -a && make defconfig && make
set -e
T=${1:?usage: apply.sh <openwrt tree>}
K=$(cd "$(dirname "$0")" && pwd)
S=$(basename "$0")
case "$S" in
*-kit-apply.sh)
	P=${S%-kit-apply.sh}
	set -- "$K/$P"-[0-9]*.patch
	D="$K/$P-kit-diffconfig"
	;;
*)
	set -- "$K"/patches/*.patch
	D="$K/diffconfig"
	;;
esac
[ -e "$1" ] || { echo "no patches found next to $S" >&2; exit 1; }
[ -f "$D" ] || { echo "no diffconfig found: $D" >&2; exit 1; }
cd "$T"
touch .kit-applied
for p in "$@"; do
	n=$(basename "$p")
	s=$(sha256sum < "$p" | cut -d" " -f1)
	if grep -q "^$s " .kit-applied; then
		echo "skipping $n: already applied"
		continue
	fi
	echo "applying $n"
	patch -p1 --forward --no-backup-if-mismatch < "$p"
	echo "$s $n" >> .kit-applied
done
touch .config
while IFS= read -r l; do
	grep -qxF "$l" .config || echo "$l" >> .config
done < "$D"
echo "done: now ./scripts/feeds update -a && ./scripts/feeds install -a && make defconfig && make -j\$(nproc)"
