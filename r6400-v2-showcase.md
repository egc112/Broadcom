# From barely 10 Mbit/s to wire speed

*OpenWrt on the Netgear R6400 v2, measured 19 November 2026*

A month ago the R6400's Wi-Fi ran 802.11g only and managed about 10 Mbit/s next to the router. With b43-next, the
Northstar flow accelerator and some tuning, the same router now forwards a gigabit link at 1 % CPU and moves over
400 Mbit/s over 5 GHz Wi-Fi.

| | Throughput | Note |
|---|---|---|
| Wired, IPv4 routed + NAT | **941 Mbit/s** | both directions, CPU 1–2 % busy |
| Wired, IPv6 routed | **928 Mbit/s** | both directions, CPU 1 % busy |
| 5 GHz Wi-Fi (VHT80, 3×3) | **424 / 356 Mbit/s** | client → LAN / LAN → client |
| 2.4 GHz Wi-Fi (HT40, 3×3) | **235 / 199 Mbit/s** | client → LAN / LAN → client |
| WireGuard server on the router | **235 / 170 Mbit/s** | client → LAN / LAN → client, both cores busy |

## Where we started: the 2.4 GHz radio, step by step

The R6400's 2.4 GHz radio is a BCM4331. OpenWrt's stock b43 driver ran it as 802.11g only. Its external front end
was not set up, so the receiver was nearly deaf, and the hardware power loop over-drove the amplifier: a strong but
distorted signal. The 5 GHz radio, a BCM4360, had no working driver at all.

| When | What | Throughput |
|---|---|---|
| 13 Oct 2026, stock OpenWrt | 802.11g only, deaf receiver (heard the other router at −75 dBm, after the fix −48 dBm), over-driven amplifier | ≈ 10–12 Mbit/s down, next to the router |
| 14 Oct | Front end set up, fixed TX gain instead of the power loop | ≈ 22 Mbit/s, the 802.11g ceiling |
| 14 Oct | 802.11n, one stream, frame aggregation | 46 down / 80 up Mbit/s |
| 30 Oct | Two spatial streams | ≈ 100 / 100 Mbit/s |
| 17 Nov, b43-next | Three spatial streams, 40 MHz (MCS 23); measured with a DL-WRX36 client | 325 up / 210 down Mbit/s |
| **19 Nov, today** | Flow accelerator, RPS, irqbalance, latest b43-next | 2.4 GHz 235 up / 199 down · 5 GHz 424 up / 356 down · wired 941 |

## Test setup

- **Router:** Netgear R6400 v2: Broadcom BCM47094, two Cortex-A9 cores at 1 GHz, BCM53011 switch, BCM4331
  (2.4 GHz, 3×3) and BCM4360 (5 GHz, 3×3).
