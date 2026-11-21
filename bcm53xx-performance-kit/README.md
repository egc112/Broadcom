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
| `patches/Perf-6-flow-accelerator.patch` | 15 kernel patches: 377 (port 5 back as a second CPU port), 721-731 ([openwrt/openwrt#26789](https://github.com/openwrt/openwrt/pull/26789)), 732 (PPPoE), 733 (port 8 at 2 Gbit/s on the BCM47094), 734 (the tag) |
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

**2 Gbit/s on port 8 (BCM47094 only, patch 733).** Every frame the FA forwards crosses port 8 twice. On the
BCM47094 the kit runs port 8 at 2 Gbit/s, as Broadcom's driver does; on the BCM4708 the FA does not keep up at 2
Gbit/s, so it stays at 1. Background: [egc112/Broadcom#6](https://github.com/egc112/Broadcom/issues/6).

**PPPoE (patch 732).** The FA cannot add or remove a PPPoE header: connections over a PPPoE WAN stay in the
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

**2 Gbit/s on port 8 only on the BCM47094 (733).** Every frame the accelerator forwards crosses port 8 twice, so
1 Gbit/s on port 8 is too little for line rate in both directions. Two iperf3 pairs at once, one down, one up:

| | port 8 at 1000 | port 8 at 2000 |
|---|---|---|
| R6400 v2 (BCM47094) | ~610 + ~640 Mbit/s | 928 + 945 Mbit/s |
| EA6900 (BCM4708) | ~245 + 941 Mbit/s | ~240 + 945 Mbit/s |

On the BCM4708 the accelerator does not keep up at 2 Gbit/s: it pauses the switch about 16 times as often and
the throughput does not improve, so that chip stays at 1. 733 sets only the switch's port 8 speed bit (b53's
`PORT_OVERRIDE_SPEED_2000M`, Broadcom's `GMII_SPEED_UP_2G`). The GMAC's own speed field is not used: bgmac already
runs these chips on the 250 MHz clock, and offloaded frames turn around in the accelerator without passing the
GMAC; it changed nothing in our tests. It may have been needed for other switch types, but not here. A 15-minute
soak at 2 Gbit/s on the R6400 v2 showed no errors and no drops on port 8.

**PPPoE stays in software (732).** The accelerator cannot add or remove a PPPoE header. Without 732 the driver
took the direction from the WAN (the flowtable describes it as plain IP), whose entry never matched, and conntrack
showed `[HW_OFFLOAD]` for a connection that ran in software. 732 refuses both directions of a PPPoE connection.
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

**Left out on purpose.** Our private test modules (register dumps, the 2 Gbit/s test module), the debug patches,
and the GMAC speed field.

## Tested

2026-11-21, OpenWrt main 6bd48701ef.

- **Builds:** this kit alone (all bcm53xx devices), both kits together (both orders give the same tree), and the
  b43-next kit alone. All 47 Northstar device trees compile.
- **R6400 v2** (BCM47094), image with both kits: b53 chose the prepended tag by itself (734), the accelerator is in
  the path, the traps go to port 5, port 8 runs at 2 Gbit/s (733). Two iperf3 pairs at once through NAT, one down,
  one up: 928 + 944 Mbit/s, three rounds alike. One download alone: 941 Mbit/s, `[HW_OFFLOAD]`, CPU 100 % idle. A
  port forward over PPPoE: 487 / 510 Mbit/s in software, no accelerator entries (732). RPS set on the Wi-Fi
  interfaces, irqbalance running, no driver warnings.
- **EA6900** (BCM4708), both kits: prepended tag, accelerator in the path, traps to port 5; port 8 stays at 1
  Gbit/s, as 733 intends for the BCM4708. No driver warnings.
- **R6400 v1** (BCM4708), both kits: the same as the EA6900. The v1 has the accelerator too; it was just never in
  the path, since the v1 ran on port 5. No throughput run on it. Then a build without this kit flashed over it,
  with settings kept: see "Going back" above.
- **Not tested:** a board without the accelerator, where b53 has to fall back to the regular tag. None of our
  routers is one.

## Sources

| Part | Author | Based on |
|---|---|---|
| `Perf-1` | Erik Conijn | board support as submitted to OpenWrt, openwrt/openwrt#26316 |
| `Perf-2` | Semih Baskan (strrs) | his openwrt/openwrt#25131, unchanged |
| `Perf-3`, `Perf-4`, `Perf-5`, `diffconfig`, `apply.sh`, `irqpin.rc.local` | Erik Conijn | OpenWrt's own scripts and package configuration, measurements on the routers |
| `Perf-6` | Erik Conijn | register map and table formats from Broadcom's `et` driver (ISC license, router GPL source releases), b53's own register definitions, and measurements on the routers; see [northstar-fa/PROVENANCE.md](../northstar-fa/PROVENANCE.md) |

The only Broadcom-derived code is the flow accelerator driver (`bgmac-fa.c`, patch 723 and later), which keeps
Broadcom's copyright and ISC permission notice.
