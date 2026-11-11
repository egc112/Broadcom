# b43: 802.11n with A-MPDU for the BCM4331 (Netgear R6400) — TEST VERSION (rc15)

> **Status: test version.** Since rc9 this series is a small set of patches **on top of Rosen
> Penev's b43 802.11n series**, openwrt/openwrt#25922, which brings 802.11n to b43 upstream.
> rc15 is rebased on his series as of 87e30600fa, which now also carries six of our patches
> (890, 891 and 893–896, see *What is in rc15*). On top of it rc15 adds up to **four SSIDs**
> on the BCM4331 (897, 898), Alessio Ferri's kernel patch 880 for the 5 GHz radio as in rc13,
> and a fix for the USB LEDs (318). rc14 was not released.
> Tested on the author's Netgear R6400 v1 and v2: rc9 in a 9.5-hour soak test with two clients
> and a phone, rc15 in the tests below.
> Not in OpenWrt or the Linux kernel yet.
> Please test and report back (see *Reporting problems*), and read *Known limitations* first.
>
> The older stand-alone series (rc8, patches 820–839) is kept in [patches-rc8](patches-rc8/)
> with its [README](README-rc8.md).

The 2.4 GHz radio of the Netgear R6400 is a **Broadcom BCM4331** (HT-PHY, "b43" driver).
Stock b43 runs it as 802.11g only, with a weak receiver and a distorted transmitter:
about 10–12 Mbit/s download. With Rosen Penev's series and these patches it runs 802.11n
(HT20, two streams, A-MPDU in both directions) at about 100 Mbit/s each way.

| Netgear R6400, 2.4 GHz, 20 MHz (iperf3 TCP, ath11k client) | download (router → client) | upload (client → router) |
|---|---|---|
| stock b43 (802.11g), v1 | 10–12 Mbit/s | 20–22 Mbit/s |
| rc8 (our old series), v1 | ~85–90 Mbit/s | ~90–105 Mbit/s |
| **rc9 = openwrt/openwrt#25922 + these patches**, v1 (soak test; rc10 and rc11 are the same speed) | **96–111 Mbit/s, avg 107** | **90–111 Mbit/s, avg 107** |
| **rc13**, v1 (no soak: runs of 20 s, iperf3 on the router, see *Changes in rc13*; rc12 is the same speed) | **111–112 Mbit/s** | **99–102 Mbit/s** |
| **rc13**, v2 (no soak: runs of 20 s to 3 min, iperf3 on the router) | **103–104 Mbit/s** | **106–107 Mbit/s** |
| **rc15**, v2 (soak of 3 h 50 min, two SSIDs; ath11k client alone on the second SSID, wired iperf3 server) | – | **104–109 Mbit/s, avg 107** |

## What is in rc15

rc15 = OpenWrt main + **openwrt/openwrt#25922 as of 87e30600fa** (Rosen Penev: the b43 patches
in `package/kernel/mac80211/patches/brcm/`, a bcma patch, and b43 firmware 784.2) + the patches
in [patches](patches/) + the kernel patches in [patches/kernel](patches/kernel/) +
`+@DRIVER_11AC_SUPPORT` in the `kmod-b43` dependencies (since rc13: hostapd then accepts
802.11ac settings, see *Hardware*):

