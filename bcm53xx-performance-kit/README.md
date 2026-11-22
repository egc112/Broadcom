# bcm53xx performance kit: the flow accelerator and the CPU port changes for the Northstar routers

For OpenWrt main on the Broadcom Northstar routers (target bcm53xx: BCM4708, BCM4709, BCM47081, BCM47094). It
builds in the hardware flow accelerator (FA) as the hardware path of OpenWrt's flow offloading, on top of the CPU
port change of [openwrt/openwrt#25131](https://github.com/openwrt/openwrt/pull/25131), with irqbalance and RPS for
the Wi-Fi interfaces. It holds no Wi-Fi driver: for b43-next on the EA6900 and the R6400, use the
[b43-next build kit](../b43-next-build-kit/) as well (see [Both kits](#both-kits-in-one-tree)).

Test version, 2026-11-21. It replaces `Broadcom-4` to `Broadcom-6` of the b43-next build kit of 2026-11-20.

## Before you flash: a risk of bricking

This kit changes how the CPU talks to the switch on 32 boards. It was tested on three of them: the **R6400 v1**,
the **R6400 v2** and the **EA6900**. On every other board it is only compile-tested. If the switch does not come
up on such a board, **all wired ports are dead**, and OpenWrt's failsafe mode does not help, because failsafe
uses the same switch.

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
| `patches/Perf-1-EA6900-board.patch` | EA6900 board support, as submitted in [openwrt/openwrt#26316](https://github.com/openwrt/openwrt/pull/26316); the same file as in the b43-next kit |
| `patches/Perf-2-cpu-port-8-openwrt-25131.patch` | [openwrt/openwrt#25131](https://github.com/openwrt/openwrt/pull/25131) at 1f6840ff, unchanged: port 8 (gmac2) becomes the CPU port on 30 boards, with the board MAC address for gmac2 from nvram |
| `patches/Perf-3-packet-steering-conduit.patch` | bcm53xx's packet steering takes the conduit of the user ports; #25131's version takes the first DSA conduit, which with the FA is the trap port |
| `patches/Perf-4-irqbalance-enable.patch` | switches irqbalance on when it is installed (the package installs disabled) |
| `patches/Perf-5-wifi-rps-hotplug.patch` | a hotplug script that switches RPS on for the Wi-Fi AP interfaces, see [below](#rps-on-for-the-wi-fi-interfaces) |
| `patches/Perf-6-flow-accelerator.patch` | the flow accelerator as in [openwrt/openwrt#26789](https://github.com/openwrt/openwrt/pull/26789): our 721-731, Semih Baskan's (strrs) 750-759 and 379 (RT-N18U), Florian Fainelli's 2 Gbit/s fixes 080/081 (backported from Linux v7.4, with the 703 refresh); plus, kit only: 377 (port 5 back as a second CPU port), 734 (the tag), 760 (PPPoE, formerly 732) |
| `diffconfig` | all bcm53xx devices in one multi-profile build; LuCI, irqbalance |
| `irqpin.rc.local` | a fixed IRQ layout for test comparisons only; not built in, copy it by hand to `/etc/rc.local` |
| `apply.sh` | applies the patches to an OpenWrt tree and adds the diffconfig to its `.config` |

## Build

    git clone https://git.openwrt.org/openwrt/openwrt.git && cd openwrt
    git checkout 6bd48701ef            # optional: the tested commit; newer main should work too
    /path/to/bcm53xx-performance-kit/apply.sh .
    ./scripts/feeds update -a && ./scripts/feeds install -a
    make defconfig && make -j$(nproc)

The diffconfig builds all bcm53xx devices (`CONFIG_TARGET_ALL_PROFILES`). For a single device, select it in
`make menuconfig` instead (Target Profile: Multiple devices, then the device), keeping "Use a per-device root
filesystem that adds profile packages" on. Images: `bin/targets/bcm53xx/generic/`.

## Both kits in one tree

Apply both kits to the same tree, in either order, then build as above:

    /path/to/b43-next-build-kit/apply.sh .
    /path/to/bcm53xx-performance-kit/apply.sh .

`apply.sh` writes the checksums of the patches it applied to `.kit-applied` in the tree and skips a patch that is
there already: the EA6900 board patch is in both kits. The diffconfigs add up: all devices, and the EA6900 and the
R6400 v1 and v2 with b43-next. Both orders give the same tree.

**Use `apply.sh`, not `patch` by hand.** It also works from a flat copy of both kits in one folder, where it is
called `B43-kit-apply.sh` or `Perf-kit-apply.sh` next to the `B43-*`/`Perf-*` patches and the `*-kit-diffconfig`.
Both kits contain the same EA6900 board patch; applied twice by hand, its image hunk goes in a second time with
fuzz, and the second `Device/linksys_ea6900` (without b43-next) wins. Its rejected hunks also leave `.rej` files in
`base-files/etc/board.d/`, which end up in the image. If that happened: `git checkout` the touched files (or start
from a clean tree) and use `apply.sh`.

## Flow accelerator

The Northstar SoCs have a flow accelerator between the CPU and switch port 8. Once a connection is set up, the
accelerator forwards it itself (IPv4 routed and with NAT, routed IPv6, also over a VLAN-tagged WAN), and the CPU
stays idle. Switch it on in LuCI, Network > Firewall > General Settings, Routing/NAT Offloading: software **and**
hardware flow offloading (`flow_offloading=1` and `flow_offloading_hw=1` in `/etc/config/firewall`), then save.
Without hardware offloading the accelerator only passes the traffic on.

**Which boards.** #25131 makes port 8 the CPU port of 30 boards; 377 adds port 5 back as a second CPU port on
32 boards, all those where port 5 is free (the list is in the patch). b53 then chooses the FA's prepended tag (patch 734) when the
switch has the accelerator (switch revision 3 or later, or a BCM47094) and both port 8 and port 5 are CPU ports;
otherwise the regular tag, and the FA stays out of the path. The tag in use: `cat /sys/class/net/eth2/dsa/tagging`
(`brcm-prepend` with the FA). The user ports stay on port 8; port 5 (eth0) only takes the frames that the FA must
not handle (TTL or hop limit 1, TCP FIN and RST). A device tree can opt out with `dsa-tag-protocol = "brcm";` on
port 8.

Not changed: the RT-AC87U and RT-AC88U (port 5 has another use), the Meraki MR26 and MR32 (gmac0 off), the DWL-8610AP
(no switch), and the boards that keep port 5 as their only CPU port (several Luxul and Buffalo boards).

**2 Gbit/s on port 8 (patches 080/081).** Every frame the FA forwards crosses port 8 twice. Florian Fainelli's
two fixes, in Linux v7.4 and backported here, run port 8 at 2 Gbit/s on every Northstar switch, as Broadcom's
driver does. Background: [egc112/Broadcom#6](https://github.com/egc112/Broadcom/issues/6).

**PPPoE (patch 760).** The FA cannot add or remove a PPPoE header: connections over a PPPoE WAN stay in the
software flowtable (both directions), and conntrack shows them as `[OFFLOAD]`, not `[HW_OFFLOAD]`.

Limits: Wi-Fi traffic is not accelerated (the radios do not sit behind port 8); PPPoE and NAT66 stay in software;
the accelerator counts packets, not bytes, so byte counters of offloaded connections stop growing.

## RPS on for the Wi-Fi interfaces

On these two-core routers a radio's interrupt thread receives the frames and also forwards them (bridge, Ethernet)
on the same CPU; at full 5 GHz speed that CPU is the limit. RPS hands the forwarding to the other CPU. bcm53xx's
`/usr/libexec/platform/packet-steering.sh` replaces the generic script and sets only the conduit and `br-lan`, and
packet steering does not run again when `wifi` creates the AP interfaces. `Perf-5` adds
`/etc/hotplug.d/net/30-wifi-rps`, which sets RPS per AP interface to the CPU that does not take the radio's
interrupt. Check with `cat /sys/class/net/phy*-ap*/queues/rx-0/rps_cpus`: 1 or 2, not 0. Until
[openwrt/openwrt#26806](https://github.com/openwrt/openwrt/pull/26806) and
[openwrt/openwrt#26655](https://github.com/openwrt/openwrt/pull/26655) are merged, this script does the job.

Measured on the R6400 v2 (5 GHz VHT80, b43-next, MT6000 client, 2026-11-19): upload 365 to 398 Mbit/s, download
319 to 349, and no "RX descriptor underrun".

## How this kit is made, and why

**Two kits instead of one.** Until 2026-11-20 one kit held b43-next and the flow accelerator together, for three
routers. b43-next is on its way into OpenWrt (openwrt/openwrt#26717); the flow accelerator, the CPU port change
and the RPS and irqbalance settings have nothing to do with the Wi-Fi driver and apply to every Northstar router.
So they are split: the b43-next kit shrinks to #26717 and the device selection, and this kit is for all bcm53xx
boards. Each kit can drop a patch as soon as its upstream PR is merged, without touching the other.

**Upstream PRs as they are.** `Perf-1` (#26316) and `Perf-2` (#25131) are the open OpenWrt PRs without any
change, so the kit tests exactly what is under review there. Everything of ours comes on top, as separate patches:
`Perf-3` changes #25131's packet-steering script, 377 changes the device trees after #25131's 376.

**Port 8 as the CPU port, port 5 as the trap port.** The accelerator sits between gmac2 and switch port 8, so
traffic has to go through port 8 for it to be used; #25131 does that for 30 boards and disables port 5. But the
accelerator must not forward every frame: TTL or hop limit 1 (the router has to answer those) and TCP FIN and RST
(conntrack has to see the end of a connection). b53 redirects those frames to a second CPU port, port 5 (gmac0,
eth0). 377 enables port 5 again, with a fixed link, on every board where it is free. The user ports stay on port
8: b53 prefers port 8 as the default CPU port.

**The tag is chosen in b53 (734), not in the device trees.** The accelerator only works with the prepended
Broadcom tag. A device tree could ask for it with `dsa-tag-protocol = "brcm-prepend"`, as the EA6900 and R6400 v2
patches of the earlier kit did (328 to 330). But on a switch without the accelerator (Broadcom's driver counts it
present from switch revision 3 on, and on every BCM47094), b53 refuses that tag, and DSA then rejects the whole
switch tree: the router has no network at all.
We cannot test 32 boards, so a per-board setting would be a risk on each untested one. 734 makes b53 pick the tag
itself: the prepended one when the switch has the accelerator (switch revision 3 or later, or a BCM47094, as in
Broadcom's `FA_CAPABLE()`) and ports 8 and 5 are both CPU ports, else the regular tag, as before. A board without
the accelerator just runs on port 8 with the regular tag. 328, 329 and 330 are therefore gone: #25131 now moves
the R6400 V1 file (which the V2 includes) to port 8, with gmac2's MAC address; 377 and 734 do the rest.

**2 Gbit/s on port 8 (080/081, Florian Fainelli).** Every frame the accelerator forwards crosses port 8 twice,
so 1 Gbit/s on port 8 is too little for line rate in both directions. Florian's two fixes (Linux v7.4: bgmac keeps
the forced 2.5 Gbit/s speed in adjust_link, b53 forces 2000 with flow control on the CPU port) run port 8 at 2
Gbit/s on every Northstar switch. They replace our earlier 733, which set only the switch bit, and only on the
BCM47094: bgmac fell back to 1 Gbit/s in adjust_link, which is why we had measured no gain on the BCM4708.
Download and upload at once through NAT, in Mbit/s:

| | port 8 at 1000 | port 8 at 2000 |
|---|---|---|
| R6400 v2 (BCM47094) | ~610 + ~640 | 930-935 + 946 |
| R6400 v1 (BCM4708) | 618-627 + 642-644 | 937-943 + 946 |
| EA6900 (BCM4708) | 279-292 + 906-907 | 879-907 + 933-937 |

On the R6400 v1 and the EA6900 both columns come from the same image, with only port 8's speed changed by a test
module; the R6400 v2's 1000 column is our earlier measurement with port 8 at 1 Gbit/s. Soaks at 2 Gbit/s, download
and upload at once (28 minutes on the R6400 v2, 30 on the EA6900), showed no link drops and no driver warnings. One trap for testing: an old Windows 10 PC as a LAN host reset
its link under the pause frames at 2 Gbit/s (upload 0); a laptop on the same port did not.

**PPPoE stays in software (760).** The accelerator cannot add or remove a PPPoE header. Without 760 the driver
took the direction from the WAN (the flowtable describes it as plain IP), whose entry never matched, and conntrack
showed `[HW_OFFLOAD]` for a connection that ran in software. 760 refuses both directions of a PPPoE connection.
It was 732 in the earlier kit; it now comes after strrs's 750-759, so that his patches apply exactly as he wrote them.
Tested with IPv4, IPv6, a port forward and PPPoE on a VLAN (`wan.7`).

**The packet-steering conduit (Perf-3).** #25131's script takes the first interface with a `dsa` directory as the
conduit. With port 5 back that is eth0, the trap port, and RPS would be set on the wrong interface. `Perf-3` takes
the conduit that most interfaces are linked to (the user ports' one, eth2). `irqpin.rc.local` uses the same rule.

**RPS for Wi-Fi and irqbalance (Perf-4, Perf-5).** irqbalance installs disabled; `Perf-4` switches it on, so the
radio and Ethernet interrupts are spread over both CPUs. The Wi-Fi RPS hotplug script stays until
openwrt/openwrt#26806 (bcm53xx's packet steering hands Wi-Fi to the generic script) and openwrt/openwrt#26655
(packet steering runs again for new Wi-Fi interfaces) are merged; then it can go.

**apply.sh and the shared board patch.** Both kits need the EA6900 board patch: the b43-next kit changes its
device packages, this kit its device tree. So both kits contain the same file, and `apply.sh` skips it when the
other kit has applied it already. It recognises it by its SHA-256 checksum, stored in `.kit-applied`. A test with
`patch -R --dry-run` does not work: the b43-next kit changes a line that the board patch adds, so the reverse
test fails, and `patch` then applied the EA6900 image definition a second time (with fuzz) instead of stopping.

**The diffconfig.** All devices (`CONFIG_TARGET_ALL_PROFILES`), with a per-device root filesystem, so each image
gets its own device packages; LuCI and irqbalance on top. No Wi-Fi driver of its own: each device keeps OpenWrt's.

**Left out on purpose.** Our private test modules (register dumps, the 2 Gbit/s test modules), the debug patches,
and our 733 (replaced by Florian's 080/081).

## Tested

**This kit, 2026-11-22**, built together with the b43-next kit and flashed over the earlier images with the
settings kept:

- **R6400 v2**, **R6400 v1** and **EA6900**: b53 chose the prepended tag by itself (734), accelerator in the path,
  traps to port 5, port 8 at 2 Gbit/s, the user ports on eth2 (`Perf-3`), b43-next up.
- **10 x 50 s download and upload at once** (separate hosts on lan1 and lan4): R6400 v2 938-943 + 935-939,
  R6400 v1 940-943 + 938-939, EA6900 877-898 + 936-937 Mbit/s; all `[HW_OFFLOAD]` at 1-4 % CPU, no driver warnings.
- **PPPoE uplink** (R6400 v2, 760): the flows stay in software offload, `[OFFLOAD]`, with no accelerator entries;
  514 up / 550 down Mbit/s.

2026-11-21, the patches of #26789 with strrs's series (721-731, 750-759, 379, 080/081, #25131 and Perf-3, without
377, 734 and 760), on OpenWrt main 6bd48701ef:

- **R6400 v2** (BCM47094), **R6400 v1** (BCM4708) and **EA6900** (BCM4708): accelerator in the path, traps to port 5,
  port 8 at 2 Gbit/s; TCP and UDP line rate with `[HW_OFFLOAD]`; FIN/RST close connections in conntrack; the trap
  conduit down and up; VLAN filtering on and off; a static switch entry for the next hop; hw-tc-offload off and on;
  a port leaving and rejoining the bridge; 2 x 128 connections at once; IPv6 at 928 / 928 Mbit/s.
- **Soaks:** download and upload at once, 28 minutes on the R6400 v2 (938-942 + 913-935 Mbit/s) and 30 on the
  EA6900 (887-907 + 933-937), then a reboot: no link drops, no driver warnings.
- **Known:** moving a user port to the other conduit and back can leave a flow at ~10 Mbit/s for a while on the
  R6400 v1 and v2 (not on the EA6900; with this kit 6 times out of 6 on the R6400 v2, 0 out of 6 on the EA6900).
  It happens only when the conduit is changed by hand, a reboot clears it, and our earlier driver did the same: a
  bug of ours, to be fixed.
- **Not tested:** a board without the accelerator, where b53 has to fall back to the regular tag. None of our
  routers is one.

## Sources

| Part | Author | Based on |
|---|---|---|
| `Perf-1` | Erik Conijn | board support as submitted to OpenWrt, openwrt/openwrt#26316 |
| `Perf-2` | Semih Baskan (strrs) | his openwrt/openwrt#25131, unchanged |
| `Perf-3`, `Perf-4`, `Perf-5`, `diffconfig`, `apply.sh`, `irqpin.rc.local` | Erik Conijn | OpenWrt's own scripts and package configuration, measurements on the routers |
| `Perf-6` | Erik Conijn; Semih Baskan (strrs) for 750-759 and 379; Florian Fainelli for 080/081 (Linux v7.4) | register map and table formats from Broadcom's `et` driver (ISC license, router GPL source releases), b53's own register definitions, and measurements on the routers; see [northstar-fa/PROVENANCE.md](../northstar-fa/PROVENANCE.md) |

The only Broadcom-derived code is the flow accelerator driver (`bgmac-fa.c`, patch 723 and later), which keeps
Broadcom's copyright and ISC permission notice.
