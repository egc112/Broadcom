# nvram fix kit (kit 0): `nvram commit` no longer leaves the router without Ethernet

For **every** bcm53xx (Northstar) build of OpenWrt main, with or without the other kits. It is
[openwrt/openwrt#26981](https://github.com/openwrt/openwrt/pull/26981) as it is: OpenWrt's `nvram` tool sometimes
writes a length that the kernel rejects at the next boot, and the router then comes up without any Ethernet port.
See the [warning in the main README](../README.md#warning-nvram-commit-can-leave-the-router-without-ethernet) for the
details, the check and the repair. Remove this kit once #26981 is in OpenWrt main.

Test version, 2026-11-28. Tested on the Netgear R7000 (the patched tool on the router's real flash, plus 17 alignment
cases and nearly full partitions, see the PR).

## Contents

| File | What |
|---|---|
| `patches/0-NVRAM-1-nvram-commit-padding-openwrt-26981.patch` | `package/utils/nvram`: pad the committed data with NULs, so the length ends at the data; `PKG_RELEASE` 15 to 16 |
| `diffconfig` | empty: the `nvram` package is already selected on bcm53xx |
| `apply.sh` | applies the patch to an OpenWrt tree |

## Build

**Apply this kit first**, before all the others. The EA6900 board kit changes the same `PKG_RELEASE` line (16 to
17) and needs this kit before it.

    git clone https://git.openwrt.org/openwrt/openwrt.git && cd openwrt
    /path/to/nvram-fix-kit/apply.sh .            # always, and first
    /path/to/ea6900-board-kit/apply.sh .         # only for the EA6900
    /path/to/b43-next-build-kit/apply.sh .       # optional: b43-next Wi-Fi
    /path/to/bcm53xx-performance-kit/apply.sh .  # optional: the flow accelerator
    ./scripts/feeds update -a && ./scripts/feeds install -a
    make defconfig && make -j$(nproc)

Tested on OpenWrt main 10658eef27 (2026-11-28): all four kits apply in that order without rejects.

A router you flash with such an image gets the fixed tool. It does not repair an NVRAM partition that already has the
bad layout: check it with the commands in the main README before the first reboot on the new image.
