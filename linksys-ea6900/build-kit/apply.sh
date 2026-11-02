#!/bin/sh
# apply.sh <openwrt tree>: puts this EA6900 build kit into a plain OpenWrt tree
# (tested on main r37507-4e16c2ed8f). See README.md for what each part is and where it comes from.
set -e
K=$(cd "$(dirname "$0")" && pwd)
T=${1:?usage: apply.sh <openwrt tree>}
cd "$T"
[ -f scripts/feeds ] || { echo "$T is not an OpenWrt tree"; exit 1; }
KP=target/linux/bcm53xx/patches-6.18
[ -d "$KP" ] || { echo "no $KP: this kit needs kernel 6.18 on bcm53xx"; exit 1; }
for p in "$K/patches/board/EA6900.patch" "$K/patches/board/broadcom.mk.diff"; do
	patch -p1 -N --dry-run -s < "$p" >/dev/null || { echo "does not apply: $p (already applied?)"; exit 1; }
done
patch -p1 -N -s < "$K/patches/board/EA6900.patch"
patch -p1 -N -s < "$K/patches/board/broadcom.mk.diff"
cp "$K"/patches/kernel/*.patch "$KP/"
cp "$K"/patches/mac80211/*.patch package/kernel/mac80211/patches/brcm/
# Install the overlay with fixed modes: copying would carry the source's directory modes into the image
# (a 0770 /etc locks the non-root services out and the router does not finish booting).
(cd "$K/files" && find . -type d) | while read -r d; do install -d -m 0755 "files/$d"; done
(cd "$K/files" && find . -type f) | while read -r f; do
	case "$f" in ./etc/rc.local|./etc/uci-defaults/*) m=0755 ;; *) m=0644 ;; esac
	install -m "$m" "$K/files/$f" "files/$f"
done
echo "done: board patch, broadcom.mk, kernel 880, $(ls "$K"/patches/mac80211/*.patch | wc -l) b43 patches, files/ (irqbalance, rc.local)"
echo "next: ./scripts/feeds update -a && ./scripts/feeds install -a, cp $K/diffconfig .config, make defconfig, make"
