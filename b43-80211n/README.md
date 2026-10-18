# b43: 802.11n with A-MPDU for the BCM4331 (Netgear R6400) — TEST VERSION (rc4)

> **Status: test version.** These patches work well on the author's Netgear R6400 v1
> (many hours of soak tests, two clean overnight tests with two clients and a phone, daily use);
> the R6400 v2 has been tested as a client, and as an access point with two streams. They are not in OpenWrt or the Linux kernel.
> Please test and report back (see *Reporting problems*), and read *Known limitations* first.

The 2.4 GHz radio of the Netgear R6400 is a **Broadcom BCM4331** (HT-PHY, "b43" driver).
Stock b43 runs it as 802.11g only, with a weak receiver and a distorted transmitter:
about 10–12 Mbit/s download. These patches fix several b43 bugs and add 802.11n
(HT20, one transmit stream by default, two optional) with A-MPDU aggregation in both
directions.

| Netgear R6400 v1, 2.4 GHz, 20 MHz (iperf3 TCP) | download (router → client) | upload (client → router) |
|---|---|---|
| stock b43 (802.11g) | 10–12 Mbit/s | 20–22 Mbit/s |
| front-end + TX gain fixes (802.11g) | 21–22 Mbit/s | 19–21 Mbit/s |
| **this series (802.11n, A-MPDU, SGI)** | **~49 Mbit/s** | **~80 Mbit/s** |

Phone (Samsung S25 FE) link rates with this series: 72.2 Mbit/s down (MCS 7, short GI),
144.4 Mbit/s up (MCS 15, short GI).

## Hardware

* **Netgear R6400 v1** (BCM4709 + BCM4331, external high-gain PA): tested.
* **Netgear R6400 v2** (BCM4331 with FEM): tested as a client of an R6400 v1 (two overnight
  tests, ~42 Mbit/s each way); as an access point not yet tested over a long period.
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
| 822 | HT-PHY: BCM4331 external front-end setup (external LNA/PA lines) |
| 823 | HT-PHY: read 32-bit PHY table entries low half first |
| 824 | HT-PHY: static TX gain instead of the TX power control loop |
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
| 836 | HT-PHY: send two spatial streams (MCS 8–15), **off by default** — see *Two transmit streams* |

Changes since rc3: 834 updated (a client could hang for good, bug 15), 835 and 836 are new;
820–833 are unchanged.

### Bugs found and fixed

| # | Problem | Cause | Fixed in |
|---|---|---|---|
| 1 | Receiver deaf on the R6400 v1 (-75 dBm where -48 is right) | b43 never configured the BCM4331's external front end (LNA/PA control lines, RF sequencer, PA LDO) | 822 |
| 2 | Corrupted TX gain word | HT-PHY 32-bit table reads took the high half first; the PHY latches on the low half | 823 |
| 3 | Distorted TX, download halved | The TX power control loop drives the external PA into compression | 824 |
| 4 | Download 2.3 Mbit/s once RX aggregation is on | Block acks were sent with transmitter address 00:00:00:00:00:00: b43 never wrote its MAC into the BA template | 826 |
| 5 | Video/voice traffic stuck | The BCM4331's VI/VO hardware queues never transmit | 827 (all traffic via the best-effort queue) |
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
| Two transmit streams, MCS 8–15 (optional, `ht_tx_streams=2`) | download 53 → 70–83 Mbit/s to two-stream clients | 836 |

## Test results

Overnight tests: R6400 v1 as access point, two clients that take turns and also load it
together: an R6400 v2 (on the same version) and a Qualcomm IPQ8074 router (ath11k), plus a
phone in power save (screen off). rc2: 15 hours, 144 cycles; rc4: 12.7 hours, 123 cycles,
one transmit stream (the default). iperf3 TCP in Mbit/s, averages (R6400 v2 / IPQ8074):

| Phase | rc2 | rc4 |
|---|---|---|
| R6400 v2 download alone | 43.2 | 49.4 |
| R6400 v2 upload alone | 42.2 | 50.2 |
| both download | 5.4 / 44.2 | 12.5 / 38.7 |
| R6400 v2 download, IPQ8074 upload | 10.4 / 63.2 | 4.1 / 89.0 |
| R6400 v2 download + upload at once | 40.8 down / 2.8 up | 32.2 down / 17.9 up |
| phone ping while the R6400 v2 downloads: runs with 0 % loss | 138 of 142 | 122 of 122 |
| phone ping while the R6400 v2 downloads: average | 0.37 s | 0.35 s |
| frames given up (access point / client) | 1381 / 801 | 58 / 18 |
| block-ack window resets (access point) | 5 | 0 |

