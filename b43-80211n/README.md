# b43: 802.11n with A-MPDU for the BCM4331 (Netgear R6400) — TEST VERSION (rc9)

> **Status: test version.** Since rc9 this series is a small set of patches **on top of Rosen
> Penev's b43 802.11n series**, openwrt/openwrt#25922, which brings 802.11n to b43 upstream
> and already contains most of what rc2–rc8 did. rc9 adds six fixes and improvements for the
> R6400 that are not (yet) in his series. Tested on the author's Netgear R6400 v1 and v2 in a
> 9.5-hour soak test with two clients and a phone. Not in OpenWrt or the Linux kernel yet.
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
| **rc9 = openwrt/openwrt#25922 + these patches**, v1 (soak test) | **96–111 Mbit/s, avg 107** | **90–111 Mbit/s, avg 107** |

## What is in rc9

rc9 = OpenWrt main + **openwrt/openwrt#25922 as of 0615bc0150** (Rosen Penev, patches 813 and
820–861 in `package/kernel/mac80211/patches/brcm/`) + the patches in [patches](patches/):

| Patch | What it does | Why |
|---|---|---|
| 862 | do not disable NAPI on SDIO devices | NAPI is only enabled on non-SDIO devices, but was disabled on all: on an SDIO device stopping the device would hang. Pointed out by the openwrt-ai review of openwrt/openwrt#25922. Not used by the R6400 (PCIe); for other b43 devices |
| 863 | HT-PHY: do not upload table 9 on FEM and HGPA boards | On the R6400 v1 the table 9 upload costs about 10 dB of transmit power: download 109–111 → 68–70 Mbit/s. Broadcom's own driver leaves the table as b43 has it without the upload. No difference on the v2 |
| 864 | HT-PHY: drop the `ht_cck_rx` module parameter | CCK reception follows the network alone (see *Module parameters*) |
| 865 | HT-PHY: optional `ht_txgain_idx` module parameter | For own builds: override the fixed transmit gain (see *Transmit power*). Not meant for upstream |
| 866 | HT-PHY: calibrate the RX I/Q imbalance on channel switch | b43 never set the receiver's I/Q compensation. On the R6400 v1, channel 6, up to a third of the frames a client sent at the top rate (MCS 15) were lost: 32.8 % → 2.1 %, upload 79.5 → 90.8 Mbit/s. Neutral on the v2. See [PROVENANCE.md](PROVENANCE.md#patch-866-rx-iq-calibration) |
| 867 | HT-PHY: receive A-MPDUs of up to 64 KiB | Upload from an ath11k client to the R6400 v2: 89–92 → 105–107 Mbit/s (+17 %); no clear difference on the v1 |
| [wifi-scripts](patches/wifi-scripts-b43-best-effort-frame-bursting.patch) | best effort frame bursting (`tx_queue_data2_burst 2.0`) by default on b43 802.11n radios | Shares the air fairer when a client uploads and downloads at once (see *Traffic in both directions*). A patch to the OpenWrt tree, not to the mac80211 package |

All of them are by Erik Conijn and carry `Assisted-by: Claude:claude-opus-5-5`: they were
written with the help of an AI assistant, which also ran most of the measurements.

What Rosen Penev's series brings (see his PR for the details): 802.11n HT20 for N-PHY and
HT-PHY devices, two spatial streams, A-MPDU in both directions (32 frames), short guard
interval, STBC, RTS/CTS for aggregates, power save in AP mode, airtime fairness, NAPI,
software encryption of protected management frames (WPA3/PMF), and the R6400 fixes from
our rc2–rc8 series that he took over (external front end, static transmit gain, 32-bit
table reads, block-ack address, Duration field, frames spanning several RX buffers, CCK
reception, VI/VO FIFOs, multi-rate retry).
Thanks to him for the work and for taking our patches in.

## Hardware

* **Netgear R6400 v1** (BCM4709 + BCM4331, external high-gain PA, `BFL_HGPA`): tested as an
  access point.
* **Netgear R6400 v2** (BCM4331 with FEM, `BFL_FEM`): tested as a client and as an access point.
* Other BCM4331 boards: 863 and 865 act only on boards with an external front end
  (`BFL_FEM` or `BFL_HGPA`); 866 runs on every HT-PHY board, but was only tested on these two
  and only at 2.4 GHz. 862 matters only for SDIO devices.
* **BCM4360 (AC-PHY) is not supported**, neither by stock b43 nor by these patches: that is the
  5 GHz radio of the R6400 and both radios of the Netgear R7000. b43 logs
  `FOUND UNSUPPORTED PHY (Analog 12, Type 11 (AC))` for it; that line is expected.

## Test results

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

## Test images (GitHub Releases)

Ready-made OpenWrt images with rc9 are attached to the release **b43-80211n-rc9**
(OpenWrt snapshot r37744-7d0bf92bee, kernel 6.18). Pick the image by the router's board ID:

| Router | board ID | Image |
|---|---|---|
| R6400 v1 | U12H332T00_NETGEAR | `openwrt-r6400-v1-b43-80211n-rc9-squashfs.chk` |
| R6400 v2 | U12H332T20_NETGEAR | `openwrt-r6400-v2-b43-80211n-rc9-squashfs.chk` |
| R6400 v2 (OTP) | U12H332T30_NETGEAR | `openwrt-r6400-v2-otp-b43-80211n-rc9-squashfs.chk` |

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

**Upgrading from rc8 with settings kept:** the rc8 module parameters are gone (see *Module
parameters*); remove them from `/etc/modules.d/b43`, which should hold just `b43`.

