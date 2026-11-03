# Linksys EA6900 v1 build kit: OpenWrt with experimental Wi-Fi (b43 AC-PHY)

A recipe to build the OpenWrt image we run and test on our EA6900 v1: board support plus both radios on
Alessio Ferri's experimental b43 AC-PHY driver, [aleferri/b43-ac-wip](https://github.com/aleferri/b43-ac-wip).
It holds patches and a few files, no images and no firmware: the build downloads the Broadcom firmware
itself (see *Firmware*).

**Experimental.** The driver is work in progress and the board support is still under review as
[openwrt/openwrt#26316](https://github.com/openwrt/openwrt/pull/26316). Read the main
[README](../README.md) first: the EA6900 needs the Asus-style CFE before it can run OpenWrt.

## Tested state

* OpenWrt main **r37507-4e16c2ed8f** (kernel 6.18). Newer trees may need the patches refreshed.
* This kit, built from a fresh checkout with `apply.sh`, flashed and soaked for 3 hours on 2026-11-02: a WRX36
  as the client, a client on each band, a wired LAN host as the iperf3 server, 5 GHz on channel 149. 26 cycles,
  0 stalls, 0 controller resets, 0 b43 errors, 0 CCMP replays, both stations connected the whole time.
  TCP averages: 2.4 GHz HT20 (3 streams) 143 down / 156 up, 5 GHz VHT80 357 down / 374 up Mbit/s;
  both bands at once 315 + 113. Router at most 75 °C.
* The same b43 patches plus one guard that never triggers (left out here) ran a 24-hour soak on 2026-11-01/02
  with the same numbers (142 / 157, 361 / 382, 319 + 112) and no errors.

## Contents

| Path | What | Source |
|---|---|---|
| `apply.sh [--no-board] <tree>` | puts everything below into an OpenWrt tree; `--no-board` only the driver parts (see *Other bcm53xx boards*) | ours |
| `patches/board/EA6900.patch` | board support: device tree, image, `02_network`, `01_leds` | ours, = [openwrt/openwrt#26316](https://github.com/openwrt/openwrt/pull/26316) |
| `patches/board/broadcom.mk.diff` | the `kmod-b43` options: AC-PHY support (selects 802.11ac in hostapd) and the 6.30.163.46 firmware | ours |
| `patches/kernel/880-bcma-ssb-support-the-BCM4352-BCM4360-family.patch` | bcma/ssb: the BCM4360's SROM rev 11 from nvram, PMU setup | Alessio Ferri, b43-ac-wip `patches/` at [1e43a20](https://github.com/aleferri/b43-ac-wip/commit/1e43a20) |
| `patches/mac80211/816-02-*`, `816-03-*` | the AC-PHY driver | Alessio Ferri, b43-ac-wip `patches/` at [8c234e6](https://github.com/aleferri/b43-ac-wip/commit/8c234e6) |
| `patches/mac80211/817-*`, `818-*` | his driver brought up to b43-ac-wip [3517def](https://github.com/aleferri/b43-ac-wip/commit/3517def) and [bc63d98](https://github.com/aleferri/b43-ac-wip/commit/bc63d98) | Alessio Ferri's code, diffs of his tree |
| `patches/mac80211/904`, `906`, `917`, `946`, `949`, `950` | AC-PHY fixes for this board | ours, see [../b43-ac/PROVENANCE.md](../b43-ac/PROVENANCE.md); in b43-ac-wip as #14, #15, #12, #8, #9 and the fix for issue #16 |
| `patches/mac80211/926`, `934`-`939` | DMA burst, locking and A-MSDU handling | ours, merged in b43-ac-wip as #6 |
| `patches/mac80211/942` | RX DMA burst length | ours, open in b43-ac-wip as #13 |
| `files/etc/config/irqbalance`, `files/etc/rc.local`, `files/etc/uci-defaults/99-irqbalance-enable` | the interrupt layout (see below) | ours |
| `diffconfig` | the configuration of the tested image | ours |

All patches are GPL-2.0, like the code they change. Alessio Ferri's patches are copied here unchanged so the
kit builds what we tested; his repository is the place to get them from and to follow, and his
[PROVENANCE.md](https://github.com/aleferri/b43-ac-wip/blob/main/PROVENANCE.md) documents their sources. The sources
of our own parts are in [../b43-ac/PROVENANCE.md](../b43-ac/PROVENANCE.md) (section *Build kit*).

## Firmware

The AC-PHY needs the firmware of d11 core rev 42 (`ucode42.fw`, `ac1initvals42.fw`, `ac1bsinitvals42.fw`).
Of the b43 firmware versions OpenWrt knows, only the one from Broadcom's driver 6.30.163.46 has it.
`broadcom.mk.diff` adds that version; the build downloads `broadcom-wl-6.30.163.46.tar.bz2`, checks its
SHA-256 and extracts the files with b43-fwcutter, as OpenWrt does for the other versions. It is the tarball
the b43 project documented at lwfinger.com/b43-firmware; that site is gone, so the build takes it from the
Gentoo mirror and falls back to the Web Archive copy of the original site (both byte-identical).

## Build

1. A plain OpenWrt tree at the tested commit:
   ```sh
   git clone https://git.openwrt.org/openwrt/openwrt.git && cd openwrt
   git checkout 4e16c2ed8f
   ```
2. `<kit>/apply.sh .`
3. `./scripts/feeds update -a && ./scripts/feeds install -a` (LuCI and irqbalance come from the feeds;
   `update` fetches their current state, so userspace packages can be newer than in our image).
4. `cp <kit>/diffconfig .config && make defconfig`, then `make menuconfig` to add what you want.
   The settings that matter: Target **Broadcom BCM47xx/53xx (ARM)**, Subtarget **Generic**, profile
   **Linksys EA6900**; Kernel modules → Wireless Drivers → `kmod-b43`: bus BCMA, firmware
   **784.2 from driver 6.30.163.46**, **Enable support for AC-PHYs**; with firmware squashing on, the core
   revisions must include **42** and the PHY types **AC**, or the build leaves the AC-PHY firmware out
   (`diffconfig` sets both); a full `wpad` (`wpad-openssl`); `luci`, `irqbalance`.
5. `make -j$(nproc)`. The images are in `bin/targets/bcm53xx/generic/`.
6. Install as in the main README, or upgrade a running EA6900 with
   `sysupgrade -v /tmp/openwrt-bcm53xx-generic-linksys_ea6900-squashfs.trx`.

After the first boot:
* `ls /lib/firmware/b43/ | grep 42` shows the three rev 42 files.
* `dmesg | grep b43` shows both radios, no warnings.
* `cat /proc/interrupts`: eth2 and the 2.4 GHz radio on CPU1, the 5 GHz radio on CPU0.

## Other bcm53xx boards

The driver parts are not EA6900-specific. For another bcm53xx board with a BCM4352 or BCM4360 radio, use
`<kit>/apply.sh --no-board .` in step 2: it applies `broadcom.mk.diff`, the bcma/ssb kernel patch and the b43
patches, and leaves out the EA6900 board patch and `files/` (the interrupt layout is for the EA6900 only).
Skip the `diffconfig` in step 4 and select your board's profile and the `kmod-b43` settings listed there.

Only the EA6900 has been tested by us; Alessio Ferri's driver itself is developed on BCM4352 boards with the
SROM on the chip. The first thing to check on a new board is the `b43`/`bcma` part of `dmesg` (chip, PHY and
radio revisions, SROM revision): please report it at
[aleferri/b43-ac-wip](https://github.com/aleferri/b43-ac-wip/issues).

## Interrupts

Ethernet and both radios otherwise share CPU0, and a busy 5 GHz radio then starves the rest. The image
enables irqbalance but bans three interrupts from it, and `rc.local` pins those: `eth2` (the CPU port) and the
2.4 GHz radio on CPU1, the 5 GHz radio on CPU0. The main README's irqbalance section has the measurements.
After reloading b43 by hand, run `/etc/rc.local` again.

## Known limitations

* No 802.11ac rates above VHT80, no DFS channels, no airtime fairness: with two busy clients, one downloading
  next to one uploading gets very little.
* 5 GHz uses the receive-gain values of the low channels on all channels; the stock driver switches to a
  second set from channel 100 up. Our tests ran on channel 149 (VHT80), so it works there, but perhaps not
  at its best; the fix is being worked on in b43-ac-wip.
* RX descriptor underruns: 6 to 26 per hour under continuous load in our soaks, without visible effect.
* A-MSDU frames are dropped (939), as brcmsmac does; joining them is being worked on in b43-ac-wip.

## Reporting problems

Please open an issue in this repository with the output of `dmesg | grep -i b43` and `logread | tail -100`.
Problems in the driver itself are better reported at [aleferri/b43-ac-wip](https://github.com/aleferri/b43-ac-wip/issues).
