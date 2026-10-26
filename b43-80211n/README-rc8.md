# b43: 802.11n with A-MPDU for the BCM4331 (Netgear R6400) — TEST VERSION (rc8)

> **Status: test version.** These patches work well on the author's Netgear R6400 v1
> (many hours of soak tests, three clean overnight tests with two clients and a phone, daily use);
> the R6400 v2 has been tested as a client (overnight) and as an access point (a 10-hour soak test with rc8). They are not in OpenWrt or the Linux kernel.
> Please test and report back (see *Reporting problems*), and read *Known limitations* first.

The 2.4 GHz radio of the Netgear R6400 is a **Broadcom BCM4331** (HT-PHY, "b43" driver).
Stock b43 runs it as 802.11g only, with a weak receiver and a distorted transmitter:
about 10–12 Mbit/s download. These patches fix several b43 bugs and add 802.11n
(HT20, two transmit streams) with A-MPDU aggregation in both directions.

| Netgear R6400 v1, 2.4 GHz, 20 MHz (iperf3 TCP) | download (router → client) | upload (client → router) |
|---|---|---|
| stock b43 (802.11g) | 10–12 Mbit/s | 20–22 Mbit/s |
| front-end + TX gain fixes (802.11g) | 21–22 Mbit/s | 19–21 Mbit/s |
| this series, one transmit stream (rc4) | ~49 Mbit/s | ~80 Mbit/s |
| **this series, two transmit streams (rc5–rc8)** | **~85–90 Mbit/s** | **~90–105 Mbit/s** |

Phone (Samsung S25 FE) link rates with this series: up to 144.4 Mbit/s in both directions
(MCS 15, short GI).

## Hardware

* **Netgear R6400 v1** (BCM4709 + BCM4331, external high-gain PA): tested.
* **Netgear R6400 v2** (BCM4331 with FEM): tested as a client of an R6400 v1 (four overnight
  tests; ~90 Mbit/s each way with rc5); as an access point in a 10-hour soak test with rc8
  (~99 Mbit/s download, ~108 Mbit/s upload to an ath11k client).
* Other BCM4331 boards: patches 820/821 (DMA) and 823 (table reads) are generic b43
  fixes; 822 and 824 act only on boards with the matching front-end flags. Untested elsewhere.
* **BCM4360 (AC-PHY) is not supported** — neither by stock b43 nor by these patches. That is the
  5 GHz radio of the R6400 and both radios of the Netgear R7000; b43 reports
  `FOUND UNSUPPORTED PHY (Analog 12, Type 11 (AC))` for it. Only the generic DMA fixes
  (820, 821) would also matter for a future BCM4360 b43 driver.

## The patches

Apply in this order (OpenWrt applies them by number).