| Patch | What it does | Why |
|---|---|---|
| [897](patches/897-wifi-b43-HT-PHY-run-up-to-four-APs-on-the-BCM4331.patch) | HT-PHY: run up to four APs on the BCM4331 | New in rc15. Stock b43 takes one interface. With firmware 784 the BCM4331 matches the BSSIDs of further APs with one base address under a mask (SHM 0x640–0x64c); 897 sets it, sends the further APs' beacons at the first AP's beacon time, and keeps their group keys in software. Only on core rev 29 (BCM4331) with firmware 784; every other device keeps one interface. Based on Ville Takio's multi-AP change for the AC-PHY cores. See [PROVENANCE.md](PROVENANCE.md) |
| [898](patches/898-wifi-b43-HT-PHY-give-the-BCM4331-a-block-of-four-MAC-addr.patch) | HT-PHY: give the BCM4331 a block of four MAC addresses | New in rc15. The first SSID keeps the factory address; SSIDs 2–4 get the locally administered form of it with the next low bits (on an R6400 with factory address `cc:…:3a`: `ce:…:3b`, `ce:…:38`, `ce:…:39`), in the order OpenWrt assigns them. No `macaddr` needs to be set, and a single SSID keeps the same address as before. Broadcom's own driver does the same |
| [wifi-scripts](patches/wifi-scripts-b43-best-effort-frame-bursting.patch) | best effort frame bursting (`tx_queue_data2_burst 2.0`) by default on b43 802.11n radios | Shares the air fairer when a client uploads and downloads at once (see *Traffic in both directions*). A patch to the OpenWrt tree, not to the mac80211 package |
| [880](patches/kernel/880-bcma-ssb-support-the-BCM4352-BCM4360-family.patch) (as in rc13) | bcma/ssb: support the BCM4352/BCM4360 family. By **Alessio Ferri**, copied unchanged from [aleferri/b43-ac-wip](https://github.com/aleferri/b43-ac-wip) (`patches/`, commit [16eb94d](https://github.com/aleferri/b43-ac-wip/commit/16eb94d)) | The kernel reads the BCM4360's SPROM revision 11 from the router's nvram and sets up its power management unit, so that an AC-PHY b43 module can be loaded for 5 GHz tests (see *Hardware*). Nothing changes at 2.4 GHz |
| [318](patches/kernel/318-ARM-dts-BCM5301X-R6400-add-the-USB-LED-trigger-sources.patch) | R6400 device tree: add the USB LED trigger sources | New in rc15. Without them the kernel logged `Failed to get trigger sources` for the USB LEDs at boot. The LEDs worked before too. Sent to OpenWrt as openwrt/openwrt#26631 |

**Now in Rosen Penev's series** (his update of 2026-11-10, 87e30600fa, with the same numbers): 890 (do not
disable NAPI on SDIO devices), 891 (HT-PHY: no table 9 upload on FEM and HGPA boards: +40 Mbit/s
download on the R6400 v1), 893 (HT-PHY RX I/Q calibration: MCS 15 losses 32.8 % → 2.1 % on the
v1), 894 (HT-PHY: receive A-MPDUs of up to 64 KiB), 895 (drop the A-MSDU subframes the MAC splits
off) and 896 (only the NAPI poll walks the DMA RX ring: fixes a double free of RX buffers that
crashed an R6400 v2 with two stations under load). What each does is described in his PR, in the *Changes in* sections below and in the
[rc13 version of this page](https://github.com/egc112/Broadcom/blob/b43-80211n-rc13/b43-80211n/README.md#what-is-in-rc13).

**Gone in rc15: 892** (the `ht_txgain_idx` module parameter, see *Transmit power*). Upstream does
not want new module parameters, so it is not in his series; it may come back in a later version.

897, 898, 318 and the wifi-scripts patch are by Erik Conijn and carry `Assisted-by:
Claude:claude-opus-5-5`: they were written with the help of an AI assistant, which also ran most
of the measurements. 880 is Alessio Ferri's.

What Rosen Penev's series brings (see his PR for the details): 802.11n HT20 for N-PHY and
HT-PHY devices, two spatial streams, A-MPDU in both directions, short guard interval, STBC,
RTS/CTS for aggregates, power save in AP mode, airtime fairness, NAPI, software encryption of
protected management frames (WPA3/PMF), the transmit I/Q and LO calibration for HT-PHY, firmware
784.2 as the default, the R6400 fixes from our rc2–rc8 series and the six patches above. Since
rc13 it also has N-PHY fixes by Ville Takio (BCM43217, RX I/Q calibration, 64 KiB A-MPDUs) and
two by Marco Martins (G-PHY, one TX descriptor per frame from core rev 30). Thanks to him for the
work and for taking our patches in.

## Hardware

* **Netgear R6400 v1** (BCM4709 + BCM4331, external high-gain PA, `BFL_HGPA`): tested as an
  access point.
* **Netgear R6400 v2** (BCM4331 with FEM, `BFL_FEM`): tested as a client and as an access point.
* Other BCM4331 boards: 897 and 898 act on every BCM4331 (core rev 29) with firmware 784, but
  were only tested on the R6400 v2 and v1. Several SSIDs need firmware 784 (the default);
  with another firmware b43 accepts one AP only, as before.
* **BCM4360 (AC-PHY) is not supported**, neither by stock b43 nor by these patches: that is the
  5 GHz radio of the R6400 and both radios of the Netgear R7000. b43 logs
  `FOUND UNSUPPORTED PHY (Analog 12, Type 11 (AC))` for it; that line is expected.
  Since rc12 the kernel also fills in the BCM4360's revision-11 SPROM fields from the nvram
  (front end, receive gains, transmit power) and sets up its power management unit (new in
  dmesg: `bus2: PMU PLL pre-write` and `bus2: PMU res mask pre-write`; rc11 logged
  `PMU resource config unknown` there), so that an AC-PHY b43 built from
  [aleferri/b43-ac-wip](https://github.com/aleferri/b43-ac-wip) against the **same** rc15 build
  tree can be loaded for 5 GHz tests; since rc13 hostapd also accepts VHT80 for it. That driver
  replaces the rc15 b43 for both radios while it is loaded, and the two cannot be combined yet:
  the 2.4 GHz radio then runs as 802.11g only, at about 10 Mbit/s. So use either this series
  (2.4 GHz) or the AC-PHY module (5 GHz), not both.

## Test results

### Changes in rc15

rc15 is rebased on Rosen Penev's series as of 87e30600fa (2026-11-10), which now contains our 890,
891 and 893–896; adds 897 and 898 (up to four SSIDs) and 318 (USB LEDs); drops 892. OpenWrt base,
kernel, 880 and firmware are rc13's (r38137-a4076a8021, kernel 6.18.60, 784.2).

Tests on the R6400 v2 (and v1 as a client):

* **One to four SSIDs** (2026-11-11, test module with the same 897/898 code): the SSIDs came up as
  `cc:…:3a` (factory), `ce:…:3b`, `ce:…:38`, `ce:…:39` with no address set in the configuration.
  An R6400 v1 as a b43 client on each SSID in turn: 75–86 Mbit/s down, 56–65 up; meanwhile a
  DL-WRX36 (ath11k) on the second SSID: 80–84 down, 102–107 up. No warnings.
* **Soak, test module** (2026-11-11, 58 cycles, 3 h 5 min, his previous head 35f92b83fc + the same
  897/898): no stall, reboot or b43 kernel message.
* **Soak, rc15 image** (2026-11-11, flashed, 50 cycles, 3 h 50 min, no driver reload): two SSIDs,
  the DL-WRX36 on the second and an R6400 v1 (b43 client) on the first; each cycle 60 s DL-WRX36
  upload, then 60 s of both SSIDs at once in each direction. No stall, reboot or b43 kernel message,
  memory steady (145–149 MB available). Mbit/s, average (min–max) over the 50 cycles:

  | phase | DL-WRX36, second SSID | R6400 v1, first SSID |
  |---|---|---|
  | DL-WRX36 upload alone | 107 (104–109) | – |
  | DL-WRX36 upload + v1 download | 88 (83–91) | 16 (13–18) |
  | DL-WRX36 download + v1 upload | 56 (53–60) | 46 (41–49) |

  While the DL-WRX36 uploads, the access point gets little air for its download to the v1 (second
  row); the other way round the shares are more even. The same was seen with one SSID (see
  *Traffic in both directions*).
* **USB LEDs** (rc15 image, v1 and v2): no `Failed to get trigger sources` at boot; on the v1 a USB stick lights
  the USB 1 LED in the front port (USB 3.0) and the USB 2 LED in the back port (USB 2.0).
* The receiver with 893 against an ath11k station at the same spots (2026-11-11, fixed MCS 15,
  transmit power stepped down): the same loss curve as the ath11k station from strong to weak
  signal; only very close to the access point (about -21 dBm) the R6400 v1 loses about 16 % of
  MCS 15 frames, which stays a known limitation.

### Changes in rc13

rc13 is rc12 with a newer 880 (b43-ac-wip 16eb94d: two more SPROM fields), `+@DRIVER_11AC_SUPPORT`
so that hostapd is built with 802.11ac, and a newer OpenWrt (r38137-a4076a8021). The b43 patches,
Rosen Penev's series and the firmware are rc12's. Nothing was meant to change at 2.4 GHz.

Tests 2026-11-05 (rc13 build, flashed on the R6400 v1 and v2):

* Boot: the BCM4360's power management unit is set up, the 4331 comes up as before, no radio hang
  in the reboots of the day, the watchdog runs.
* As access point with a DL-WRX36 (ath11k) as client, and iperf3 on the router itself. These runs
  used rc13's b43 with a read-only counter file added. R6400 v1 (channel 11, HT20, -42 dBm):
  TCP 111–112 Mbit/s down, 99–102 up. R6400 v2 (channel 6, HT20): 103–104 down, 106–107 up,
  3-minute runs included.
* The ucode's counters on a UDP download: 97–98 % (v1) and 95–96 % (v2) of RTS frames got a CTS.
  During TCP uploads the ucode counts TX underflows on FIFO 1 only, about 40 (v1) and 120 (v2) per
  20 s; none on downloads, and we see no effect on throughput.
* 5 GHz on the R6400 v1 with an AC-PHY module built from b43-ac-wip 16eb94d against the same tree,
  channel 149, VHT80: about 355 Mbit/s each way with the DL-WRX36 (link rate up to VHT-MCS 9,
  1300 Mbit/s), 333 down / 370 up with a phone. That is a test of his driver, not part of the images.

No soak test for rc13: the code of our patches is unchanged.

### Changes in rc12

rc12 is rc11 plus kernel patch 880 (see *What is in rc13*). The b43 code, the firmware and the
OpenWrt revision are rc11's; the b43 module is rebuilt only because 880 extends the kernel's
SPROM structure that b43 reads.

Tests 2026-11-04 on the R6400 v1 (rc12 image, flashed):

* Boot: the BCM4360's power management unit is set up, the 4331 comes up as before; three warm
  reboots with no radio hang; the watchdog runs.
* R6400 v1 as access point (channel 11, HT20), DL-WRX36 (ath11k) as client at -42 dBm, three
  rounds of 20 s iperf3 TCP each way and 20 pings: upload 99.5–99.9 Mbit/s, download
  112–113, MCS 15 short GI, no ping lost, no b43 errors (only the expected `UNSUPPORTED PHY`
  line of the BCM4360).
* R6400 v2 (rc12 image, flashed): three warm reboots with no radio hang, the watchdog runs. As
  access point (channel 6, HT20) with the DL-WRX36 as client at -31 to -34 dBm and a wired PC
  as the iperf3 server: TCP upload 96.0–97.8 Mbit/s, download 76.8–97.1, no ping lost; UDP at a
  fixed MCS 15 113–115 Mbit/s and at MCS 7 58–59, both with 0 % loss; no b43 errors.
* For comparison, a Linksys EA6900 (BCM4360, AC-PHY b43 from aleferri/b43-ac-wip) on the same
  channel, client and PC, its access point limited to two streams (MCS 0–15) like the BCM4331:
  TCP 91.5–95.0 up / 95.2–99.6 down, UDP at MCS 15 116–117 Mbit/s and at MCS 7 57 with 0 % loss.
  With its third stream it reached 131 up / 140 down; b43 uses at most two streams on the
  BCM4331.
* Measure UDP loss with a wired host as the iperf3 server, not the router itself: with the R6400
  as the receiver, its iperf3 process misses datagrams (`RcvbufErrors` in `/proc/net/snmp`;
  1–3 % at MCS 15, up to 9 % in one session) that the radio did receive.

### Changes in rc11

rc11 is rc10 rebased on Rosen Penev's updated series (openwrt/openwrt#25922 at fe90f890dc,
2026-11-02), with the default b43 firmware 784.2 that his update brings:

* Our patches are renumbered 890–895, because his series now uses 862–869. 864 is dropped (his
  series does the same now); the others are unchanged, except that 893 (rc10's 866) now runs
  after the transmit I/Q and LO calibration his update adds, as brcmsmac does (TX first, then
  RX).
* Firmware 784.2 (wl 6.30.163.46) replaces 666.2 as the default; the older firmware versions are
  no longer offered.

Tests 2026-11-03, alternated blocks (A, B, B, A, three rounds), 20 s iperf3 TCP each way and 20
pings per block, the module reloaded for every block:

* R6400 v1 as access point, R6400 v2 (rc10) as client, at close range: rc10 101.1 Mbit/s up /
  99.1 down, rc11 100.8 / 98.3 (both firmware 666.2); rc11 with firmware 666.2 102.3 / 98.2,
  with 784.2 102.7 / 100.2. No ping lost, no b43 errors.
* R6400 v2 as access point, DL-WRX36 (ath11k) as client: rc10 with 666.2 against rc11 with
  784.2: upload 97.2–108 against 96.9–97.9 Mbit/s, download 99.2–101 against 101–102; UDP at a
  fixed MCS 15 lost 1.8–4.6 % against 1.3–3.0 %. No ping lost, no b43 errors.
* No long soak test for rc11: the code of our patches is unchanged from rc10, and his update
  says its HT-PHY parts were done on a BCM4331 and on an R6400 v1/v2.

### Changes in rc10

rc10 is rc9 with patch 866 reworked and patch 868 added; Rosen Penev's series is the same
(0615bc0150).

* **866** now calibrates only the operating channel of a running access point or client, once
  each time the radio starts; switching back to that channel writes the stored result again.
  rc9 also calibrated on the channels mac80211 sets while an interface starts or stops, which
  gave an odd result at interface stop on the v1 and up to four calibrations each time the
  radio started. Scan channels stay uncompensated, as in rc9, and the calibration no
  longer runs at 5 GHz, where it was never measured. It no longer depends on a scan flag of
  Rosen Penev's series.
* **868** is new (see the table above).

Tests 2026-10-30 on the R6400 v2 as access point (channel 6), with a DL-WRX36 (ath11k) as
client:

* Calibrations: rc10 does 1 per `wifi` up, none at `wifi` down and none during a scan; rc9 did
  up to 4 each time the radio started.
* rc10 against rc9, alternated (rc10, rc9, rc9, rc10), iperf3 TCP and UDP at a fixed rate:
  upload 96–97 Mbit/s and download 100–102 Mbit/s for both; MCS 15 UDP loss 1.7–1.9 % (rc10)
  and 1.4–2.0 % (rc9): the same.
* A 43-minute soak with rc10: 12 cycles of download, upload and a scan, a `wifi` restart every
  third cycle: 100–102 Mbit/s down, 97.5–98.7 up, no b43 errors, no replays, memory stable;
  of 2574 pings, 16 were lost in the 4 restarts and 14 in the scans (the access point leaves its
  channel to scan), none otherwise.
* As a client: the R6400 v2 switching back and forth between the v1 (channel 11) and a test
  access point (channel 1) without restarting the radio calibrated once per switch, never
  during 9 scans, and never re-initialized. On channel 1, MCS 15 loss straight after a
  calibration was 0.5–1.4 % and after scans (stored result written back) 0.8–1.2 %: the same.
* 868: 20 hours on the R6400 v1 (rc9 + 868, with a counter for the dropped frames) as the
  access point for a phone: no A-MSDU arrived, no errors.

### rc9 soak test

Soak test 2026-10-26, 09:35–19:25: R6400 v1 as access point (rc9 code, channel 6, HT20,
the burst on), two clients that take turns and also upload together: an R6400 v2 (rc9, as a
client) and a DL-WRX36 (Qualcomm IPQ8074, ath11k); from 12:16 also a phone (Samsung S25 FE).
The wired end was a PC on the v1's LAN. 36 cycles of 60 s per direction per client, 10
minutes idle in between, a wifi restart on the access point every third cycle and a scan on
the v2 every fourth. iperf3 TCP in Mbit/s:

| | lowest | average | highest |
|---|---|---|---|
| R6400 v2 upload | 78 | 96 | 103 |
| R6400 v2 download | 85 | 101 | 104 |
| DL-WRX36 upload | 90 | 107 | 111 |
| DL-WRX36 download | 97 | 108 | 111 |

* No kernel errors, stalls or hangs on either R6400; memory stable (v1 146 MB free at the start,
  140–142 MB from the first cycle on; v2 132–136 MB).
* All disconnects came from the planned wifi restarts; the clients came back each time.
* The RX I/Q calibration (866) stayed good all day: residual image rejection 42–70 dB on all
  three receive chains of both routers (uncompensated: 25–44 dB), no drift. Scans on the v2
  left the stored calibration of the operating channel in place.
* The lowest values were short dips that hit the whole channel and were gone the next cycle.
* Both clients uploading at the same time: R6400 v2 7–17 vs DL-WRX36 70–99 Mbit/s (see *Known
  limitations*).

## Traffic in both directions

When a client uploads and downloads at the same time (a backup while streaming), the
download from the R6400 used to drop to a few Mbit/s while the upload kept ~100: the router
fills most of its turns on the air with the small TCP acknowledgements of the upload, while
the client fills its own turns with large frames. Letting the router send for up to 2 ms
per turn (best effort TXOP, `tx_queue_data2_burst`) shares the air much more evenly. The
b43 firmware honours it; OpenWrt only sets it by default for 5 GHz 802.11ac access points.

The wifi-scripts patch makes 2.0 ms the default for b43 radios in 802.11n mode. An explicit
`option tx_queue_data2_burst` in the `wifi-device` section of `/etc/config/wireless` still
overrides it (`'0'` switches it off). Without the patch (e.g. on an image you did not build
yourself) add `option tx_queue_data2_burst '2.0'` there and run `wifi`.

Measured with an upload and a download to the same client at once (Mbit/s, up / down):

| | without | with the burst |
|---|---|---|
| R6400 v2 (Rosen Penev's series), client DL-WRX36 | 77–80 / 17–20 | 68 / 32 |
| R6400 v1 (his series + 863), client DL-WRX36 | 58–66 / 35–44 | 46–59 / 45–58 |
| R6400 v2, rc8 | 101–103 / 3.3–5.1 | 89–94 / 15–19 |
| R6400 v1, rc8 | 82–90 / 10–17 | 72–78 / 28–31 |

Single direction speeds and the ping during a download stayed the same, and a third client
did not wait longer (during traffic both ways its ping went down).

## As a client: uploading next to other clients

When an R6400 is the client of another access point (a repeater or a client bridge) and
uploads while another client uploads to the same access point, it gets only a small share of
the air, although each sends about 100 Mbit/s alone. The access point tells its clients how
long they may send per turn (best effort TXOP), and OpenWrt's default is 0: one A-MPDU per
turn. b43 keeps to that and contends for the air again before every A-MPDU. The DL-WRX36
(ath11k) next to it sends several A-MPDUs per turn anyway, so it wins most of the time.

Letting the clients send for up to 3 ms per turn evens this out. It is set **on the access
point**, not on the R6400: add to the `wifi-device` section of its 2.4 GHz radio in
`/etc/config/wireless` (94 × 32 µs = 3 ms) and run `wifi`:

```
	list hostapd_options 'wmm_ac_be_txop_limit=94'
```

Measured with an R6400 v1 (b43 client) and a DL-WRX36 uploading at once to an R6400 v2 access
point (Mbit/s; the access point was set back to 0 afterwards and measured again):

| access point allows per turn | R6400 alone | together: R6400 / DL-WRX36 |
|---|---|---|
| 0 (default) | 100–103 | 14–20 / 81–89 |
| 3 ms | 104–109 | 27–30 / 72–76 |

The total stayed the same. Every client of that access point may then hold the air for up to
3 ms per turn, so under load the others can wait a little longer (video traffic already gets
3 ms by default). Tested on an OpenWrt snapshot; `hostapd_options` may be missing in older
releases, and other routers may offer this as a WMM setting.

## Interrupt balancing (irqbalance)

Install and enable **irqbalance**. The R6400 has two CPU cores, but OpenWrt does not spread
interrupts on this target (bcm53xx): Ethernet and the b43 radio are both handled by core 0,
and core 1 gets none (checked on an R6400 v2). On the Linksys EA6900, the same SoC family
with the same kernel, a busy 5 GHz radio left so little time on core 0 for the 2.4 GHz radio
that its receive ring overflowed: for 30 to 90 seconds it acknowledged nothing, so clients
that checked the link disconnected, while the beacons kept going out. irqbalance spreads the
interrupts over both cores.

The package comes disabled, so enable it after installing:

```sh
apk add irqbalance            # OpenWrt 24.10: opkg update && opkg install irqbalance
uci set irqbalance.irqbalance.enabled='1'
uci commit irqbalance
service irqbalance restart
```

Check with `cat /proc/interrupts` after some traffic: the b43 and Ethernet lines should no
longer all count on CPU0 only. When building your own image, select `irqbalance` (Utilities)
and add the `uci set` line in a uci-defaults file.

## Test images (GitHub Releases)

Ready-made OpenWrt images with rc15 are attached to the release **b43-80211n-rc15**
(OpenWrt snapshot r38137-a4076a8021, kernel 6.18.60, b43 firmware 784.2). Pick the image by the router's board ID:

| Router | board ID | Image |
|---|---|---|
| R6400 v1 | U12H332T00_NETGEAR | `openwrt-r6400-v1-b43-80211n-rc15-squashfs.chk` |
| R6400 v2 | U12H332T20_NETGEAR | `openwrt-r6400-v2-b43-80211n-rc15-squashfs.chk` |
| R6400 v2 (OTP) | U12H332T30_NETGEAR | `openwrt-r6400-v2-otp-b43-80211n-rc15-squashfs.chk` |

On OpenWrt the board ID is shown by `strings /dev/mtd1 | grep board_id` (the `nvram` partition).
Netgear's own firmware only accepts a `.chk` with the router's own board ID. The **R6700 v3**
has the hardware of the R6400 v2 but board ID U12H332T77_NETGEAR, so none of these images
installs on it from Netgear's firmware (one already running OpenWrt can sysupgrade to the v2
image). Untested.

Install: from Netgear's firmware, upload the `.chk` in the web interface (Advanced →
Administration → Router Update); from OpenWrt, `sysupgrade -v <image>.chk`. Check the SHA-256
sums first. Have a way back (Netgear's TFTP/nmrp recovery): this is a test version.

**Upgrading with settings kept from an older OpenWrt:** a wireless configuration made with stock
b43 has no `htmode` for the 2.4 GHz radio, and the radio then stays 802.11g. Check with
`uci show wireless` and set it once:

```sh
uci set wireless.radio0.htmode='HT20'; uci commit wireless; wifi
```

**Upgrading from rc9 to rc15:** nothing to change; the settings stay valid. The image brings
firmware 784.2 along. A b43 module built for rc11 or rc12 does not fit rc13 or rc15 and the other
way round (880 changes the kernel's SPROM structure): flash the image instead of copying a module.
From rc13 to rc15: if `/etc/modules.d/b43` sets `ht_txgain_idx`, remove it (892 is gone; the kernel
ignores it with an `unknown parameter` warning). For more SSIDs, add `wifi-iface` sections on the 2.4 GHz radio without a
`macaddr` option; a `macaddr` set by hand for a further SSID must lie in the same block of four as
the other further SSIDs, or that SSID gets no frames (b43 logs `gets no frames: outside the BSSID
block`).

**Upgrading from rc8 with settings kept:** the rc8 module parameters are gone (see *Module
parameters*); remove them from `/etc/modules.d/b43`, which should hold just `b43`.

## Building

You need an OpenWrt main build tree for the bcm53xx target (R6400 v1 and v2 support is in
OpenWrt main since 2026-11-01). rc15 was built on OpenWrt main r38137-a4076a8021 (kernel 6.18,
mac80211 backports 7.2).

1. Take Rosen Penev's series, openwrt/openwrt#25922 at 87e30600fa (18 commits on OpenWrt main
   89e69d9391):

   ```sh
   cd <openwrt>
   git fetch https://github.com/openwrt/openwrt pull/25922/head
   git checkout -b b43-rc15 87e30600fa
   ```

   If his PR has moved on since, our patches may no longer apply on top of it; use this commit.
   (The rc15 images were built on r38137 with his files copied in: `patches/brcm/`,
   `broadcom.mk` and `target/linux/generic/pending-6.18/805-*`; the b43 code is the same.)

2. Copy our mac80211 patches next to his, and apply the wifi-scripts patch:

   ```sh
   cp <this repo>/b43-80211n/patches/89*.patch package/kernel/mac80211/patches/brcm/
   git apply <this repo>/b43-80211n/patches/wifi-scripts-b43-best-effort-frame-bursting.patch
   ```

   And the kernel patches, and the dependency that builds hostapd with 802.11ac (only needed for
   5 GHz tests with an AC-PHY module):

   ```sh
   cp <this repo>/b43-80211n/patches/kernel/*.patch target/linux/bcm53xx/patches-6.18/
   sed -i '/define KernelPackage\/b43$/,/^endef/s/+@KERNEL_PAGE_POOL \\$/+@KERNEL_PAGE_POOL +@DRIVER_11AC_SUPPORT \\/' package/kernel/mac80211/broadcom.mk
   ```

   If you use `patch` for anything on a newer OpenWrt, add `--no-backup-if-mismatch`: a stray
   `02_network.orig` in `target/linux/bcm53xx/base-files` ends up in the image and shows the LAN
   ports twice in LuCI.

   In a tree that was built before, rebuild the kernel and mac80211 from scratch, since 880
   changes a structure the b43 module reads:
   `make target/linux/clean package/kernel/mac80211/clean package/network/services/hostapd/clean`.

3. Select b43 (`make menuconfig`): Kernel modules → Wireless Drivers → `kmod-b43`; b43 options:
   bus BCMA, PHY type **HT**, firmware **6.30.163.46** (ucode 784.2, the default since his
   update; the older firmware choices are gone). With firmware squashing on, keep core rev 29
   and PHY type HT in the lists.

4. Build the image (`make -j$(nproc)`) and flash it, or build only the module:

   ```sh
   make package/kernel/mac80211/{clean,compile} -j$(nproc)
   ```

   The module is
   `build_dir/target-*/linux-bcm53xx_generic/mac80211-regular/backports-*/ipkg-*/kmod-b43/lib/modules/<kernel>/b43.ko`.
   Copying a module onto a router only works if the router runs an image from the **same** build
   tree (same kernel and backports); otherwise flash the image.

No b43 configuration is needed: the defaults are the tested settings. Do enable irqbalance
(see *Interrupt balancing*).

## Module parameters

Upstream does not want new module parameters, and Rosen Penev's series has none: the rc8
parameters (`ht`, `ht_tx_streams`, `ht_txcore`, `ht_sgi`, `ampdu_*`, `ht_cck_rx`, …) are all
gone. 802.11n, two streams, aggregation and the short guard interval are always on; CCK
(802.11b) reception is off only when the network uses no 802.11b rates (the OpenWrt default)
and stays on while scanning.

These patches add no b43 parameter (rc13's `ht_txgain_idx`, patch 892, is gone, see *Transmit
power*). The standard b43 parameters (`qos`, `nohwcrypt`, `hwtkip`, `btcoex`, `hwpctl`, `verbose`,
`pio`, `gpiomask`, `bad_frames_preempt`, `allhwsupport`, `fwpostfix`) are unchanged.

Set parameters on one line in `/etc/modules.d/b43` and reboot (OpenWrt reads this file only at
boot), e.g. `echo "b43 verbose=3" > /etc/modules.d/b43`. Check the values in use with
`grep . /sys/module/b43/parameters/*`.

## Transmit power

On boards with an external front end the BCM4331 sends with a fixed transmit gain instead of
the hardware power control loop, which drove the external amplifiers into distortion: index
24 on the **R6400 v1** (`BFL_HGPA`) and 16 on the **R6400 v2** (`BFL_FEM`), chosen from the
SPROM board flags (Rosen Penev's 830, based on our rc8 patch 824). A higher index is less
power.

rc13's `ht_txgain_idx` (patch 892) could override that choice; rc15 does not have it, because
upstream does not want new module parameters and Rosen Penev's series has none. It may come back
in a later version. Until then rc15 always uses the automatic index.

## Reporting problems

Please include:

```sh
logread | grep -iE "b43|ieee80211" | tail -100
iw dev <wifi interface> station dump
```

and what the clients were doing (download/upload, which device, which channel). With
`verbose=3` in `/etc/modules.d/b43` b43 also logs the transmit gain, the CCK reception
switch and the RX I/Q calibration result (`RX I/Q comp …`). It also turns on b43's
`PHY transmission error` message, which then shows up dozens of times per 30 s while a client
uploads, with rc9 as with rc10 and rc11: it is not a new fault and does not lower the speed.

`tx failed` in the station dump counts send attempts that got no acknowledgement, not lost
frames: most of those get through when they are sent again.

## Known limitations

* 20 MHz only (no 40 MHz). The R6400's BCM4331 is 2.4 GHz only.
* The transmit power setting of LuCI and `iw` does not lower the fixed gain on the R6400, and rc15
  has no other way to do it (see *Transmit power*).
* Several SSIDs: one channel and one beacon interval for all; the further SSIDs' beacons go out on
  the voice queue; their broadcast and multicast frames are encrypted in software; the block acks
  carry the first SSID's address (receive aggregation on a further SSID was only tested with an
  ath11k station).
* Two clients uploading at the same time do not share the air evenly: an R6400 v2 as a client
  got 7–17 Mbit/s next to an ath11k client's 70–99. Each alone gets ~100. Not investigated
  yet; it is between the clients, not in the access point.
* 893 calibrates the operating channel once per start of the radio (about 25 ms); the channels
  a scan visits run uncompensated, as before. At 5 GHz (other BCM4331 boards) the
  compensation stays at zero, as in stock b43.
* The b43 receiver reports the signal about 17–20 dB too high (no RSSI calibration in b43's
  HT-PHY code).
* With CCK (802.11b) reception off, the access point does not hear the 1 Mbit/s probe requests
  that phones send while scanning, so it never answers them. Phones then see the network only
  when they catch a beacon, and in a scan list or a WiFi analyzer app it comes and goes.
  Connecting is not affected. Enabling 802.11b rates (`option legacy_rates '1'` on the radio)
  turns CCK reception back on and the network answers probe requests again, but it brings back
  some of the lost client frames (on channel 11: 3.5 % of first attempts retried instead of 1.9 %).
  The open-source B-PHY registers offer no detection threshold to keep CCK on for nearby
  stations only.

## Credits

Rosen Penev (@neheb) for openwrt/openwrt#25922, the base of rc9 to rc15, which includes
several of our earlier patches. Ville Takio for the multi-AP change for the AC-PHY cores that
897 is based on. The openwrt-ai review of his PR for the point fixed in 890.
Alessio Ferri (aleferri) for 880, from his AC-PHY port of b43, aleferri/b43-ac-wip.

## License

GPL-2.0, like the b43 driver. Where every patch comes from, and how the information was
obtained, is documented in [PROVENANCE.md](PROVENANCE.md).
