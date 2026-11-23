# EA6900 board kit: Linksys EA6900 v1 support for OpenWrt main

Only for owners of a **Linksys EA6900 v1**. It adds the board to OpenWrt main (bcm53xx), as submitted in
[openwrt/openwrt#26316](https://github.com/openwrt/openwrt/pull/26316). The other two kits, the
[b43-next kit](../b43-next-build-kit/) (Wi-Fi) and the [FA kit](../bcm53xx-performance-kit/) (flow accelerator), work without it; each of
them has a small EA6900 part of its own (`*-EA6900.patch`) that is applied only when the tree has this board.

Test version, 2026-11-23. Until 2026-11-22 this patch was in both other kits (`B43-1` and `Perf-1`).

## Contents

| File | What |
|---|---|
| `patches/1-EA6900-1-board.patch` | EA6900 board support: device tree (327), image definition, board.d LEDs and network, the nvram partial-boots fix; openwrt/openwrt#26316 as it is |
| `diffconfig` | the EA6900 in a multi-profile build, with a per-device root filesystem |
| `apply.sh` | applies the patch to an OpenWrt tree and adds the diffconfig to its `.config` |

## Build

**Apply this kit first**, before the other kits: their EA6900 parts change lines that this patch adds.

    git clone https://git.openwrt.org/openwrt/openwrt.git && cd openwrt
    /path/to/ea6900-board-kit/apply.sh .
    /path/to/b43-next-build-kit/apply.sh .       # optional: b43-next Wi-Fi
    /path/to/bcm53xx-performance-kit/apply.sh .  # optional: the flow accelerator
    ./scripts/feeds update -a && ./scripts/feeds install -a
    make defconfig && make -j$(nproc)

The numbers in the file names give the order: `1-` (this kit), `2-` (b43-next), `3-` (FA). With all kits copied
into one folder, applying every `*.patch` with `patch -p1` in name order gives the same tree.

Image: `bin/targets/bcm53xx/generic/*linksys_ea6900-squashfs.trx`. Install it as described in
[linksys-ea6900](../linksys-ea6900/). Without the b43-next kit the EA6900 gets OpenWrt's default Wi-Fi packages,
and its BCM4360 radios then have no driver.

When openwrt#26316 is merged into OpenWrt, this kit is no longer needed; the EA6900 parts of the other kits stay
and then apply on OpenWrt's own board support.

## Sources

| Part | Author | Based on |
|---|---|---|
| `1-EA6900-1` | Erik Conijn | board support as submitted to OpenWrt and reviewed there, openwrt/openwrt#26316; the board's own nvram and stock firmware layout |
| `diffconfig`, `apply.sh` | Erik Conijn | OpenWrt's own configuration |