Access point: no stalls, no hangs, no RX ring errors, no reboot, memory stable, in both. The
R6400 v2 client on rc4 had one TX stall of one second that recovered by itself. The phone's
latency under load (~0.35 s) is what it shows without load: it is the phone's power save.
The uneven numbers when both clients are busy, and the R6400 v2's weak upload under load,
are described under *Known limitations*.

## Test images (GitHub Releases)

Ready-made OpenWrt images with this series are attached to the release **b43-80211n-rc4**
(OpenWrt snapshot r37195-66ee7b6950, kernel 6.18). Pick the image by the router's board ID:

| Router | board ID | Image |
|---|---|---|
| R6400 v1 | U12H332T00_NETGEAR | `openwrt-r6400-v1-b43-80211n-rc4-squashfs.chk` |
| R6400 v2 | U12H332T20_NETGEAR | `openwrt-r6400-v2-b43-80211n-rc4-squashfs.chk` |
| R6400 v2 (OTP) | U12H332T30_NETGEAR | `openwrt-r6400-v2-otp-b43-80211n-rc4-squashfs.chk` |

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
tcpdump, USB storage (incl. NTFS), curl, `iperf3` and `htop`. The b43 module needs no configuration.
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

Set in `/etc/modules.d/b43` (e.g. `b43 ampdu_rts=1`) and reboot. OpenWrt's `modprobe` ignores
parameters on the command line.

| Parameter | Default | Meaning |
|---|---|---|
| `ht` | 1 | 802.11n on the HT-PHY (0 = 802.11g only) |
| `ht_rx_ampdu` | 1 | accept RX block-ack sessions |
| `ht_tx_ampdu` | 1 | TX A-MPDU aggregation |
| `ht_sgi` / `ht_sgi_tx` | 1 / 1 | announce / send the short guard interval |
| `ampdu_rts` | -1 | RTS/CTS before aggregates: -1 only for re-sends, 1 always, 0 never |
| `ampdu_inflight` | 2 | aggregates in flight per queue (1 lowers latency, costs ~12 % download) |
| `ampdu_max_frames` | 16 | maximum frames per aggregate |
| `ht_txgain_idx` | -2 | static TX gain index: -2 auto (24 with high-gain PA, else 16), -1 old power loop |
| `ht_txcore` | 1 | TX core mask for one-stream frames (core 0) |
| `ht_tx_streams` | 1 | transmit streams (patch 836): 1 = MCS 0–7, 2 = MCS 0–15; only at module load |
| `ht_txcore2` | 3 | TX core mask for two-stream frames (3 = cores 0 and 1; 5, 6 possible) |
| `ht_cck_rx` | -1 | CCK (802.11b) reception (patch 833): -1 only when the network has CCK basic rates, 0 never, 1 always |
| `ht_txq_pull` | 1 | airtime fairness (patch 834); 0 = the old single driver queue |

## Two transmit streams (optional)

Patch 836 can send two spatial streams (MCS 8–15) to clients that receive two streams, as
most phones and laptops do. It is **off by default** in rc4: with two streams two power
amplifiers transmit at the same time at the gain of one, about 3 dB more in total. So far it
has been tested on the R6400 v2 (download 53 → 70–83 Mbit/s to a two-stream client at
-24 dBm); the R6400 v1, with its external high-gain amplifiers, has not been tested yet.

To turn it on, set the parameter in `/etc/modules.d/b43` and reboot (it is read only when
the module loads):

```sh
echo "b43 ht_tx_streams=2" > /etc/modules.d/b43
reboot
```

If the file already holds other parameters, add `ht_tx_streams=2` to that line instead.
Check:

```sh
cat /sys/module/b43/parameters/ht_tx_streams       # 2
iw dev <wifi interface> station dump | grep "tx bitrate"   # MCS 8-15 to two-stream clients
```

To turn it off again, remove the parameter (or set `ht_tx_streams=1`) and reboot. Rate
control (patch 835) moves to a lower rate on its own when the two-stream rates do not
work; please report your results, with and without it.

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

* One transmit stream (MCS 0–7) by default, to keep the power amplifiers within safe limits;
  two streams are optional (see *Two transmit streams*). Clients may always send on two
  streams. With two streams the top rate (MCS 15) works well at some times and not at
  others; rate control then uses MCS 13–14.
* 20 MHz only (no 40 MHz), 2.4 GHz only.
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

## License

GPL-2.0, like the b43 driver. Based on b43, brcmsmac and ath9k (Linux kernel) and on
measurements against Broadcom's wl driver.