## Building

You need an OpenWrt main build tree for the bcm53xx target (R6400 support is in OpenWrt main
for the v1; for the v2 see openwrt/openwrt#25929). Tested with OpenWrt main r37507-4e16c2ed8f
and r37744-7d0bf92bee (kernel 6.18, mac80211 backports 7.2).

1. Apply Rosen Penev's series, openwrt/openwrt#25922 at 0615bc0150, in the OpenWrt tree:

   ```sh
   cd <openwrt>
   curl -L https://github.com/openwrt/openwrt/commit/0615bc015072e3ac901193092562d7c2df7dcef5.patch | git am
   ```

   If his PR has moved on since, these patches may no longer apply on top of it; use this
   commit.

2. Copy our mac80211 patches next to his, and apply the wifi-scripts patch:

   ```sh
   cp <this repo>/b43-80211n/patches/86*.patch package/kernel/mac80211/patches/brcm/
   git apply <this repo>/b43-80211n/patches/wifi-scripts-b43-best-effort-frame-bursting.patch
   ```

3. Select b43 (`make menuconfig`): Kernel modules → Wireless Drivers → `kmod-b43`; b43 options:
   bus BCMA, PHY type **HT**, firmware **5.100.138** (contains ucode 666.2 for the BCM4331).

4. Build the image (`make -j$(nproc)`) and flash it, or build only the module:

   ```sh
   make package/kernel/mac80211/{clean,compile} -j$(nproc)
   ```

   The module is
   `build_dir/target-*/linux-bcm53xx_generic/mac80211-regular/backports-*/ipkg-*/kmod-b43/lib/modules/<kernel>/b43.ko`.
   Copying a module onto a router only works if the router runs an image from the **same** build
   tree (same kernel and backports); otherwise flash the image.

No configuration is needed: the defaults are the tested settings.

## Module parameters

Upstream does not want new module parameters, and Rosen Penev's series has none: the rc8
parameters (`ht`, `ht_tx_streams`, `ht_txcore`, `ht_sgi`, `ampdu_*`, `ht_cck_rx`, …) are all
gone. 802.11n, two streams, aggregation and the short guard interval are always on; CCK
(802.11b) reception is off only when the network uses no 802.11b rates (the OpenWrt default)
and stays on while scanning.

The only b43 parameter these patches add is `ht_txgain_idx` (patch 865), see *Transmit power*.
The standard b43 parameters (`qos`, `nohwcrypt`, `hwtkip`, `btcoex`, `hwpctl`, `verbose`, `pio`,
`gpiomask`, `bad_frames_preempt`, `allhwsupport`, `fwpostfix`) are unchanged.

Set parameters on one line in `/etc/modules.d/b43` and reboot (OpenWrt reads this file only at
boot), e.g. `echo "b43 ht_txgain_idx=30" > /etc/modules.d/b43`. Check the values in use with
`grep . /sys/module/b43/parameters/*`.

## Transmit power

On boards with an external front end the BCM4331 sends with a fixed transmit gain instead of
the hardware power control loop, which drove the external amplifiers into distortion: index
24 on the **R6400 v1** (`BFL_HGPA`) and 16 on the **R6400 v2** (`BFL_FEM`), chosen from the
SPROM board flags (Rosen Penev's 840, based on our rc8 patch 824). A higher index is less
power.

`ht_txgain_idx` (patch 865) overrides that choice: 0–127 selects the index, -1 the power
control loop, -2 (the default) the automatic choice. It can be written live in
`/sys/module/b43/parameters/ht_txgain_idx` and takes effect at the next `wifi`. Stay at or
above the automatic index: a lower one gives more power than the board was measured with.
Leave it at -2 unless you have a reason, such as less power at close range.

## Reporting problems

Please include:

```sh
logread | grep -iE "b43|ieee80211" | tail -100
iw dev <wifi interface> station dump
cat /sys/module/b43/parameters/ht_txgain_idx
```

and what the clients were doing (download/upload, which device, which channel). With
`verbose=3` in `/etc/modules.d/b43` b43 also logs the transmit gain, the CCK reception
switch and the RX I/Q calibration result per channel switch (`RX I/Q comp …`).

`tx failed` in the station dump counts send attempts that got no acknowledgement, not lost
frames: most of those get through when they are sent again.

## Known limitations

* 20 MHz only (no 40 MHz). The R6400's BCM4331 is 2.4 GHz only.
* The transmit power setting of LuCI and `iw` does not lower the fixed gain on the R6400; use
  `ht_txgain_idx` (see *Transmit power*).
* Two clients uploading at the same time do not share the air evenly: an R6400 v2 as a client
  got 7–17 Mbit/s next to an ath11k client's 70–99. Each alone gets ~100. Not investigated
  yet; it is between the clients, not in the access point.
* 866 calibrates at every channel switch (interface start, channel change); during a scan the visited channels run uncompensated, as before. A channel switch takes
  about 25 ms longer. Not tested at 5 GHz (other BCM4331 boards).
* The b43 receiver reports the signal about 20 dB too high (no RSSI calibration in b43's
  HT-PHY code).

## Credits

Rosen Penev (@neheb) for openwrt/openwrt#25922, the base of rc9, which includes several of our
earlier patches. The openwrt-ai review of his PR for the point fixed in 862.

## License

GPL-2.0, like the b43 driver. Where every patch comes from, and how the information was
obtained, is documented in [PROVENANCE.md](PROVENANCE.md).
