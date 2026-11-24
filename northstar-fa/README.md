# Northstar FA: hardware NAT offloading on Broadcom BCM4708/BCM4709 routers — RESEARCH

> **Status: research; to try it, use the [FA kit](../bcm53xx-performance-kit/)** (test version,
> 2026-11-23, for all bcm53xx boards; read its bricking warning first). Under OpenWrt the flow accelerator ("FA")
> in these routers works. It routes and NATs at full gigabit speed with the router's CPU idle. This page explains
> what the FA is, how to check whether your router has one, and what we measured. The features are done (IPv4,
> IPv6, VLAN WAN), and the OpenWrt driver is submitted as [openwrt/openwrt#26789](https://github.com/openwrt/openwrt/pull/26789)
> (2026-11-18, IPv6 and VLAN added 2026-11-20, under review; see *The pull request*).
> Tested on the Linksys EA6900 v1 and the Netgear R6400 v2; the R6400 v1 boots with it, the FA in the path
> (2026-11-21, no throughput run yet). Not in OpenWrt or the Linux kernel yet.
> Based on Broadcom's public, ISC-licensed driver source and our own measurements only: see
> [PROVENANCE.md](PROVENANCE.md).

## What is it?

The Broadcom "Northstar" routers (BCM4708, BCM4709 and BCM47094 SoCs) have a small hardware block between the
CPU and the built-in switch: the **Flow Accelerator** (FA). Once a connection is running, the FA can forward its
packets itself: it rewrites the addresses and ports for NAT, lowers the TTL, fixes the checksums and hands the
packet back to the switch. The CPU never sees those packets.

Stock firmware and DD-WRT use it (Broadcom calls it CTF/FA). OpenWrt has never used it, so on OpenWrt all
routing and NAT is done by the CPU, and a dual-core 800 MHz–1.4 GHz ARM cannot do that at gigabit speed.

## What can be offloaded?

| Traffic | Offloaded? |
|---|---|
| IPv4 TCP and UDP, LAN → internet (NAT / masquerade) | **yes** |
| IPv4 port forwards (DNAT), internet → LAN | **yes** |
| IPv4 routing without NAT | **yes** (found in this research; Broadcom's driver never used it) |
| Wired ports only (LAN ports and WAN port of the built-in switch) | yes |
| Wi-Fi clients | no: the radios are not behind the switch, so their traffic stays in the software flowtable. What helps instead is packet steering (RPS) for the Wi-Fi interfaces; see *Wi-Fi* |
| IPv6 TCP and UDP, routed (as home IPv6 is) | **yes**, also over a VLAN-tagged WAN (found in this research; Broadcom's driver never used it) |
| IPv6 with NAT (NAT66, IPv6 port forwards) | no, by choice: these stay in software. Home IPv6 is routed, so this is rare. The IPv6 entry does have a 128-bit NAT address and a NAT port field (found while mapping the IPv6 layout), but Broadcom's driver never used them and they are untested; the driver refuses such connections |
| WAN with a VLAN tag (some ISPs) | **yes** (802.1Q tag on the WAN port; tested with VLAN 10) |
| PPPoE | no: the FA has no field for it |
| Byte counters | no: the FA counts packets only, so traffic statistics per connection are too low |

Everything that is not offloaded simply stays in the normal software path: nothing breaks, it is only slower.

## Does my router have it?

Every BCM47094 (chip id **53030**) has it. A BCM4708/BCM4709 (chip id **53010** or **53018**) has it when its
built-in **switch revision is 3 or higher**. Earlier chip steppings (switch rev 0–2) do not have it. This is
the rule in Broadcom's own driver (`FA_CAPABLE()` in `etc_fa.c`, see *Sources*).

On OpenWrt, run this on the router:

```
dmesg | grep -E "found switch|Found chip with id"
```

Two lines matter. On a Linksys EA6900 v1:

```
b53-srab-switch 18007000.ethernet-switch: found switch: BCM53011, rev 3
bcma-host-soc 18000000.axi: bus0: Found chip with id 53010, rev 0x00 and package 0x02
```

(chip id 53010 and switch rev 3, so it has the FA.) On a Netgear R6400 v2:

```
b53-srab-switch 18007000.ethernet-switch: found switch: BCM53011, rev 0
bcma-host-soc 18000000.axi: bus0: Found chip with id 53030, rev 0x00 and package 0x02
```

(chip id 53030 = BCM47094, so it has the FA even though the switch revision is 0.)

- `Found chip with id 53030` → **yes**.
- `Found chip with id 53010` or `53018` **and** `found switch: ..., rev 3` or higher → **yes**.
- Switch rev 0, 1 or 2 → **no**.

Use the `rev` of the **switch** line. The `rev` in the "Found chip" line is the SoC revision and does not count.
After a long uptime the boot lines may be gone from `dmesg`; reboot and run it again.

A one-line version that prints the verdict:

```
c=$(dmesg | sed -n 's/.*Found chip with id \([0-9]*\).*/\1/p' | head -1); r=$(dmesg | sed -n 's/.*found switch: .*, rev \([0-9]*\).*/\1/p' | head -1); echo "chip ${c:-?}, switch rev ${r:-?}"; if [ -z "$c" ] || [ -z "$r" ]; then echo "FA: unknown (boot lines gone from dmesg: reboot and run again)"; elif [ "$c" = 53030 ]; then echo "FA: yes"; elif [ "$c" = 53010 -o "$c" = 53018 ] && [ "$r" -ge 3 ]; then echo "FA: yes"; else echo "FA: no"; fi
```

| Router (tested) | chip id | switch rev | FA |
|---|---|---|---|
| Linksys EA6900 v1 | 53010 | 3 | yes |
| Netgear R6400 v1 | 53010 | 5 | yes |
| Netgear R6400 v2 | 53030 | 0 | yes (BCM47094) |

## What does it give?

Linksys EA6900 v1, OpenWrt snapshot (kernel 6.18), one wired PC on a LAN port, iperf3 TCP to a server on the WAN
side, upload and download (Mbit/s):

| | upload | download | router CPU |
|---|---|---|---|
| no offloading | 293 | 336 | one core full |
| software offloading¹ | 621 | 738 | one core full |
| **hardware offloading with the FA** | **941** | **941** | **0 %** |
| same with 128 connections at once | 937 | | 0 % |
| port forward (DNAT), internet → LAN / LAN → internet | 949 | 926 | 0 % |
| routing without NAT | 943 | | 0 % |
| WAN with a VLAN tag (VLAN 10) | 938 | 935 | 1–2 % |
| **IPv6** (routed) | **928** | **928** | **2 %** |
| IPv6 over the VLAN-tagged WAN | 924 | 919 | 5 % |

941 Mbit/s is the most a gigabit link can carry with TCP (IPv6: 928, its header is 20 bytes longer; a VLAN tag
costs a few more), so the FA is not the limit. DD-WRT with Broadcom's
own driver reaches the same (950/949) on these routers.

Upload and download at full speed **at the same time** give about 1130 Mbit/s in total, not 2 × 941: every
routed packet crosses the link between the switch and the CPU/FA (switch port 8, 1 Gbit/s) twice, once in and
once out, so that link carries both directions together. The same limit applies without the FA.

¹ fw4's "software flow offloading" with firewall4 3722eadc08 or newer, in OpenWrt main since 2026-11-12
(dab12e7663). Older snapshots have a firewall4 bug that makes software offloading *slower* (213/245) on these
routers; see the note in the
[EA6900 build kit README](https://github.com/egc112/Broadcom/blob/d07f0a7/linksys-ea6900/build-kit/README.md) (*Known limitations*; that kit is replaced by [b43-next-build-kit](../b43-next-build-kit/), which is based on a main with the fix).

### Slower than expected? Check GSO and GRO first

GSO and GRO (segmentation and receive offload in the kernel) on the switch ports make a large difference for
everything the CPU forwards: no offloading, software offloading, and whatever the FA does not take. Which setting
is fastest is not always the same (sometimes on, sometimes off), so with an unexpectedly slow result, check them
before anything else and try both:

```sh
ethtool -k wan | grep -E '^generic-(segmentation|receive)-offload'   # "off [requested on]" = switched off by the kernel
for p in wan lan1 lan2 lan3 lan4; do ethtool -K $p gso on gro on; done   # or: gso off gro off
```

Measured 2026-11-14 on the EA6900 (no offloading): after a run-time change of the switch tagging, the kernel had
switched GSO and GRO off on `wan` and `lan1` ("off [requested on]"), and the router did 275/336 Mbit/s instead of
366/433. Switching them back on restored 366/433. After a normal boot they were on.

### Boot message "bcma0:6 … failed with error -524": harmless

Every Northstar router on stock OpenWrt (with or without the FA work) shows at boot:

```
bgmac_bcma bcma0:6: Unsupported core_unit 3
bgmac_bcma bcma0:6: probe with driver bgmac_bcma failed with error -524
```

The SoC has four Ethernet MAC cores (GMAC0-3), and the bus driver offers all four to the Ethernet driver
(`bgmac_bcma`). GMAC3 is not wired to a switch port: it is the core whose register space holds the FA. The driver
looks for a MAC address for it (device tree, then the `et0macaddr`-`et2macaddr` NVRAM entries, which exist for
GMAC0-2 only), finds none and gives up with `ENOTSUPP`, a kernel-internal error number (524) that has no name in
user space. Nothing is lost: there is no port behind GMAC3, and the FA driver uses its registers without binding
to it. Measured on the EA6900: the same message with and without the FA patches.

## Status

Working in the prototype, measured on the EA6900:

- nftables flowtable hardware offload (`flow_offloading_hw` in OpenWrt's firewall). Since 2026-11-23 the FA is
  put in the path at boot, so after turning it on: **reboot** (see *The pull request*).
- Both directions of a connection always together, so no half-offloaded connections.
- A full table (1024 entries) is handled cleanly: new connections stay in software, then move to the FA by
  themselves once space frees up; nothing is left behind afterwards.
- Closed connections (TCP FIN/RST) are noticed, as Broadcom does it: a switch rule copies them to the CPU, so
  connection tracking does not keep them around for two hours.
- No flooding of offloaded packets to other ports.
- TTL is decremented on offloaded packets.
- WAN with a VLAN tag (802.1Q, as some ISPs need): both directions offloaded. The switch's VLAN table needs the
  FA's output port as a member, which the module adds while a connection uses it and removes afterwards.
- Packets with TTL (IPv6: hop limit) 0 or 1 never reach the FA: a switch rule hands them to the CPU, so the
  router answers with "time exceeded" as it should (traceroute and mtr show the router), instead of the FA
  dropping them silently (IPv4) or passing them on with hop limit 0 (IPv6). On by default; see *Settings*.
- 2-hour soak test with full load in both directions, port forwards and DNS churn at the same time: no errors,
  69,070 hardware entries added and all removed again, connection tracking back to normal afterwards, CPU mostly
  0–8 %. The same load without the FA (software offloading): one core full, ping loss 8.3 % instead of
  0.8 %, average ping 10.7 ms instead of 1.2 ms, DNS timeouts 3.4 % instead of 0.14 %.
- The same 2-hour soak over a VLAN-tagged WAN: equally clean (68,588 entries added and removed, CPU 0–9 %,
  ping loss 0.66 %).
- **IPv6** (routed TCP and UDP): an IPv6 connection takes two table slots per direction; the module places
  them so that IPv4 entries block as few IPv6 places as possible. Tested with a full table of IPv4 and IPv6
  mixed: every entry forwards in hardware (each one's hit counter checked).
- A **firewall reload** (any `fw4 reload`, or switching offloading off) clears the module's entries. Before this
  was fixed, already offloaded connections kept running in hardware outside the new firewall rules (see test 11).
- 2-hour soak with IPv4 and IPv6 over the VLAN-tagged WAN: 185 rounds of full-speed traffic in both
  directions, TTL / hop-limit-1 checks from the LAN and the WAN side (also inside offloaded connections), a
  firewall reload every 10th round and DNS churn: no failure, 54,460 entries added and all removed again,
  memory stable.
- Pulling the WAN cable: after a short outage new connections go straight back to the FA; after a long one the
  switch-over script falls back to the normal (software) path, and the network keeps working.

### The OpenWrt driver (in progress, 2026-11-14)

The prototype is being rewritten as proper kernel patches for OpenWrt's bcm53xx target (Linux 6.18): the FA
code in the Ethernet driver (bgmac), the switch rules in the switch driver (b53). No module and no switch-over
script any more: it is active from boot when the board's device tree asks for the FA tag. Measured on the
EA6900 with test images:

| Part | State | Result |
|---|---|---|
| FA set-up, following the tagger | tested | switches cleanly between the two tag formats |
| IPv4 TCP/UDP offload (routing, NAT, port forwards) | tested | 941 / 941 Mbit/s, router 95–99 % idle; 30 firewall reloads clean |
| TTL 0/1 handed to the CPU ("time exceeded" works) | tested | 4 of 5 answered (ICMP rate limit); without the rule: none |
| TCP FIN/RST handed to the CPU | tested | hardware entry gone within 1 s, instead of after ~30 s |
| LAN-to-LAN traffic with the rules on | tested | TTL-1 pings and TCP closes between two LAN ports work |
| IPv6 TCP/UDP offload (routed) | tested | 928 / 928 Mbit/s (software path: 629), router 95–100 % idle |
| VLAN-tagged WAN (802.1Q, e.g. `wan.10`) | tested | IPv4 939 / 935, IPv6 925 / 920 Mbit/s, router 99–100 % idle; traps also catch TTL-1 frames arriving tagged from the WAN |
| Byte counters | decided: packets only | the FA counts packets per entry, not bytes; offloaded connections show correct packet counts but too few bytes (as with offloading on other routers) |
| Table race (2026-11-20) | tested | the race Florian Fainelli's upstream series guards against (a lookup during a table write copying a key into another slot): 64 verified UDP flows plus a stream of new flows at line rate, IPv4 and IPv6, EA6900 and R6400 v2: no packet misrouted or wrongly NATed |
| Soak tests, no VLAN | tested | 4 hours (374 rounds) + 2 hours (170 rounds) of IPv4, IPv6 and mixed traffic at full speed, TTL / hop-limit-1 checks from LAN and WAN (also inside offloaded connections), a firewall reload every 10th round, DNS churn: 0 kernel warnings, the table empty afterwards |

How the rules reach the CPU: the switch redirects those frames to its port 5, which is wired to a second
Ethernet interface of the SoC (eth0) and does not pass the FA. The driver brings eth0 up by itself. If eth0 is
down, IPv4 offload continues without the rules, and IPv6 connections leave the hardware within a second and
continue in software (the FA would otherwise forward hop limit 1 as 0).

The patches are in [patches/](patches/) (328, 329, 721–731, and 330 for the R6400 v2). The first soak found that the driver slept while
waiting for each table access, under the lock that every flow addition takes: with about 250 flows the load
average rose to 15 while the CPU was idle. 724 now busy-waits for those few microseconds, as Broadcom's own
driver does; the second soak ran with that fix.

The R6400 v2 (BCM47094) runs it too since 2026-11-19, with patch 330 for its device tree: CPU port 8 as
openwrt/openwrt#25131 sets it for the R6400 V1 file (here only in the V2 file), the MAC address of gmac2 from
nvram, and ports 5 and 8 as on the EA6900. First boot worked unchanged: IPv4 941/941 and IPv6 928/928 Mbit/s at
98 % idle, and the TTL, FIN and RST traps behave as on the EA6900.

Still to do: the device trees of the other routers (they need openwrt/openwrt#25131 first). IPv6 is done in
the new driver as well (TCP and UDP, firewall reloads, soaks, the table-race test below). Later, to research: PPPoE, NAT66, and port 8 at 2 Gbit/s (would lift the ~1130 Mbit/s
both-ways limit). A hybrid mode for Wi-Fi, in which the FA does the lookup and the NAT and the CPU forwards the
packet (an idea from the
[forum thread](https://forum.openwrt.org/t/northstar-bcm4708-4709-fa-hardware-offload-how-should-tcp-fin-rst-reach-the-flowtable/255472)),
was researched and is not worth building: see *Wi-Fi*. The patches build on two OpenWrt patches by Rosen Penev
(a second CPU port for b53, openwrt/openwrt#26005), already in OpenWrt.

### The pull request (2026-11-18)

[openwrt/openwrt#26789](https://github.com/openwrt/openwrt/pull/26789) adds the driver (patches 721-731: IPv4, and
since 2026-11-20 also IPv6 and the VLAN-tagged WAN) and the EA6900 device tree changes 328/329. It needs
openwrt/openwrt#25131 (port 8 as the CPU port) and openwrt/openwrt#26316 (EA6900 support) merged first.

Upstream: Florian Fainelli (Broadcom) posted a Linux driver for the FA to netdev on 2026-11-16
([net-next 0/9](https://patchwork.kernel.org/project/netdevbpf/list/?series=1213213)), for now IPv4 NAT between
standalone ports on the BCM4708/53011/53012. That is where the FA belongs in the long run: once it is in the
kernel and in OpenWrt, OpenWrt can switch to it and #26789 can go. Until then #26789 covers the usual OpenWrt
setup (a LAN bridge, IPv6, a VLAN WAN, the BCM47094).

**Switching it on (since 2026-11-23).** The FA needs the switch's prepended tag. strrs's preinit hook in #26789
sets it at boot, before the network starts, and only when both flow offloading options are on: so turn them on,
save, and **reboot**. Without the reboot the flows run in software. The reason for the boot-time switch: a router
then boots exactly as stock OpenWrt until the user asks for the FA, a switch that refuses the tag (no FA) keeps
the regular one and its network, and failsafe never switches; with the tag in the device tree, every boot used
it, and a refusal took all wired ports down, failsafe included.

One change against the prototype: TCP FIN/RST and TTL 0/1 frames addressed through the router are **redirected**
to port 5 by the switch, not copied. They take the normal software path, so nothing has to drop a duplicate,
and the flowtable sees the close and removes the hardware entry. Tested with the image of the PR (wired hosts on
the WAN and LAN side, iperf3):

| Test | Result |
|---|---|
| TCP LAN to WAN, both directions | 941 Mbit/s, CPU 97 % idle |
| port forward, WAN host to LAN host | 943 / 946 Mbit/s at 0 % CPU (software flowtable: 477 / 548, one core full) |
| hit counters as flow statistics | one hit = one packet: 74,998 and 100,002 UDP datagrams counted exactly (plus the one that set up the flow, in software) |
| TTL 1 inside an offloaded flow | rule on: "time exceeded" comes back; rule off: dropped silently |
| TCP FIN and RST inside an offloaded flow | rule on: hardware entries gone within 1 s; rule off: the entry stays |
| `fw4 reload` during a transfer, 20 times | every transfer continues, 12-second averages 891-941 Mbit/s |
| offloading off/on 10 times, port 5 down/up 10 times, 3 reboots, flowtable modules unloaded and reloaded 10 times | 940-941 Mbit/s after each, no kernel warnings |
| 1-hour soak through the port forward (TCP each way, UDP 300 Mbit/s, 15 rounds) | 940-941 Mbit/s, UDP 0-0.0013 % loss, no kernel warnings, no memory growth |

The patch files are generated with `git format-patch` and refreshed the way OpenWrt's `make target/linux/refresh`
does, as OpenWrt's formality check asks.

## Wi-Fi (researched 2026-11-18/19)

**The FA cannot carry Wi-Fi traffic, and on the EA6900 it would not help if it could.**

- The radios sit on PCIe, so their frames never pass port 8 and the FA never sees them. Broadcom's own driver
  refuses an FA entry unless both sides are Ethernet (GMAC) interfaces (`fa_napt_add()` in `etc_fa.c`); its
  firmware forwards Wi-Fi in software (CTF). OpenWrt's equivalent is the software flowtable, and Wi-Fi
  connections do use it with `flow_offloading_hw` on (the hardware refuses them, the software path takes them).
- Measured on the EA6900 (5 GHz, VHT80, 3-stream client, routed to a wired host on the WAN side, software
  flowtable): about **410 Mbit/s** WAN to client and **315 Mbit/s** client to WAN. The limit is the CPU: the Wi-Fi
  driver's (b43-next) 5 GHz interrupt thread takes 85-92 % of one core in both directions, and to the client the
  other core is full with receiving from the switch and sending to the radio.
- The same transfer **bridged** (a wired LAN host to the Wi-Fi client: no routing, no NAT, no flowtable) is not
  faster (395-398 Mbit/s); routing, NAT and the flowtable together cost about 10 % of one core. A hybrid mode
  (FA does the lookup and NAT, the CPU only forwards) could at most save those 10 % and give no extra
  throughput, while every Wi-Fi packet would also have to cross port 8 to the FA and back. Not worth building.
- The software flowtable itself does help: +26 % to the client and +57 % from the client against plain
  forwarding. It is on with OpenWrt's `flow_offloading`.
- firewall4 adds Wi-Fi interfaces to the flowtable only when it (re)loads after they exist. At boot that can be
  too early ([openwrt/firewall4#123](https://github.com/openwrt/firewall4/pull/123) fixes that). On our EA6900 the
  IPv6 WAN coming up a moment after the radios made firewall4 reload again, so the boot gap did not show; on a
  setup without IPv6 on the WAN it can.

So any further Wi-Fi speed-up has to come from the CPU side, not from the FA:

- **Packet steering (RPS) for the Wi-Fi interfaces** (2026-11-19, R6400 v2). The radio's interrupt thread receives
  each frame and, without RPS, also forwards it on the same core, which is then the limit. RPS hands the forwarding
  to the other core. OpenWrt's packet steering does not do this on bcm53xx (the target's own script sets only
  `eth0` and `br-lan`, and it does not run again when `wifi` creates the AP interfaces), so the
  [FA kit](../bcm53xx-performance-kit/#rps-on-for-the-wi-fi-interfaces) adds a hotplug script that sets
  it per AP interface, to the core that does not take that radio's interrupt. With irqbalance putting the two
  radios on different cores, the R6400 v2 reaches **424 / 356 Mbit/s** (5 GHz, client to LAN / LAN to client) and
  **235 / 199 Mbit/s** (2.4 GHz, 40 MHz), and the "RX descriptor underrun" errors at full upload are gone.
- RPS on the Ethernet side stays off: moving it to the second core cost 5 GHz download speed (337 instead of 356
  Mbit/s).
- Beyond that the limit is the Wi-Fi driver's receive path (a threaded interrupt without NAPI).

## Details (for the technically minded)

### How it fits together

The FA sits between the Ethernet controller GMAC2 and port 8 of the built-in BCM5301x switch. Its registers are
at GMAC3 + 0xc00 (0x18027c00). It only works when the CPU and the FA talk with the 4-byte **prepended**
Broadcom header (`brcm-prepend` in Linux DSA terms) on port 8. That needs two kernel changes:

1. b53 must be able to switch port 8 between the normal Broadcom tag and the prepended one
   (`change_tag_protocol`);
2. the `tag_brcm` driver must accept the FA's own opcode 2 ("lookup result, with flow id"), which the FA puts
   on packets it sends to the CPU.

Mainline already uses `brcm-prepend` on port 8 for the BCM58xx because of the FA. The 1024-entry flow table
is indexed by a CRC-CCITT of the 5-tuple, which software can compute (verified against the FA's own flow ids):
256 hash rows × 4 buckets. Next hops (destination MAC + port) and pools (source MAC) are separate small tables.

The prototype hooks into Linux's standard **nftables flowtable hardware offload** (`TC_SETUP_FT`, the same
interface the MediaTek PPE uses): the firewall decides what is offloaded, the module only writes the entries.

### Test results

| # | Item | Result |
|---|---|---|
| 1 | **Error bits** | The error register is write-1-to-clear. Bit 0 (receive buffer overflow) sets whenever the path runs at line rate, but with 0 retransmits and 0 % loss: Ethernet flow control slows the sender. Bit 1 (TX queue overflow) never came back; it was a leftover of the switch-over. **Harmless**; cleared at init, reported only. |
| 2 | **Switch address-table aging** (one-way traffic) | 420 s of one-way UDP: the client's MAC never aged out. Forced aging (10 s, silent client): the entry ages out after ~15 s and the switch floods **only within the LAN side**, nothing to the WAN port, 0 % loss. **No fix needed.** |
| 3 | **Many flows / full table** | 128 TCP connections: 937 Mbit/s at 0 % CPU. The table fills to 1024 of 1024; refused flows stay in software (643 Mbit/s); no leaks afterwards. A flow refused while the table was full moves to hardware by itself later (625 → 941 Mbit/s). A direction is only offloaded when its reply direction fits too (the flowtable retries only when both were refused). |
| 4 | **DNAT (port forward)** | WAN → LAN 927/949, LAN → WAN 949/926 Mbit/s, 0 retransmits, **0 % CPU**. Software: 729/746 and 617/602 Mbit/s with one core full. |
| 5 | **Retransmits at flow start** | 0 in 20 of 20 runs, including each first second. |
| — | **UDP** | Offloaded in all runs. The UDP upload loss in our setup (16 % at 900 Mbit/s) is the same in software, so it comes from the test setup, not the FA. |
| 6 | **VLAN on the WAN port** | **Works.** Download (tag removed by the FA) worked at once: 931 Mbit/s. Upload (tag added by the FA) first failed: the switch dropped the FA's tagged output, because Linux's b53 switch driver only writes VLAN table entries when VLAN filtering is on, so VLAN 10 had no member ports. Fix: the module adds the WAN port and the FA port as tagged members while a connection uses the VLAN, and restores the entry afterwards. Then 938 up / 935 down at 1–2 % CPU (941/941 without VLAN); FIN/RST copies are recognised with the tag; 2-hour soak clean; UDP, a full table, firewall reloads, unloading under traffic, routing without NAT (TTL lowered) and WAN cable pulls all tested. |
| 7 | **Routing without NAT** (action 0) | **Works** (Broadcom never used it): 943 Mbit/s at 0 % CPU, software 713. **TTL decremented** on every offloaded packet (508k packets arrived with TTL 63, none with 64). The retransmits seen in one direction were located *upstream* of the router by counting frames per hop: the router passes every frame on; TCP's normal probing loss just moves to the next bottleneck. |
| 8 | **IPv6** | **Works.** Found on the hardware (Broadcom's public code never adds IPv6 entries): the FA's hash is the IPv4 one with the full 128-bit addresses (68 of 68 flows matched); an IPv6 flow takes **two** table slots, which must start at slot 0 or 2 of a hash row; the layout was confirmed field by field (flipping any one bit stops the hits). In the module: TCP 928/928 Mbit/s at 98 % idle (software 735); UDP offloaded with no packet lost by the FA (every loss we saw was counted at the receiving machine); a full table mixed with IPv4: every entry forwards. Routed only: IPv6 with NAT stays in software. |
| 9 | **TCP FIN/RST** (conntrack) | Problem: closed offloaded connections stayed ESTABLISHED in conntrack for ~2 h (429 leftovers after 4 test runs), because the FA forwards the FIN/RST itself. Fix, as in Broadcom's driver: a switch (CFP) rule copies FIN/RST from the LAN/WAN ports to the spare port 5; the module marks the flow as closing. Closed connections now leave conntrack within 45 s; 0 lost copies; throughput unchanged. |
| 10 | **TTL / hop limit 1** | Problem: for an offloaded connection the FA **drops** IPv4 packets with TTL 1 without telling anyone (no ICMP "time exceeded"), and **forwards** IPv6 packets with hop limit 1 with hop limit 0, which a router must never do. Linux's own software offloading hands such packets back to the normal path. Fix: the switch can classify the TTL (we measured its four classes: 0, 1, 2–254, 255), so one switch rule sends TTL/hop limit 0–1 to the spare port 5 instead of the FA; port 5 carries the Broadcom tag, so the module knows the incoming port and gives the packet to Linux as if it came in there. Tested: Linux answers with "time exceeded" for IPv4 and IPv6, from the LAN and from the WAN side, also inside connections the FA already handles; a 41,000 packets/s flood of such packets lost none (and the router stayed more responsive than without the rule: ping 2 ms instead of 18 ms); throughput unchanged (941 Mbit/s); can be switched on and off while traffic runs; a 1-hour soak (60 rounds of full-speed traffic, each with these checks from the LAN and the WAN side) had no failure. **With a VLAN-tagged WAN** the first version dropped such packets from the WAN (it expected the IP header right after the Ethernet header, not a VLAN tag): fixed, the packet keeps its tag and Linux's VLAN handling takes it; tested in the 2-hour IPv6 + VLAN soak. |
| 11 | **Firewall reload** | Problem: on a firewall reload (or switching offloading off) Linux disconnects the old flowtable from the driver *before* it removes its connections, so the driver never hears about them (the same holds for the MediaTek driver). The prototype's entries stayed in the FA and kept forwarding, outside the new firewall rules, until the connection closed. Fix: the module notes which flowtable added each entry and removes that flowtable's entries when it disconnects. Tested with IPv4 and IPv6 traffic running: switching off empties the table at once; on a reload the running connections are back in hardware within 2 s; 18 reloads during the 2-hour soak. |

### Settings

The prototype module has two settings meant for users (they will become options of the real driver):

| Setting | Default | What it does |
|---|---|---|
| `ttl_trap` | on | Sends packets with TTL / hop limit 0 or 1 past the FA to Linux (see test 10). Switch it off only to compare with the bare hardware behaviour. While it is off, IPv6 is not offloaded (the FA would pass hop limit 1 on as 0). |
| `ipv6` | on | Offloads routed IPv6 connections. Off: IPv6 stays in software, IPv4 is unaffected. |

Set them when the module loads (`insmod bcmfa ttl_trap=0`, or the line `bcmfa ttl_trap=0` in a file in
`/etc/modules.d/`), or change them while the router runs: `ttl_trap` takes effect at once, `ipv6` for new
connections (same commands with `ipv6` instead of `ttl_trap`):

```sh
cat /sys/module/bcmfa/parameters/ttl_trap        # Y = on, N = off
echo 0 > /sys/module/bcmfa/parameters/ttl_trap   # off
echo 1 > /sys/module/bcmfa/parameters/ttl_trap   # on
```

### Limits of the hardware

- **No PPPoE**: the FA entry has no field for it (Broadcom: "currently not supported for PPP").
- **No byte counters**: an entry has a hit (packet) counter and a 3-bit timestamp only. Offloaded connections
  stay alive in conntrack through the packet counter, but their byte counts are too low.
- **Port 8 is 1 Gbit/s**: routed traffic crosses it twice, so both directions together top out at about
  1130 Mbit/s (see *What does it give?*).
- **1024 entries** (two per connection, one per direction); an IPv6 entry takes two slots, so a hash row holds
  at most two IPv6 directions, or one IPv6 and two IPv4.
- **No check for TTL / hop limit 1** of its own that Linux can live with (IPv4: silent drop; IPv6: forwarded with
  hop limit 0); the switch rule above covers it.

## Sources

Everything here comes from public sources and our own measurements on our own routers. The full record, including
what an upstream driver must do to keep it clean, is in **[PROVENANCE.md](PROVENANCE.md)**.

- Broadcom's `et` Ethernet driver with the FA code (`etc_fa.c`, `fa_core.h`, `bcmrobo.c`), published under an
  ISC-style permission notice in the GPL source releases, for example
  [FreshTomato-Project/freshtomato-arm](https://github.com/FreshTomato-Project/freshtomato-arm) @ 08bcf264
  (`release/src-rt-7.14.114.x/src/et/`) and [mirror/dd-wrt](https://github.com/mirror/dd-wrt) @ fd537862
  (`src/linux/universal/linux-4.14/brcm/arm/`).
- Register read-back and traffic measurements on our Linksys EA6900 v1 and Netgear R6400 v1/v2.
- OpenWrt and Linux (b53, DSA, nftables flowtable).

Questions: please open an issue.
