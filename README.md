# Broadcom BCM4708/BCM4709 (bcm53xx) — patches and files

Patches and files for Broadcom BCM53xx ARM routers running OpenWrt, e.g. the Netgear R6400 and the Linksys EA6900.

| Folder | What |
|---|---|
| [b43-80211n](b43-80211n/) | **b43: 802.11n with A-MPDU for the BCM4331 2.4 GHz radio** (Netgear R6400 v1/v2): test version rc15 (up to four SSIDs), patches on top of Rosen Penev's openwrt/openwrt#25922 + build instructions (the older stand-alone rc8 is kept there too); [provenance and legal notes](b43-80211n/PROVENANCE.md). Test images: see [Releases](../../releases). |
| [linksys-ea6900](linksys-ea6900/) | **OpenWrt for the Linksys EA6900 v1** (with the Asus-style XVortex CFE): install from DD-WRT, recovery, patches for an own build. Test version; build with the [EA6900 board kit](ea6900-board-kit/) plus the [b43-next kit](b43-next-build-kit/). |
| | **Four build kits** for OpenWrt main, test versions of 2026-11-23 to 2026-11-28. Apply them in the order of their numbers; kit 0 belongs in every build, the others work without each other (the EA6900 needs the board kit). |
| [nvram-fix-kit](nvram-fix-kit/) | **0: the `nvram commit` fix** (openwrt/openwrt#26981), for every bcm53xx build: without it about one `nvram commit` in four leaves the router without Ethernet after the next boot, see the warning below. |
| [ea6900-board-kit](ea6900-board-kit/) | **1: the Linksys EA6900 v1 board** (openwrt/openwrt#26316). Only for EA6900 owners. |
| [b43-next-build-kit](b43-next-build-kit/) | **2: b43-next as the Wi-Fi driver** for the R6400 v1/v2 and the EA6900 ([b43-next](https://github.com/aleferri/b43-next), BCM4331 + BCM4360): openwrt/openwrt#26717 + the device selection; replaces the EA6900 build kit and the b43-80211n patch series. |
| [bcm53xx-performance-kit](bcm53xx-performance-kit/) | **3: the FA kit, the hardware flow accelerator for all bcm53xx (Northstar) boards**: openwrt/openwrt#26789 (CPU port 8, the FA driver, 2 Gbit/s on port 8) + port 5 and the tag for all boards + PPPoE kept in software + irqbalance and RPS for Wi-Fi. Tested on the EA6900 and the R6400 v1/v2; **read its bricking warning first**. To use the FA: both flow offloading options on, then **reboot**. |
| [new-device-support.md](new-device-support.md) | **How to get a Broadcom Northstar router supported in OpenWrt**: the board (DTS on CPU port 8), Wi-Fi with b43-next and the flow accelerator (port 5), with the Linksys EA6900 as the worked example |
| [northstar-fa](northstar-fa/) | **Research: the hardware flow accelerator (FA)** in BCM4708/BCM4709/BCM47094 routers under OpenWrt: what it is, how to check whether your router has one, measurements (941 Mbit/s NAT at 0 % CPU on the EA6900). To try it: the [FA kit](bcm53xx-performance-kit/). |

What it adds up to: [measured best-case figures for the R6400 v2](r6400-v2-showcase.md), wired and Wi-Fi, from 802.11g at about 10 Mbit/s to 941 Mbit/s at 1 % CPU.

## Warning: `nvram commit` can leave the router without Ethernet

OpenWrt's `nvram` tool (`package/utils/nvram`, current main) sometimes writes an NVRAM partition that the kernel
rejects at the next boot. The kernel's NVRAM driver then fails (`brcm_nvram ... probe ... failed with error -22`
in `dmesg`), the switch waits for it forever (`deferred probe pending`), and the router comes up **without any
Ethernet port, WAN and LAN alike**. Wi-Fi still works, if it is set up.

It happens when the NVRAM data ends exactly on a 4-byte boundary, so roughly one `nvram commit` in four, depending
on what was set or unset: the tool then gives the data a length that includes 4 bytes it left at `0xff` instead of
zeroing them. Seen on our R7000 on 2026-11-27 (OpenWrt main 15df7fcd24); any bcm53xx router that takes its MAC
addresses from NVRAM can be hit.

The tool has written this length since 2009; kernels before Linux 6.18.61, 6.12.117 and 6.6.163 simply accepted it.
Those stable kernels check it more strictly (Linux a67e2c323a47, a correct fix of an out-of-bounds read). So a
router whose NVRAM already has the bad layout from an earlier commit can lose Ethernet right after a sysupgrade to
such a kernel, without any new commit. And not only manual commits count: OpenWrt's `nvram-bcm53xx.init` commits on
every boot on the Linksys EA9200 and Panamera and the ASUS RT-AC3100, RT-AC5300, RT-AC88U and RT-AC3200 (and on the
EA6900 with the board kit). **Check the partition before you upgrade** to a newer image, with the commands below.

The fix for the tool is [openwrt/openwrt#26981](https://github.com/openwrt/openwrt/pull/26981); for an own build,
apply the [nvram fix kit](nvram-fix-kit/) first.

**Before you reboot after an `nvram commit`, and before a sysupgrade**, check the partition (busybox, on the router
itself):

```sh
mtd=/dev/$(grep '"nvram"' /proc/mtd | cut -d: -f1)
len=$(hexdump -s 4 -n 4 -e '1/4 "%u"' $mtd)
hexdump -s $((len - 4)) -n 4 -e '4/1 "%02x" "\n"' $mtd
```

Any output other than `ffffffff` is fine: `00000000`, or a byte of the last entry followed by `000000`.

`ffffffff` means the bad layout: do **not** reboot. Add a harmless entry of 9 bytes, which moves the end off the
4-byte boundary, commit once more and check again:

```sh
nvram set fixpad=1     # if fixpad is already set: nvram unset fixpad
nvram commit
```

**Already rebooted and no Ethernet?** Connect over Wi-Fi (the router's own SSID, then `ssh root@192.168.1.1`), add
the entry and commit as above, check, then reboot. Do not try to re-bind the NVRAM driver at runtime: on our R7000
that broke NAND access until a power cycle.

Questions and test reports: please open an issue.