| Patch | What it does |
|---|---|
| 820 | DMA: map RX buffers bidirectionally so b43's RX poison works on non-coherent ARM |
| 821 | DMA: drop RX frames spanning several buffers without losing ring sync |
| 822 | HT-PHY: BCM4331 external front end with analog PA control (external LNA/PA lines); **rewritten in rc7** from open sources and measurements, see [PROVENANCE.md](PROVENANCE.md) |
| 823 | HT-PHY: read 32-bit PHY table entries low half first |
| 824 | HT-PHY: static TX gain instead of the TX power control loop, on boards with an external front end (BFL_FEM or BFL_HGPA) |
| 825 | HT-PHY: 802.11n HT20, MCS 0–7 (one TX stream), RX block-ack sessions |
| 826 | HT-PHY: fill in the transmitter address of the BlockAck template |
| 827 | HT-PHY: A-MPDU TX aggregation with block-ack window tracking |
| 828 | HT-PHY: short guard interval at 20 MHz |
| 829 | HT-PHY: RTS/CTS in front of A-MPDUs (only for re-sends by default) |
| 830 | AP mode: hold frames for clients in power save |
| 831 | HT-PHY: fill in the Duration field of 802.11n frames |
| 832 | HT-PHY: use a 256-slot RX ring |
| 833 | HT-PHY: receive CCK only when the BSS uses it |
| 834 | HT-PHY: take frames from the mac80211 TXQs when there is room (airtime fairness) |
| 835 | HT-PHY: one rate control status per A-MPDU (based on work by Rosen Penev, openwrt/openwrt#25922) |
| 836 | HT-PHY: send two spatial streams (MCS 8–15), **on by default since rc5** — see *Two transmit streams* |
| 837 | BCM4331: give the VI and VO TX FIFOs room, one hardware queue per WMM access category |
| 838 | HT-PHY: send frames again at a lower rate after two failures (multi-rate retry) |
| 839 | encrypt robust management frames in software, needed with WPA3/PMF — **patch by Rosen Penev**, from openwrt/openwrt#25922, unchanged |

Changes since rc7:
* 824 only acts on boards whose SPROM board flags show an external front end (BFL_FEM or
  BFL_HGPA), the same check as in Rosen Penev's openwrt/openwrt#25922. On the R6400 nothing
  changes: index 24 on the v1, 16 on the v2. The module parameter `ht_txgain_idx` is gone (see
  *Transmit power*).
* 827: the radio hang detector no longer restarts the radio of an idle access point on a quiet
  channel. It now also watches the CRS glitch counter, which a working receiver keeps counting
  when no frames arrive. The firmware's header format is checked after the firmware upload,
  when it is known.
* The other patches are unchanged in code; some differ in line offsets or context lines.

Changes since rc6: 822 is rewritten. It now rests only on open sources and on measurements of the
hardware, not on decompiled Broadcom code (see [PROVENANCE.md](PROVENANCE.md)); it sets the same
hardware state as before, so nothing changes in use. 824, 833 and 839 differ only in line offsets;
the other patches are unchanged. Since rc5: 839 is new (with WPA3 or PMF the router set up no send
aggregation without it). Since rc4: 836 changed (two streams on by default), 837 and 838 new.

### Bugs found and fixed

| # | Problem | Cause | Fixed in |
|---|---|---|---|
| 1 | Receiver deaf on the R6400 v1 (-75 dBm where -48 is right) | b43 never configured the BCM4331's external front end (LNA/PA control lines, RF sequencer) | 822 |
| 2 | Corrupted TX gain word | HT-PHY 32-bit table reads took the high half first; the PHY latches on the low half | 823 |
| 3 | Distorted TX, download halved | The TX power control loop drives the external PA into compression | 824 |
| 4 | Download 2.3 Mbit/s once RX aggregation is on | Block acks were sent with transmitter address 00:00:00:00:00:00: b43 never wrote its MAC into the BA template | 826 |
| 5 | Video/voice traffic stuck | The BCM4331's VI and VO hardware TX FIFOs are too small in the firmware's initial layout (11 and 9 blocks of 256 bytes): a frame placed there is never sent | 827 worked around it (all traffic via the best-effort queue); 837 fixes it (VI/VO FIFOs enlarged, the way brcmsmac programs them) |
| 6 | Router hang ("reboot -f" blocked) | RX of a frame spanning several buffers left the ring pointer one slot too far: permanent ring desync | 821 |
| 7 | Frames larger than one RX buffer (A-MSDU 3839/7935 bytes from HT clients) | Not handled safely (triggered bug 6) | 821 |
| 8 | Garbage RX "frames", wifi dropouts, ring desync | RX buffers mapped DMA_FROM_DEVICE: on non-coherent ARM the RX poison never reached memory, skipped buffers were read as stale data | 820 |
| 9 | Phones with the screen off lose frames under load (46 % ping loss) | No power-save handling: frames already queued in the driver went to a dozing client and were dropped after the retries | 830 |
| 10 | Other stations did not reserve time for the acknowledgement of 802.11n frames | Duration field 0 in every MCS frame: mac80211 leaves it to the driver for MCS rates | 831 |
| 11 | Frames lost although the sender got an ACK; a phone in power save unreachable for ~26 s under load | The firmware ACKs a frame before it is in host memory and drops it when the 32-slot RX ring is full, which A-MPDU bursts caused about three times per second | 832 |
| 12 | Receiver "deaf" to 13–16 % of its clients' frames on a quiet channel, at any signal level and rate | The receiver locks onto every CCK (802.11b) frame it detects, also a weak 1 Mbit/s broadcast of a distant network (~2 ms), and misses a much stronger frame of its own clients that starts meanwhile (90 % lost then, 2 % otherwise) | 833 (CCK reception off when the network uses no CCK rates, the OpenWrt default) |
| 13 | Phones in power save slow under load (0.4–1.5 s pings), stations not served in turn | b43 let mac80211 push all frames into one shared driver queue (100–270 frames): a waking phone's frames waited behind another station's traffic and the phone dozed off again | 834 |
| 14 | Rate control kept a rate at which most aggregates failed (two streams: 9–23 instead of 70–80 Mbit/s for minutes) | Only the frames that got through were reported to rate control; frames sent again were never reported | 835 |
| 15 | A client could stop receiving for good after many failed frames | Frames waiting to be sent again count as pending airtime for mac80211's airtime queue limit (AQL); above the limit mac80211 no longer hands out that client's queue, so they were never sent | 834 (rc4) |
| 16 | Frames sent up to six times at a rate the client could not take at that moment (a phone that briefly receives only one stream), then given up | Frames sent again always used rate control's first choice | 838 |
| 17 | With WPA3 or PMF switched on: no send aggregation, ~20 instead of 85–90 Mbit/s, pings up to 1–2 s | b43 announces management frame protection, but the hardware encrypts protected management frames like data frames, so the block-ack setup (ADDBA) never arrives | 839 (Rosen Penev) |

### Improvements added

| Improvement | Effect | Patch |
|---|---|---|
| 802.11n HT20, MCS 0–7, receive MCS 0–15 | 20 Mbit/s → 802.11n rates, clients may send on two streams | 825 |
| RX A-MPDU (block-ack sessions) | upload 22 → 45 Mbit/s | 825, 826 |
| TX A-MPDU (up to 16 frames) | download 20 → 46, upload 45 → 75 Mbit/s | 827 |
| Block-ack window tracking (as ath9k) | no frames lost when a block ack is missed | 827 |
| Short guard interval | +7 % download, +10 % upload | 828 |
| RTS/CTS for re-sent aggregates, at a basic OFDM rate | no frames given up under collisions, same throughput | 829 |
| Watchdog / hang check, debugfs counters | self-recovery, diagnosis | 827 |
| Power save in AP mode (as ath9k): frames held, TIM bit set, delivered on wake-up, PS-Poll or uAPSD trigger | phone with the screen off under load: 0 % ping loss (was 46 %) | 830 |
| CCK reception only when the network uses CCK rates | client frames ACKed at the first attempt 86 → 99 %; TCP to/from a client 49.6 → 53.7 / 85.2 → 93.7 Mbit/s | 833 |
| Airtime fairness: frames taken from mac80211's per-station queues only when the hardware has room, airtime reported, AQL | phone in power save under load: same latency as without load (~0.3 s instead of up to 1.5 s); two UDP downloads get equal airtime | 834 |
| One rate control status per aggregate, frames sent again at the current rate | rate control falls back when a rate stops working | 835 |
| Two transmit streams, MCS 8–15 (default since rc5; `ht_tx_streams=1` for one) | download 50 → 85–90 Mbit/s to two-stream clients | 836 |
| WMM priority: one hardware queue per access category | video 10 → 56 Mbit/s; a voice-class download next to a best-effort one gets 32.5 Mbit/s (was 5.5); a WhatsApp call stayed clean under full load | 837 |
| Multi-rate retry for frames sent again | with a phone that at times cannot take two-stream frames: through within 3 sends instead of 6, slowest frame 19.5 → 5.2 ms, frames given up 10 → 0 in 5 minutes; throughput unchanged | 838 |

## Test results

Overnight tests: R6400 v1 as access point, two clients that take turns and also load it
together: an R6400 v2 (on the same version) and a Qualcomm IPQ8074 router (ath11k), plus a
phone in power save (screen off). rc2: 15 hours, 144 cycles; rc4: 12.7 hours, 123 cycles,
one transmit stream; rc5: 14.2 hours, 137 cycles, two transmit streams (the rc5 default).
iperf3 TCP in Mbit/s, averages (R6400 v2 / IPQ8074):

| Phase | rc2 | rc4 | rc5 |
|---|---|---|---|
| R6400 v2 download alone | 43.2 | 49.4 | 89.8 |
| R6400 v2 upload alone | 42.2 | 50.2 | 91.9 |
| both download | 5.4 / 44.2 | 12.5 / 38.7 | 36.9 / 46.9 |
| R6400 v2 download, IPQ8074 upload | 10.4 / 63.2 | 4.1 / 89.0 | 4.4 / 99.8 |
| R6400 v2 download + upload at once | 40.8 down / 2.8 up | 32.2 down / 17.9 up | 55.8 down / 40.8 up |
| phone ping while the R6400 v2 downloads: runs with 0 % loss | 138 of 142 | 122 of 122 | 136 of 136 |
| phone ping while the R6400 v2 downloads: average | 0.37 s | 0.35 s | 0.32 s |
| frames given up (access point / client) | 1381 / 801 | 58 / 18 | 192 / 0 |
| block-ack window resets (access point) | 5 | 0 | 0 |

Access point: no stalls, no hangs, no RX ring errors, no reboot, memory stable, in all three.
The R6400 v2 client had one TX stall of about one second that recovered by itself, on rc4 and
on rc5. The 192 frames given up on rc5 are out of 17 million aggregates.

rc8 (R6400 v2 as access point, HT20 channel 9, an IPQ8074 router (ath11k) as client, plus a
phone now and then): 10.3 hours, 18 load runs of 60 s download and 60 s upload every 30 minutes.
Download 92–101 Mbit/s, upload 106–110 Mbit/s, link MCS 15 short GI. 14.6 million frames in
991,000 aggregates; 76 frames given up; no stalls, hangs, block-ack window resets or receive
errors; memory stable. The R6400 v1 uses the same gain index as with rc7 (24); rc8 was not
soak-tested on it.

rc7 changes only patch 822 (see *The patches*). On both routers it leaves exactly the hardware
state of the rc6 version, also from a cold start, and a 100-minute soak test (R6400 v1 access point,
R6400 v2 client, both on rc7's 822) gave the same results as rc5/rc6: 89.5 / 92.2 Mbit/s, no
stalls, hangs or receive errors.

rc6 is rc5 plus patch 839. With PMF switched on (`ieee80211w` 1 or 2), rc5 set up no send
aggregation: R6400 v2 download/upload 23/20 Mbit/s, pings up to 2.2 s, and the block-ack setup
to a phone was retried without end. With 839: 85.5/91.4 Mbit/s, block-ack sessions in both
directions to the R6400 v2 and to the phone. Without PMF, 839 changes nothing (85.3/90.9 Mbit/s). The phone's
latency under load (~0.35 s) is what it shows without load: it is the phone's power save.
The uneven numbers when both clients are busy, and the R6400 v2's weak upload under load,
are described under *Known limitations*.

## Test images (GitHub Releases)

Ready-made OpenWrt images with this series are attached to the release **b43-80211n-rc8**
(OpenWrt snapshot r37507-4e16c2ed8f, kernel 6.18). Pick the image by the router's board ID:

| Router | board ID | Image |
|---|---|---|
| R6400 v1 | U12H332T00_NETGEAR | `openwrt-r6400-v1-b43-80211n-rc8-squashfs.chk` |
| R6400 v2 | U12H332T20_NETGEAR | `openwrt-r6400-v2-b43-80211n-rc8-squashfs.chk` |
| R6400 v2 (OTP) | U12H332T30_NETGEAR | `openwrt-r6400-v2-otp-b43-80211n-rc8-squashfs.chk` |

On OpenWrt the board ID is shown by `strings /dev/mtd1 | grep board_id` (the `nvram` partition).
Netgear's own firmware only accepts a `.chk` with the router's own board ID.

The **R6700 v3** has the same hardware as the R6400 v2 but board ID U12H332T77_NETGEAR: none of these
images matches it for a first install from Netgear's firmware (an R6700 v3 already running OpenWrt can
sysupgrade to the v2 image). Untested.

Install: from Netgear's firmware, upload the `.chk` in the web interface (Advanced → Administration →
Router Update); from OpenWrt, `sysupgrade -v <image>.chk`. Check the SHA-256 sums first. Have a way back
(Netgear's TFTP/nmrp recovery) — this is a test version.

**Upgrading with settings kept from an older OpenWrt:** a wireless configuration made with stock
b43 has no `htmode` for the 2.4 GHz radio, and the radio then stays 802.11g. Check with `uci show wireless`
and set it once:

```sh
uci set wireless.radio0.htmode='HT20'; uci commit wireless; wifi
```

The images contain LuCI (HTTPS), WireGuard, OpenVPN, pbr, https-dns-proxy, watchcat, Wake-on-LAN,
tcpdump, USB storage (incl. NTFS), curl, `iperf3`, `htop`, the full `iw`, `iputils-ping`,
GNU `timeout`, `nvram` and an SFTP server (plain `scp` works). The b43 module needs no configuration.
Kernel modules from the OpenWrt package repository will not install on these images (custom kernel
build); other packages usually do.

## Building

You need an OpenWrt build tree for the bcm53xx target with the R6400 supported
(R6400 support is being upstreamed; see the other folders of this repository for the
device patches). Tested with OpenWrt main (kernel 6.18, mac80211 backports 7.2).

1. Copy the patches into the mac80211 package:

   ```sh
   cp patches/8*.patch <openwrt>/package/kernel/mac80211/patches/brcm/
   ```

2. Make sure b43 is selected (`make menuconfig`):
   * Kernel modules → Wireless Drivers → `kmod-b43`
   * b43 options: bus BCMA, PHY type **HT**, firmware **5.100.138** (contains ucode 666.2 for the BCM4331)

3. Build the image (`make -j$(nproc)`) and flash it, or build only the module:

   ```sh
   make package/kernel/mac80211/{clean,compile} -j$(nproc)
   ```

   The module is `build_dir/target-*/linux-bcm53xx_generic/mac80211-regular/backports-*/ipkg-*/kmod-b43/lib/modules/<kernel>/b43.ko`.
   Copying a module onto a router only works if the router runs an image from the **same**
   build tree (same kernel and backports); otherwise flash the image.

No configuration is needed: the defaults are the tested settings.

## Module parameters

### How to change them

**Permanently:** put them on one line in `/etc/modules.d/b43` and reboot. OpenWrt reads this
file only at boot; `modprobe` ignores parameters given on the command line.

```sh
echo "b43 ht_tx_streams=1 ampdu_rts=1" > /etc/modules.d/b43   # the file normally holds just "b43"
reboot
```

**Without a reboot (until the next reboot):** the parameters marked *live* or *wifi* in the
table below can be written in `/sys/module/b43/parameters/`. *Live* takes effect for the next
frame; for *wifi*, restart the wireless afterwards with `wifi`. Parameters marked *boot* only
change through `/etc/modules.d/b43` and a reboot.

```sh
echo 1 > /sys/module/b43/parameters/ampdu_rts      # live
```

**Check** the values in use: `grep . /sys/module/b43/parameters/*`.

### 802.11n parameters (these patches)

| Parameter | Default | Values | Effect | Patch |
|---|---|---|---|---|
| `ht` | 1 | 1 = 802.11n HT20, 0 = 802.11g only | boot | 825 |
| `ht_tx_streams` | 2 | 1 = one transmit stream (MCS 0–7), 2 = two streams (MCS 0–15); see *Two transmit streams* | boot | 836 |
| `ht_txcore` | 1 | transmit core mask for one-stream frames, 1–7 (1 = core 0) | live | 825 |
| `ht_txcore2` | 3 | transmit core mask for two-stream frames: 3 (cores 0 + 1), 5 (0 + 2) or 6 (1 + 2) | live | 836 |
| `ht_sgi` | 1 | announce the short guard interval to clients (1) or not (0) | boot | 828 |
| `ht_sgi_tx` | 1 | send with the short guard interval when rate control picks it (1) or never (0) | live | 828 |
| `ht_rx_ampdu` | 1 | accept block-ack sessions from clients, i.e. receive aggregates (1) or refuse them (0) | wifi | 825 |
| `ht_tx_ampdu` | 1 | send aggregates (A-MPDU) (1) or single frames only (0) | boot | 827 |
| `ampdu_max_frames` | 16 | most frames per aggregate, 1–16 | live | 827 |
| `ampdu_inflight` | 2 | aggregates handed to the hardware per queue before waiting for its status, 1 or 2; see *Low jitter* below | live | 827 |
| `ampdu_rts` | -1 | RTS/CTS in front of aggregates: -1 = only when an aggregate is sent again, 1 = always, N > 1 = for aggregates of N bytes or more, 0 = never | live | 829 |
| `ampdu_retry_mrr` | 1 | frames sent again: from the second re-send on at rate control's most reliable rate (1), or always at its first choice (0, the rc4 behaviour) | live | 838 |
| `ht_txq_pull` | 1 | airtime fairness: take frames from mac80211's per-client queues when the hardware has room (1), or the old single driver queue (0) | boot | 834 |
| `ht_qos_fifos` | 1 | one hardware transmit queue per WMM class, so voice and video get priority (1), or all traffic in the best-effort queue (0, the rc4 behaviour) | boot | 837 |
| `ht_cck_rx` | -1 | receive CCK (802.11b) frames: -1 = only when the network uses 802.11b rates (`legacy_rates 1`), 0 = never, 1 = always | wifi | 833 |
| `ampdu_dbg` | 0 | debugging: log the next N aggregates and their status reports to the kernel log (very noisy) | live | 827 |

Leave these at their defaults unless you are testing something; the defaults are the
settings that were measured best on the R6400 v1 and v2.

**Low jitter.** With the default `ampdu_inflight=2` a client waiting behind another
client's download usually sees 5–10 ms, but now and then 50–150 ms. With
`ampdu_inflight=1` it never waited more than about 20 ms in our tests, at the cost of
about 20 % throughput for a single download (R6400, two streams: ~89 → ~72 Mbit/s).
Use 1 if calls or games matter more than the top download speed:
`echo 1 > /sys/module/b43/parameters/ampdu_inflight` (live), or add `ampdu_inflight=1`
to `/etc/modules.d/b43` to keep it after a reboot.

**Traffic in both directions: set a 2 ms burst.** When a client uploads and downloads at
the same time (a backup while streaming, a big upload while browsing), the download from
the R6400 can drop to a few Mbit/s while the upload keeps 100. The R6400 sends at most 16
frames per turn on the air and most of them are the small TCP acknowledgements of the
upload; a busy client fills its own turns with large frames. Letting the router send for
up to 2 ms per turn fixes most of it. This is a wireless setting, not a module parameter:
in the `wifi-device` section of the b43 radio in `/etc/config/wireless` add

```
	option tx_queue_data2_burst '2.0'
```

and run `wifi`. Measured on the R6400 v2 (rc8 module, client a DL-WRX36, traffic routed
through the R6400, runs alternated with the default):

| | default | with the burst |
|---|---|---|
| upload + download at once | 101–103 / 3.3–5.1 Mbit/s | 89–94 / 15–19 Mbit/s |
| upload only | 106–108 | 108–109 |
| download only | ~100 | 108 |
| ping during a download | 7–8 ms | 7–8 ms |

On the R6400 v1 (same test) the download with traffic both ways went from 10–17 to
28–31 Mbit/s, and single-direction speeds and ping were unchanged.

A third client does not wait longer: its ping during another client's download stayed the
same, and during traffic both ways it went down (v1, rc8: average 14–16 → 11–12 ms, no
pings above 50 ms instead of a few). The burst gives the router a larger share of the
airtime; with a client that is itself slow to send, the balance can tip towards the
router's direction.

OpenWrt already uses this value by default for 5 GHz 802.11ac access points; for 2.4 GHz
it stays at 0.

### Standard b43 parameters

Unchanged by these patches; listed for completeness.

| Parameter | Default | Values | Effect |
|---|---|---|---|
| `qos` | 1 | WMM (QoS) on (1) or off (0); keep it on, 802.11n needs it | boot |
| `nohwcrypt` | 0 | 1 = encrypt and decrypt in software instead of in the hardware (slower; for testing) | boot |
| `hwtkip` | 0 | 1 = TKIP (old WPA1) in hardware | boot |
| `btcoex` | 1 | Bluetooth coexistence; the R6400 has no Bluetooth | boot |
| `hwpctl` | 0 | hardware power control of the old G-PHY chips; no effect on the BCM4331 (see *Transmit power*) | boot |
| `verbose` | 2 | kernel log detail: 0 = errors, 1 = warnings, 2 = info, 3 = debug | live |
| `pio` | 0 | 1 = programmed I/O instead of DMA (slow; debugging only, not tested with these patches) | boot |
| `gpiomask` | 15 | GPIO mask for the LED control (0x000F) | boot |
| `bad_frames_preempt` | 0 | 1 = Bad Frames Preemption | boot |
| `allhwsupport` | 1 | also drive chips that the brcmsmac driver supports | boot |
| `fwpostfix` | (empty) | load the firmware files with this postfix added to their names | boot |

## Two transmit streams

Patch 836 can send two spatial streams (MCS 8–15) to clients that receive two streams, as
most phones and laptops do. It is **on by default** since rc5 (in rc4 it was off). With two
streams two power amplifiers transmit at the same time, each at the gain used for one stream,
so the total output is about 3 dB higher on two-stream frames.

Results, 30 minutes of continuous download per setting, alternating an R6400 v2 (b43) and an
IPQ8074 client at close range (R6400 v1 as the access point):

| Setting | Download (v2 / IPQ8074) | SoC temperature |
|---|---|---|
| one stream, `ht_tx_streams=1` | 50 / 53 Mbit/s | 55.6 °C |
| two streams (default) | 89 / 84 Mbit/s | 56.9 °C |

No stalls or hangs; the case stayed lukewarm near the antennas. The R6400 v2 (no external
high-gain amplifiers) gave 53 → 70–83 Mbit/s with two streams.

Check:

```sh
cat /sys/module/b43/parameters/ht_tx_streams       # 2
iw dev <wifi interface> station dump | grep "tx bitrate"   # MCS 8-15 to two-stream clients
```

To go back to one stream, set the parameter in `/etc/modules.d/b43` and reboot (it is read
only when the module loads):

```sh
echo "b43 ht_tx_streams=1" > /etc/modules.d/b43
reboot
```

If the file already holds other parameters, add `ht_tx_streams=1` to that line instead.

### Transmit power

On the R6400 the BCM4331 sends with a fixed gain (patch 824): index 24 on the **R6400 v1**
(high-gain amplifier) and 16 on the **R6400 v2**, chosen from the board flags in the SPROM.
The hardware power control loop drove the external amplifiers into distortion and halved the
throughput. There is no setting for this gain, and the transmit power of LuCI and `iw` has no
effect. Check with `logread | grep "static TX gain"`.

Before rc8 a module parameter `ht_txgain_idx` set this gain. It is gone: if
`/etc/modules.d/b43` still holds it, remove it there (the kernel ignores it with a warning).

Rate control (patch 835) moves to a lower rate on its own when the two-stream rates do not
work; please report your results, with one and with two streams.

## Tools

Broadcom's `wl` utility does not work here: it talks only to Broadcom's own closed driver
(`wl.ko`, used by the stock firmware and DD-WRT). These images use b43, the open Linux
driver, which works with the standard Linux wireless tools.

**`iw`** (installed by default):

```sh
iw dev                                  # interface names (e.g. phy0-ap0), channel
iw dev <wifi interface> station dump    # per client: signal, tx/rx bitrate (MCS), tx failed
iw dev <wifi interface> link            # R6400 as a client: the access point, signal, rate
iw list                                 # what the chip supports
```

`tx failed` in the station dump counts send attempts of aggregates that got no block ack at
all, not lost frames: most of those frames get through when they are sent again.

**b43 settings:** `/sys/module/b43/parameters/`, see *Module parameters*.

**Counters** (debugfs, mounted by OpenWrt):

```sh
cat /sys/kernel/debug/ieee80211/phy*/b43_ampdu    # aggregation, drops, stalls, RX ring (see Reporting problems)
cat /sys/kernel/debug/ieee80211/phy*/netdev:*/stations/<client MAC>/rc_stats   # rate control table of one client
```

**Transmit power:** the BCM4331's HT-PHY does not use the transmit power setting of LuCI
or `iw dev <wifi interface> set txpower`; changing it has no effect, and the value `iw`
shows (e.g. "txpower 30.00 dBm") is not what the chip sends. The power is set by a fixed gain
(see *Transmit power*). This was already so in b43 before these patches.

## Reporting problems

Please include:

```sh
logread | grep -iE "b43|ieee80211" | tail -100
cat /sys/kernel/debug/ieee80211/phy*/b43_ampdu
iw dev <wifi interface> station dump
```

and what the clients were doing (download/upload, which device). `b43_ampdu` counters
(reset by writing anything to the file): `rx_garbage` must stay 0; `stalls` and `hangs`
should stay 0; `rx_uflow` (frames lost because the RX ring was full) should stay near 0;
an occasional `baw_reset` (a few per day) is a recovery and harmless.

## Known limitations

* Two transmit streams by default since rc5; `ht_tx_streams=1` goes back to one (see *Two
  transmit streams*). With two streams the top rate (MCS 15) works well at some times and not at
  others; rate control then uses MCS 13–14.
* 20 MHz only (no 40 MHz), 2.4 GHz only.
* The transmit power setting of LuCI and `iw` is ignored, and there is no setting to lower the
  power (see *Transmit power*).
* Airtime is shared fairly since patch 834 (two UDP downloads: equal airtime). With TCP, an
  R6400 used as a *client* still gets less than a modern client next to it (12 vs 39 Mbit/s),
  because it has a harder time sending its TCP acknowledgements; ordinary clients are not
  affected.
* Without patch 833 (and with 833 when 802.11b rates are enabled, `legacy_rates 1`), the
  receiver misses 13–16 % of its clients' frames: it locks onto weak 802.11b frames of
  neighbouring networks. Patch 833 turns CCK reception off when the network uses no CCK
  rates (the OpenWrt default); the router then does not answer 802.11b probe requests of
  scanning clients, which still find the network by its beacons.
* **Client (station) mode:** because of the point above, an R6400 used as a client of another
  R6400 sends slowly while the access point is busy with another client: ping times of
  0.2–2.4 s with rc2, avg 0.46 s and at most 1.05 s with patch 833 (measured before patch 834).
  Since rc2 its connections no longer stall (none in 15 hours), and without that other load
  it runs at ~42–51 Mbit/s. An ath11k client in the same position did not show this
  (72–84 ms). Prefer the R6400 as an access point.
* Power save: tested with a phone that wakes up fully to fetch its frames. Clients that use
  PS-Poll or uAPSD are handled by the code but have not been tested yet.

## Credits

Patch 839 is by Rosen Penev (@neheb), and 835 is based on his work: both come from his
openwrt/openwrt#25922, which brings 802.11n to the b43 N-PHY devices (e.g. the ASUS RT-N16).

## License

GPL-2.0, like the b43 driver. Based on b43, brcmsmac and ath9k (Linux kernel) and on
measurements against Broadcom's wl driver. Where every patch comes from, and how the
information was obtained, is documented in [PROVENANCE.md](PROVENANCE.md).