- **Firmware:** OpenWrt snapshot r38478, kernel 6.18.64, built with the
  [b43-next build kit](b43-next-build-kit/) and the
  [flow accelerator patches](northstar-fa/). Wi-Fi driver:
  [b43-next](https://github.com/aleferri/b43-next) 42a5567 with pull request #39, the same code as b43-next 4854b6f.
- **Wired path:** a desktop PC (Ubuntu 24.04, gigabit Ethernet) on a LAN port, to an iperf3 server on the WAN side,
  behind NAT on the R6400. The WAN side is a plain Ethernet segment, no PPPoE.
- **Wi-Fi client:** a GL.iNet GL-MT6000 as station, a few metres from the router, three spatial streams.
  5 GHz: channel 149, 80 MHz, link at VHT MCS 8–9 (−44 dBm). 2.4 GHz: channel 6 + 10, 40 MHz, link at MCS 23
  (−32 to −37 dBm). "To LAN" is the wired PC; "to WAN" is the WAN-side server, through NAT.
- **Method:** iperf3 TCP, 30 s per run, one stream and four parallel streams; the figure is what the receiver got.
  CPU load is read from the router's `/proc/stat` over the same 30 s, per core.

## Optimisations

- **Flow accelerator.** The BCM47094 has a hardware flow engine in front of the switch's CPU port. Once a connection
  is set up, it forwards and translates the packets itself, IPv4 and IPv6. Packets that need the kernel (TTL or hop
  limit about to expire, TCP FIN and RST) are trapped to it. Switch it on with software and hardware flow
  offloading in the firewall settings.
- **b43-next.** b43 with working 802.11n for the BCM4331 and 802.11ac for the BCM4360: three spatial streams,
  aggregation, a working front end.
- **RPS for Wi-Fi.** b43-next handles each radio's receive in that radio's interrupt thread. A hotplug script moves
  the forwarding work of each Wi-Fi interface to the other CPU core.
- **irqbalance.** Puts the two radios' interrupts on different cores, which the RPS script then builds on.
- **Left as it was:** RPS on the Ethernet side. Moving it to the second core cost 5 GHz download speed (337 instead
  of 356 Mbit/s), so it stays off.

## Wired: LAN to WAN, three ways of forwarding

Same router, same cable, same PC. Only the firewall's offload setting changes.

| Mode | Traffic | Mbit/s | CPU busy |
|---|---|---|---|
| Flow accelerator (hardware) | IPv4 up | 941 | 1 % |
| | IPv4 down | 941 | 2 % |
| | IPv6 up | 928 | 1 % |
| | IPv6 down | 928 | 1 % |
| Software flowtable | IPv4 up | 601 | 96 % |
| | IPv4 down | 593 | 96 % |
| | IPv6 up | 580 | 93 % |
| | IPv6 down | 602 | 97 % |
| No offload | IPv4 up | 468 | 70 % |
| | IPv4 down | 488 | 53 % |
| | IPv6 up | 442 | 68 % |
| | IPv6 down | 501 | 52 % |

Without offload, one core does all the forwarding (98 % busy) while the other waits. The software flowtable uses
both cores but stops near 600 Mbit/s. The flow accelerator reaches the line rate of gigabit Ethernet with the cores
idle.

## Wi-Fi: both bands, to the LAN and to the WAN

The flow accelerator only sees the switch ports, so all Wi-Fi traffic passes through the CPU. At 5 GHz both cores are
about 90 % busy: the CPU, not the radio, sets the limit.

| Band / path | Direction | 1 stream | 4 streams | CPU busy |
|---|---|---|---|---|
| 5 GHz to LAN | up | 422 | 424 | 91–93 % |
| 5 GHz to LAN | down | 356 | 356 | 90–91 % |
| 5 GHz to WAN | up | 282 | 331 | 75–91 % |
| 5 GHz to WAN | down | 338 | 351 | 87–90 % |
| 2.4 GHz to LAN | up | 229–235 | 30\* | 10–21 % |
| 2.4 GHz to LAN | down | 199 | 194 | 54 % |
| 2.4 GHz to WAN | up | 160\* | 92\* | 24–58 % |
| 2.4 GHz to WAN | down | 198 | 196 | 51–54 % |

All figures in Mbit/s. \* Varies between runs, see below.

**About the 2.4 GHz upload.** 40 MHz had to be forced here: about 50 neighbouring networks share the band, and the
router normally falls back to 20 MHz in that case. Five 30-second runs in a row gave 229–235 Mbit/s with no
retransmissions and no second below 208 Mbit/s. In the earlier runs of the same afternoon, though, the upload
stopped for whole seconds at a time and averaged 80–160 Mbit/s, with the radio link at MCS 23 throughout; the
figures marked \* come from that period. That points to the neighbours sharing the wider channel. At 20 MHz the
same client uploads a steady 135–138 Mbit/s without any of those pauses.

## WireGuard: a server on the router

*Measured 21 November 2026, same router, firmware and settings.*

A desktop PC on the WAN side connects to a WireGuard server on the R6400 and runs iperf3 TCP through the tunnel to
a host on the LAN, two parallel streams, about 20 s per direction.

| Direction | Mbit/s | CPU busy |
|---|---|---|
| Client → LAN (the router decrypts) | 235 | both cores 100 % |
| LAN → client (the router encrypts) | 170 | both cores 97–99 % |

On DD-WRT the same router manages about 120 Mbit/s LAN → client, measured the same way.

The crypto runs on the CPU: the Cortex-A9 cores of the BCM47094 have no NEON, so ChaCha20-Poly1305 runs as plain ARM
code, and both cores are fully busy in both directions. The flow accelerator cannot help here. The encrypted packets
end at the router itself, and the decrypted traffic leaves through the WireGuard interface, which is not a switch
port. Software offloading does take the decrypted leg (the tunnel's connections show `[OFFLOAD]`), so those packets
skip most of the firewall. The LAN → client direction is slower with the same full load, so encrypting costs more
per packet than decrypting. The likely reasons, not measured one by one: an encrypted packet needs room for padding
and the authentication tag, which can mean a copy, and it goes through the full output path, with no flowtable to
shortcut it.

## These are best-case figures

They were measured under ideal conditions: a client a few metres away with a clear line of sight, one client at a
time, a quiet 5 GHz channel, a router doing nothing else, and test traffic that can use the whole link. At home you
will see less: walls, distance, older or two-stream phones and laptops, neighbouring networks, several devices at
once, and anything else the router has to do all take their share. Treat the figures as what the hardware and the
software can do, not as a promise for a given home.

---

b43-next: Alessio Ferri (aleferri) and contributors. OpenWrt b43-next package: Ville Takio (flatstik). Board,
flow-accelerator and test work: Erik Conijn (egc112), with the help of Claude.

The iperf3 and CPU logs behind every figure are kept with the test scripts; ask in an issue if you want to see them.
