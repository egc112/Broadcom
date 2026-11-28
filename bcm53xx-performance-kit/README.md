# FA kit: the flow accelerator for the Northstar routers (bcm53xx)

For OpenWrt main on the Broadcom Northstar routers (target bcm53xx: BCM4708, BCM4709, BCM47081, BCM47094). It
builds in the hardware flow accelerator (FA) as the hardware path of OpenWrt's flow offloading, as in
[openwrt/openwrt#26789](https://github.com/openwrt/openwrt/pull/26789), on all boards where it can work, with
irqbalance and RPS for the Wi-Fi interfaces. It holds no Wi-Fi driver: for b43-next on the R6400 and the EA6900,
use the [b43-next kit](../b43-next-build-kit/) as well. For the EA6900, apply the
[EA6900 board kit](../ea6900-board-kit/) first.

> **To switch the FA on:** turn on software **and** hardware flow offloading (LuCI, Network > Firewall, Routing/NAT
> Offloading), save, and **reboot**. Turning it off also takes a reboot to take the FA out of the path; until then
> the flows just run in software. Without the reboot the FA is not used, even with both options on: conntrack then
> shows `[OFFLOAD]`, not `[HW_OFFLOAD]`. After a sysupgrade that keeps the settings, the FA is on from the first
> boot. Why a reboot: see [The tag is switched at boot](#how-this-kit-is-made-and-why).

Test version, 2026-11-23. Until 2026-11-22 this kit was called the bcm53xx performance kit
([last version](https://github.com/egc112/Broadcom/tree/499c3ea/bcm53xx-performance-kit)); the directory keeps that
name, so links to it keep working. Changes: #26789 v3
(strrs's bridge-address checks in 703, the WAN MAC from nvram for the RT-N18U, R6400 and EA6900); the EA6900 board
and the EA6900 parts of #26789 moved out (`1-EA6900-1` in the board kit, `3-FA-6-EA6900` here); the old `Perf-2`
(#25131) and `Perf-3` (packet steering) are part of #26789 now. Later on 2026-11-23: strrs's preinit hook switches
the FA's tag on only with hardware flow offloading, so the kit's own 734 is gone, and #26789 no longer names the
tag in any device tree (EA6900: 328 dropped, 329 without its tag line; RT-N18U: 384).

## Before you flash: a risk of bricking

This kit changes how the CPU talks to the switch on 32 boards: port 8 becomes the CPU port and port 5 a second
one. It was tested on three of them: the **R6400 v1**, the **R6400 v2** and the **EA6900**. On every other board
it is only compile-tested. If the switch does not come up on such a board, **all wired ports are dead**, and
OpenWrt's failsafe mode does not help, because failsafe uses the same switch.

The FA's own tag is less of a risk: the switch always boots with the regular tag, and only a normal boot with
hardware flow offloading on switches it (see [below](#flow-accelerator)). Failsafe never does, so if the network
fails only with hardware offloading on, failsafe gets you in to turn it off.

So before you flash an untested board, make sure you have another way in:

- **Working Wi-Fi.** An access point that you have used from a client, with its settings kept on the upgrade
  (the default of `sysupgrade` and of LuCI's "Keep settings"). Wi-Fi does not go through the switch, so you can
  still log in and flash another image. After a fresh install OpenWrt's Wi-Fi is off, so do this before flashing
  the kit, not after.
- **And/or a recovery path that does not need OpenWrt:** a serial console, or the bootloader's own recovery
  (CFE's TFTP or web recovery, Netgear's nmrp, the ASUS rescue mode), which works whatever the image does.

If you combine this kit with the b43-next kit on a board, the wired ports and Wi-Fi both change in one
upgrade: on the three tested routers that is fine, on anything else flash one kit at a time.

**Going back.** A regular OpenWrt image flashed over this kit's, with settings kept, works: tested on the R6400
v1 (2026-11-21). The switch comes back on its old CPU port with the regular tag, the user ports keep their
names (`lan1` to `lan4`, `wan`), so the network configuration fits, and the WAN came up. The RPS script and
irqbalance go with the image. A firewall with hardware offloading still on loads without errors.

If you try the kit on another board, please report what you see, working or not, with the output of
`dmesg | grep -iE "b53|bgmac|flow accelerator"` and `cat /sys/class/net/eth*/dsa/tagging`.

## Contents

| File | What |
|---|---|
| `patches/3-FA-1-flow-accelerator-openwrt-26789.patch` | [openwrt/openwrt#26789](https://github.com/openwrt/openwrt/pull/26789) at e124ccf5d7, without its EA6900 parts: port 8 as the CPU port (376, strrs, formerly #25131), bcm53xx packet steering on the user ports' conduit, Florian Fainelli's 2 Gbit/s fixes 080/081 (Linux v7.4), moving ports between CPU ports (703, Rosen Penev, with strrs's bridge-address checks), the FA driver (our 721-731, strrs's 750-759), strrs's preinit hook that switches the FA's tag on (`/lib/preinit/99_20_flow_accel`), b53 finding the FA by the chip id (762), the RT-N18U (379, 382, 384, strrs) and the R6400 WAN MAC (383) |
| `patches/3-FA-2-flow-accelerator-on-all-boards.patch` | kit only: 377, port 5 back as a second CPU port on 32 boards; without it only the RT-N18U and the EA6900 get the FA |
| `patches/3-FA-3-keep-pppoe-off-the-flow-accelerator.patch` | kit only: 760, connections over PPPoE stay in software |
| `patches/3-FA-4-irqbalance-enable.patch` | switches irqbalance on when it is installed (the package installs disabled) |
| `patches/3-FA-5-wifi-rps-hotplug.patch` | a hotplug script that switches RPS on for the Wi-Fi AP interfaces, see [below](#rps-on-for-the-wi-fi-interfaces) |
| `patches/3-FA-6-EA6900.patch` | #26789's EA6900 parts: 329 (port 5 for the traps), 385 (WAN MAC from nvram); needs the EA6900 board kit, `apply.sh` skips it without the board |
| `diffconfig` | all bcm53xx devices in one multi-profile build; LuCI, irqbalance |
| `irqpin.rc.local` | a fixed IRQ layout for test comparisons only; not built in, copy it by hand to `/etc/rc.local` |
| `apply.sh` | applies the patches to an OpenWrt tree and adds the diffconfig to its `.config` |

## Build

Tested on OpenWrt main 194f70d6fd (2026-11-23).

    git clone https://git.openwrt.org/openwrt/openwrt.git && cd openwrt
    /path/to/nvram-fix-kit/apply.sh .            # always, and first
    /path/to/ea6900-board-kit/apply.sh .         # only for the EA6900
    /path/to/b43-next-build-kit/apply.sh .       # optional: b43-next Wi-Fi
    /path/to/bcm53xx-performance-kit/apply.sh .
    ./scripts/feeds update -a && ./scripts/feeds install -a
    make defconfig && make -j$(nproc)

**By hand instead of `apply.sh`:** `patch -p1 < file` for each patch in name order, after the EA6900 board kit;
without that kit, leave out `3-FA-6-EA6900.patch`. Then add the diffconfig lines to `.config`. With all kits
copied into one folder, every `*.patch` in name order gives the same tree as the three `apply.sh` runs.

The diffconfig builds all bcm53xx devices (`CONFIG_TARGET_ALL_PROFILES`). For a single device, select it in
`make menuconfig` instead (Target Profile: Multiple devices, then the device), keeping "Use a per-device root
filesystem that adds profile packages" on. Images: `bin/targets/bcm53xx/generic/`.

## Flow accelerator

The Northstar SoCs have a flow accelerator between the CPU and switch port 8. Once a connection is set up, the
accelerator forwards it itself (IPv4 routed and with NAT, routed IPv6, also over a VLAN-tagged WAN), and the CPU
stays idle. Switch it on in LuCI, Network > Firewall > General Settings, Routing/NAT Offloading: software **and**
hardware flow offloading (`flow_offloading=1` and `flow_offloading_hw=1` in `/etc/config/firewall`), save, and
**reboot**: the tag can only change while the switch's ports are down, so the boot does it, not the firewall.
Switching it off works at once for the flows (they go back to software), and the next boot takes the
accelerator out of the path. Check after the reboot: `dmesg | grep "flow accelerator tag"` shows "switched ... to
brcm-prepend", and `grep -c HW_OFFLOAD /proc/net/nf_conntrack` counts offloaded connections during traffic.

**Which boards.** 376 makes port 8 the CPU port of 30 boards; 377 adds port 5 back as a second CPU port on 32
boards, all those where port 5 is free (the list is in the patch). The switch boots with the regular tag. With
both offloading options on, strrs's preinit hook switches it to the FA's prepended tag, once, before the network
starts. It needs two CPU ports, and b53 refuses the tag on a switch without the accelerator (switch revision 3 or
later, or a BCM47094, has it); in either case the hook keeps the regular tag and the FA stays out of the path. The
hook logs what it did: `dmesg | grep "flow accelerator tag"`. The tag in use: `cat /sys/class/net/eth2/dsa/tagging`
(`brcm-prepend` with the FA). The user ports stay on port 8; port 5 (eth0) only takes the frames that the FA must
not handle (TTL or hop limit 1, TCP FIN and RST). The RT-N18U and the EA6900 have port 5 in their own device trees
(379, 329).

Not changed: the RT-AC87U and RT-AC88U (port 5 has another use), the Meraki MR26 and MR32 (gmac0 off), the DWL-8610AP
(no switch), and the boards that keep port 5 as their only CPU port (several Luxul and Buffalo boards).

**2 Gbit/s on port 8 (080/081).** Every frame the FA forwards crosses port 8 twice. Florian Fainelli's two fixes,
in Linux v7.4 and backported here, run port 8 at 2 Gbit/s on every Northstar switch, as Broadcom's driver does.
Background: [egc112/Broadcom#6](https://github.com/egc112/Broadcom/issues/6).

**PPPoE (760).** The FA cannot add or remove a PPPoE header: connections over a PPPoE WAN stay in the software
flowtable (both directions), and conntrack shows them as `[OFFLOAD]`, not `[HW_OFFLOAD]`.

**Moving a port to the other CPU port** (`ip link set wan type dsa conduit eth0`): only for tests and tuning,
nothing does it by itself. A bridged port cannot move alone; b53 refuses with `EBUSY` (703, strrs), because the
bridge's address can reach the CPU through one CPU port only. A standalone port such as the WAN can move when it
has a MAC address of its own in the device tree; otherwise it would take its new conduit's address, which is the
LAN's, and that move is refused too. The RT-N18U, R6400 and EA6900 (382-384) and several boards in Linux itself
have that address.

Limits: Wi-Fi traffic is not accelerated (the radios do not sit behind port 8); PPPoE and NAT66 stay in software;
the accelerator counts packets, not bytes, so byte counters of offloaded connections stop growing.

## RPS on for the Wi-Fi interfaces

On these two-core routers a radio's interrupt thread receives the frames and also forwards them (bridge, Ethernet)
on the same CPU; at full 5 GHz speed that CPU is the limit. RPS hands the forwarding to the other CPU. bcm53xx's
`/usr/libexec/platform/packet-steering.sh` replaces the generic script and sets only the conduit and `br-lan`, and
packet steering does not run again when `wifi` creates the AP interfaces. `3-FA-5` adds
`/etc/hotplug.d/net/30-wifi-rps`, which sets RPS per AP interface to the CPU that does not take the radio's
interrupt. Check with `cat /sys/class/net/phy*-ap*/queues/rx-0/rps_cpus`: 1 or 2, not 0. Until
[openwrt/openwrt#26806](https://github.com/openwrt/openwrt/pull/26806) and
[openwrt/openwrt#26655](https://github.com/openwrt/openwrt/pull/26655) are merged, this script does the job.

Measured on the R6400 v2 (5 GHz VHT80, b43-next, MT6000 client, 2026-11-19): upload 365 to 398 Mbit/s, download
319 to 349, and no "RX descriptor underrun".

## How this kit is made, and why

**Three kits.** b43-next (Wi-Fi, on its way into OpenWrt via openwrt/openwrt#26717) and the flow accelerator
(every Northstar router, whatever its Wi-Fi driver) are separate kits since 2026-11-21. Since 2026-11-23 the
EA6900 board support is a third kit: only EA6900 owners need it, and it was in both other kits before. Each kit
keeps the EA6900 lines it changes in a `*-EA6900.patch` of its own, which `apply.sh` skips on a tree without
the board. The numbers in the file names (`1-` board, `2-` b43-next, `3-` FA) give the order in which the kits
must be applied, also when all patches are applied from one folder in name order.

**#26789 as it is.** `3-FA-1` is the PR without changes, apart from leaving out its EA6900 parts (329 and the
EA6900 half of 383, which is `385` here), so that it applies without the EA6900 board. Everything of the kit's
own comes on top, as separate patches.

**Port 8 as the CPU port, port 5 as the trap port.** The accelerator sits between gmac2 and switch port 8, so
traffic has to go through port 8 for it to be used; 376 does that for 30 boards and disables port 5. But the
accelerator must not forward every frame: TTL or hop limit 1 (the router has to answer those) and TCP FIN and RST
(conntrack has to see the end of a connection). b53 redirects those frames to a second CPU port, port 5 (gmac0,
eth0). 377 enables port 5 again, with a fixed link, on every board where it is free. The user ports stay on port
8: b53 prefers port 8 as the default CPU port.

**The tag is switched at boot, not set in the device trees.** The accelerator only works with the prepended
Broadcom tag. A device tree can ask for it with `dsa-tag-protocol = "brcm-prepend"`, as #26789 did at first for
the RT-N18U and the EA6900. But on a switch without the accelerator (Broadcom's driver counts it present from
switch revision 3 on, and on every BCM47094), b53 refuses that tag, and DSA then rejects the whole switch tree:
the router has no network at all, failsafe included. Earlier versions of this kit had b53 pick the tag itself
(734). Since 2026-11-23 strrs's preinit hook in #26789 does it, only when hardware flow offloading is on: it
switches the conduits' tag at runtime, and when b53 refuses or the port 8 conduit does not open, it goes back to
the regular tag. A board without the accelerator just runs on port 8 with the regular tag, the FA is off unless
the user asks for it, and failsafe never switches.

Why this is worth a reboot: with the tag in the device tree, every boot of every user went through the FA,
also with hardware offloading off, and a switch that refused the tag took all wired ports down, failsafe
included. Now a router boots exactly as stock OpenWrt does until the user turns hardware offloading on; if the
switch then refuses the tag, the router keeps its network on the regular tag, and
failsafe always gets you in to turn it off. The price: the tag can only change while the switch's ports are
down, which is during the boot, so switching the FA on takes one reboot.

**2 Gbit/s on port 8 (080/081, Florian Fainelli).** Every frame the accelerator forwards crosses port 8 twice,
so 1 Gbit/s on port 8 is too little for line rate in both directions. Florian's two fixes (Linux v7.4: bgmac keeps
the forced 2.5 Gbit/s speed in adjust_link, b53 forces 2000 with flow control on the CPU port) run port 8 at 2
Gbit/s on every Northstar switch. Download and upload at once through NAT, in Mbit/s:

| | port 8 at 1000 | port 8 at 2000 |
|---|---|---|
| R6400 v2 (BCM47094) | ~610 + ~640 | 930-935 + 946 |
| R6400 v1 (BCM4708) | 618-627 + 642-644 | 937-943 + 946 |
| EA6900 (BCM4708) | 279-292 + 906-907 | 879-907 + 933-937 |

On the R6400 v1 and the EA6900 both columns come from the same image, with only port 8's speed changed by a test
module; the R6400 v2's 1000 column is our earlier measurement with port 8 at 1 Gbit/s. Soaks at 2 Gbit/s, download
and upload at once (28 minutes on the R6400 v2, 30 on the EA6900), showed no link drops and no driver warnings.
One trap for testing: an old Windows 10 PC as a LAN host reset its link under the pause frames at 2 Gbit/s
(upload 0); a laptop on the same port did not.

**PPPoE stays in software (760).** The accelerator cannot add or remove a PPPoE header. Without 760 the driver
took the direction from the WAN (the flowtable describes it as plain IP), whose entry never matched, and conntrack
showed `[HW_OFFLOAD]` for a connection that ran in software. 760 refuses both directions of a PPPoE connection.
Tested with IPv4, IPv6, a port forward and PPPoE on a VLAN (`wan.7`).

**The WAN MAC in the device tree only for the tested boards.** Normal operation does not need it: OpenWrt sets
the WAN address itself (`board.d/02_network`: nvram's `wan_hwaddr`, else the LAN address + 1). It only matters
when the WAN is moved to the other CPU port by hand, and without it b53 refuses that move, which is harmless.
Where the WAN address lives in nvram differs per board, so it is only set for boards we could check.

**RPS for Wi-Fi and irqbalance (3-FA-4, 3-FA-5).** irqbalance installs disabled; `3-FA-4` switches it on, so the
radio and Ethernet interrupts are spread over both CPUs. The Wi-Fi RPS hotplug script stays until
openwrt/openwrt#26806 and openwrt/openwrt#26655 are merged; then it can go.

**The diffconfig.** All devices (`CONFIG_TARGET_ALL_PROFILES`), with a per-device root filesystem, so each image
gets its own device packages; LuCI and irqbalance on top. No Wi-Fi driver of its own: each device keeps OpenWrt's.

**Left out on purpose.** Our private test modules (register dumps, the 2 Gbit/s test modules), the debug patches,
and our parked ARL guard for the conduit move (strrs's checks in 703 remove what triggered it).

## Tested

**These kit files, 2026-11-23**, OpenWrt main 194f70d6fd: the three kits apply alone, together and from one flat
folder in name order, with and without the EA6900 board kit; `make target/linux/refresh` leaves every patch
unchanged. Built with the b43-next and EA6900 board kits for the EA6900, R6400 v1 and v2, and flashed over the
previous kit with the settings kept:

- **The hook**, on all three: on the first boot with both offloading options on, "switched eth0 eth2 to
  brcm-prepend", accelerator in the path, traps to port 5. Hardware offloading off and a reboot: the regular tag
  on both conduits, no hook line, the accelerator not started. On again and a reboot: the prepended tag again.
- **Failsafe** (R6400 v1): the regular tag on both conduits, no accelerator, the network works; the normal boot
  after it switched to the prepended tag again.
- **TCP through the accelerator**, download / upload / both at once, Mbit/s, all `[HW_OFFLOAD]` at 0-10 % CPU:
  R6400 v1 IPv4 940 / 941 / 939 + 938, IPv6 926 / 928 / 926 + 925; EA6900 IPv4 941 / 941 / 939 + 937.
- **Moving ports** (R6400 v1 and EA6900): the same as with v3 below.
- **762, 2026-11-24** (b53 finds the FA by the chip id): the R6400 v2 (chip 53030, switch revision 0), where
  only the chip id finds it now, switched to the prepended tag at boot; TCP 941 / 941 / 939 + 938 Mbit/s through the
  FA at 95-100 % idle CPU. The EA6900 (switch rev 3) and R6400 v1 (rev 5) switched as before, the v1 at 940 / 941 /
  940 + 938. Without 762, a BCM47094 on an image for a BCM4708 board (an RT-AC66U B1 on the RT-AC68U image)
  kept the regular tag.

**R7000, 2026-11-26** (BCM4709, switch BCM53012 rev 5), these kit files with the b43-next kit, OpenWrt main
15df7fcd24: with both offloading options on and a reboot, "switched eth0 eth2 to brcm-prepend", accelerator in the
path, traps to port 5. TCP from a LAN PC through the FA: upload 941 Mbit/s, upload and download at once 938 + 892
(the WAN-side host, an MT6000, retransmitted as the sender, so 892 is its limit), `[HW_OFFLOAD]`, 0 % CPU, no
driver warnings. For comparison on the same router: about 550 Mbit/s each way in software, about 720 with
software offloading only.

The previous files of the same day (with 734 instead of the hook), built from the published kit files on another
build host and flashed on the EA6900: IPv4 939 / 941 / 939 + 938, IPv6 927 / 928 / 926 + 924, a 30-minute soak at
940 + 938 without a driver warning.

**Without hardware offloading**, in software: one direction 480-550 Mbit/s, but with download and upload at
once the download falls to almost nothing while the upload keeps about 500; one CPU is then fully busy with
softirq. The same with and without the hook, with the regular and with the prepended tag. With the accelerator
on this does not happen.

**#26789 v3 changes, 2026-11-23** (R6400 v2 and EA6900): moving a bridged LAN port to eth0 is refused with
`EBUSY`, the bridge's address keeps its static entry on port 8, and the LAN hosts keep reaching the router; the
WAN moves to eth0 and back during a TCP download, keeping its address from the device tree: 940 Mbit/s through the
FA, about 520-530 in software while on eth0, 937-941 after the move back. Nothing refused at boot.

**The previous kit, 2026-11-22** (the same FA code apart from the v3 changes above), built together with the
b43-next kit and flashed over the earlier images with the settings kept:

- **R6400 v2**, **R6400 v1** and **EA6900**: b53 chose the prepended tag by itself (734), accelerator in the path,
  traps to port 5, port 8 at 2 Gbit/s, the user ports on eth2, b43-next up.
- **10 x 50 s download and upload at once** (separate hosts on lan1 and lan4): R6400 v2 938-943 + 935-939,
  R6400 v1 940-943 + 938-939, EA6900 877-898 + 936-937 Mbit/s; all `[HW_OFFLOAD]` at 1-4 % CPU, no driver warnings.
- **PPPoE uplink** (R6400 v2, 760): the flows stay in software offload, `[OFFLOAD]`, with no accelerator entries;
  514 up / 550 down Mbit/s.

2026-11-21, #26789 with strrs's series on all three: TCP and UDP line rate with `[HW_OFFLOAD]`; FIN/RST close
connections in conntrack; the trap conduit down and up; VLAN filtering on and off; a static switch entry for the
next hop; hw-tc-offload off and on; a port leaving and rejoining the bridge; 2 x 128 connections at once; IPv6 at
928 / 928 Mbit/s; soaks of 28 and 30 minutes, then a reboot: no link drops, no driver warnings.

**Not tested:** a board without the accelerator, where b53 refuses the prepended tag and the hook keeps the
regular one. None of our routers is one.

## Sources

| Part | Author | Based on |
|---|---|---|
| `3-FA-1`, `3-FA-6` | Erik Conijn; Semih Baskan (strrs) for 376, 379, 382, 384, 750-759, the preinit hook and the checks in 703; Rosen Penev for 703; Florian Fainelli for 080/081 (Linux v7.4) | register map and table formats from Broadcom's `et` driver (ISC license, router GPL source releases), b53's own register definitions, and measurements on the routers; see [northstar-fa/PROVENANCE.md](../northstar-fa/PROVENANCE.md) |
| `3-FA-2`, `3-FA-3` | Erik Conijn | as above |
| `3-FA-4`, `3-FA-5`, `diffconfig`, `apply.sh`, `irqpin.rc.local` | Erik Conijn | OpenWrt's own scripts and package configuration, measurements on the routers |

The only Broadcom-derived code is the flow accelerator driver (`bgmac-fa.c`, patch 723 and later), which keeps
Broadcom's copyright and ISC permission notice.
