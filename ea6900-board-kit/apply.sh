#!/bin/sh
# apply.sh <openwrt tree>: apply this kit's patches in order and add its diffconfig to the tree's .config.
# Works from the kit folder (patches/, diffconfig) and from one flat folder with all kits, where this script
# is <n>-<Kit>-kit-apply.sh next to <n>-<Kit>-<m>-*.patch and <n>-<Kit>-kit-diffconfig.
# A patch named *-EA6900.patch is the kit's part for the Linksys EA6900: it is applied only when the tree
# has that board (from the EA6900 board kit, applied first, or from OpenWrt itself once it has it).
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
for p in "$@"; do
	n=$(basename "$p")
	case "$n" in
	*-EA6900.patch)
		if ! grep -qs '^define Device/linksys_ea6900$' target/linux/bcm53xx/image/Makefile; then
			echo "skipping $n: this tree has no Linksys EA6900"
			continue
		fi
		;;
	esac
	echo "applying $n"
	patch -p1 --forward --no-backup-if-mismatch < "$p"
done
touch .config
while IFS= read -r l; do
	grep -qxF "$l" .config || echo "$l" >> .config
done < "$D"
echo "done: now ./scripts/feeds update -a && ./scripts/feeds install -a && make defconfig && make -j\$(nproc)"
