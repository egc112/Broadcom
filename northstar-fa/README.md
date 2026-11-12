# Northstar FA: hardware NAT offloading on Broadcom BCM4708/BCM4709 routers — RESEARCH

> **Status: research prototype, nothing to install yet.** Under OpenWrt the flow accelerator ("FA") in these
> routers works. It routes and NATs at full gigabit speed with the router's CPU idle. But it runs as a test module
> that needs two kernel changes and a switch-over script. This page explains what the FA is, how to check whether
> your router has one, and what we measured. A proper OpenWrt driver comes when the remaining features are done.
> Tested on the Linksys EA6900 v1. Not in OpenWrt or the Linux kernel.
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
| Wi-Fi clients | no: the radios are not behind the switch (their traffic stays in software, fast path) |
| IPv6 | not yet: the hardware has IPv6 entries, the layout still has to be worked out |
| WAN with a VLAN tag (some ISPs) | not yet: planned |
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

941 Mbit/s is the most a gigabit link can carry with TCP, so the FA is not the limit. DD-WRT with Broadcom's
own driver reaches the same (950/949) on these routers.

¹ fw4's "software flow offloading" with firewall4 3722eadc08 or newer. Older snapshots have a firewall4 bug
that makes software offloading *slower* (213/245) on these routers; see the note in the
[EA6900 build kit README](../linksys-ea6900/build-kit/README.md) (*Known limitations*).

## Status

Working in the prototype, measured on the EA6900:

- nftables flowtable hardware offload (`flow_offloading_hw` in OpenWrt's firewall works as-is).
- Both directions of a connection always together, so no half-offloaded connections.
- A full table (1024 entries) is handled cleanly: new connections stay in software, then move to the FA by
  themselves once space frees up; nothing is left behind afterwards.
- Closed connections (TCP FIN/RST) are noticed, as Broadcom does it: a switch rule copies them to the CPU, so
  connection tracking does not keep them around for two hours.
- No flooding of offloaded packets to other ports.
- TTL is decremented on offloaded packets.
- 2-hour soak test with full load in both directions, port forwards and DNS churn at the same time: no errors,
  69,070 hardware entries added and all removed again, connection tracking back to normal afterwards, CPU mostly
  0–8 %. The same load without the FA (software offloading): one core full, ping loss 8.3 % instead of
  0.8 %, average ping 10.7 ms instead of 1.2 ms, DNS timeouts 3.4 % instead of 0.14 %.

Still to do before a real driver: IPv6, VLAN on the WAN port, and the other routers (the R6400 first needs
openwrt/openwrt#25131). Then the proper OpenWrt patch: the FA code in the Ethernet driver (bgmac), active
from boot instead of a switch-over script, and the two kernel changes cleaned up for upstream.

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
| 6 | **VLAN on the WAN port** | Not done yet (needs a tagged uplink). The FA has a tag field for it. |
| 7 | **Routing without NAT** (action 0) | **Works** (Broadcom never used it): 943 Mbit/s at 0 % CPU, software 713. **TTL decremented** on every offloaded packet (508k packets arrived with TTL 63, none with 64). The retransmits seen in one direction were located *upstream* of the router by counting frames per hop: the router passes every frame on; TCP's normal probing loss just moves to the next bottleneck. |
| 8 | **IPv6** | Not done yet. A v6 entry uses two table slots; Broadcom's public code does not give the layout, so it has to be found on the hardware. |
| 9 | **TCP FIN/RST** (conntrack) | Problem: closed offloaded connections stayed ESTABLISHED in conntrack for ~2 h (429 leftovers after 4 test runs), because the FA forwards the FIN/RST itself. Fix, as in Broadcom's driver: a switch (CFP) rule copies FIN/RST from the LAN/WAN ports to the spare port 5; the module marks the flow as closing. Closed connections now leave conntrack within 45 s; 0 lost copies; throughput unchanged. |

### Limits of the hardware

- **No PPPoE**: the FA entry has no field for it (Broadcom: "currently not supported for PPP").
- **No byte counters**: an entry has a hit (packet) counter and a 3-bit timestamp only. Offloaded connections
  stay alive in conntrack through the packet counter, but their byte counts are too low.
- **1024 entries** (two per connection, one per direction); IPv6 entries will need two slots each.

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
