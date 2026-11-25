# Broadcom BCM4708/BCM4709 (bcm53xx) — patches and files

Patches and files for Broadcom BCM53xx ARM routers running OpenWrt, e.g. the Netgear R6400 and the Linksys EA6900.

| Folder | What |
|---|---|
| [b43-80211n](b43-80211n/) | **b43: 802.11n with A-MPDU for the BCM4331 2.4 GHz radio** (Netgear R6400 v1/v2): test version rc15 (up to four SSIDs), patches on top of Rosen Penev's openwrt/openwrt#25922 + build instructions (the older stand-alone rc8 is kept there too); [provenance and legal notes](b43-80211n/PROVENANCE.md). Test images: see [Releases](../../releases). |
| [linksys-ea6900](linksys-ea6900/) | **OpenWrt for the Linksys EA6900 v1** (with the Asus-style XVortex CFE): install from DD-WRT, recovery, patches for an own build. Test version; build with the [EA6900 board kit](ea6900-board-kit/) plus the [b43-next kit](b43-next-build-kit/). |
| | **Three build kits** for OpenWrt main, test versions of 2026-11-23. Apply them in the order of their numbers; each works without the others (the EA6900 needs the board kit first). |
| [ea6900-board-kit](ea6900-board-kit/) | **1: the Linksys EA6900 v1 board** (openwrt/openwrt#26316). Only for EA6900 owners. |
| [b43-next-build-kit](b43-next-build-kit/) | **2: b43-next as the Wi-Fi driver** for the R6400 v1/v2 and the EA6900 ([b43-next](https://github.com/aleferri/b43-next), BCM4331 + BCM4360): openwrt/openwrt#26717 + the device selection; replaces the EA6900 build kit and the b43-80211n patch series. |
| [bcm53xx-performance-kit](bcm53xx-performance-kit/) | **3: the FA kit, the hardware flow accelerator for all bcm53xx (Northstar) boards**: openwrt/openwrt#26789 (CPU port 8, the FA driver, 2 Gbit/s on port 8) + port 5 and the tag for all boards + PPPoE kept in software + irqbalance and RPS for Wi-Fi. Tested on the EA6900 and the R6400 v1/v2; **read its bricking warning first**. To use the FA: both flow offloading options on, then **reboot**. |
| [new-device-support.md](new-device-support.md) | **How to get a Broadcom Northstar router supported in OpenWrt**: the board (DTS on CPU port 8), Wi-Fi with b43-next and the flow accelerator (port 5), with the Linksys EA6900 as the worked example |
| [northstar-fa](northstar-fa/) | **Research: the hardware flow accelerator (FA)** in BCM4708/BCM4709/BCM47094 routers under OpenWrt: what it is, how to check whether your router has one, measurements (941 Mbit/s NAT at 0 % CPU on the EA6900). To try it: the [FA kit](bcm53xx-performance-kit/). |

What it adds up to: [measured best-case figures for the R6400 v2](r6400-v2-showcase.md), wired and Wi-Fi, from 802.11g at about 10 Mbit/s to 941 Mbit/s at 1 % CPU.

Questions and test reports: please open an issue.
