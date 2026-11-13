# Linksys EA6900 v1 build kit: OpenWrt with experimental Wi-Fi (b43 AC-PHY)

A recipe to build the OpenWrt image we run and test on our EA6900 v1: board support plus both radios on
Alessio Ferri's experimental b43 AC-PHY driver, [aleferri/b43-ac-wip](https://github.com/aleferri/b43-ac-wip).
It holds patches and a few files, no images and no firmware: the build downloads the Broadcom firmware
itself (see *Firmware*).

**Experimental.** The driver is work in progress and the board support is still under review as
[openwrt/openwrt#26316](https://github.com/openwrt/openwrt/pull/26316). Read the main
[README](../README.md) first: the EA6900 needs the Asus-style CFE before it can run OpenWrt.

## Tested state

* OpenWrt main **r38134-5c5a157852** (kernel 6.18.60) with the feeds of 2026-11-05 (packages 5a350e9, luci 59b4e33,
  routing ea8633d, telephony 9bcb6d7, video 4582d70). Driver: b43-ac-wip **16eb94d**.
* This kit, built from a fresh checkout with `apply.sh`, flashed and soaked for 3 hours on 2026-11-05: a WRX36
  as the client, a client on each band, a wired LAN host as the iperf3 server, 5 GHz on channel 149. 26 cycles,
  0 stalls, 0 controller resets, 0 b43 errors, 0 CCMP replays, both stations connected the whole time.
  TCP averages: 2.4 GHz HT20 (3 streams) 134 down / 148 up, 5 GHz VHT80 440 down / 394 up Mbit/s;
  both bands at once 323 + 133. Highest temperature read 76.6 °C.
* Compared with the previous kit (2026-11-02 soak: 143 / 156, 357 / 374, 315 + 113), 5 GHz and both bands at once
  are faster; 2.4 GHz alone was 5-6 % slower, cause not known (the two soaks ran on different days).

## Contents

| Path | What | Source |
|---|---|---|
| `apply.sh [--no-board] <tree>` | puts everything below into an OpenWrt tree; `--no-board` only the driver parts (see *Other bcm53xx boards*) | ours |
| `patches/board/EA6900.patch` | board support: device tree, image, `02_network`, `01_leds` | ours, = [openwrt/openwrt#26316](https://github.com/openwrt/openwrt/pull/26316) |
| `patches/board/broadcom.mk.diff` | the `kmod-b43` options: AC-PHY support (selects 802.11ac in hostapd) and the 6.30.163.46 firmware | ours |
| `patches/kernel/880-bcma-ssb-support-the-BCM4352-BCM4360-family.patch` | bcma/ssb: the BCM4360's SROM rev 11 from nvram, PMU setup | Alessio Ferri, b43-ac-wip `patches/` at [16eb94d](https://github.com/aleferri/b43-ac-wip/commit/16eb94d) |
| `patches/mac80211/816-02-*`, `816-03-*` | the b43 core changes and the AC-PHY driver | Alessio Ferri, generated from b43-ac-wip [16eb94d](https://github.com/aleferri/b43-ac-wip/commit/16eb94d) with his `phase1-to-openwrt.sh` (see *How the driver patches are made*) |
| `files/etc/config/irqbalance`, `files/etc/rc.local`, `files/etc/uci-defaults/99-irqbalance-enable` | the interrupt layout (see below) | ours |
| `diffconfig` | the configuration of the tested image | ours |

The kit has no b43 patches of its own any more: all our fixes, from the earlier kits' `904`-`950`, are merged in
b43-ac-wip and come with `816-02` and `816-03`.

All patches are GPL-2.0, like the code they change. Alessio Ferri's patches are included unchanged, as his tree and
script produce them, so the kit builds what we tested; his repository is the place to get them from and to follow, and his
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
   git checkout 5c5a157852
   ```
2. `<kit>/apply.sh .`
3. `./scripts/feeds update -a && ./scripts/feeds install -a` (LuCI and irqbalance come from the feeds;
   `update` fetches their current state, so userspace packages can be newer than in our image).
4. `cp <kit>/diffconfig .config && make defconfig`, then `make menuconfig` to add what you want.
   The settings that matter: Target **Broadcom BCM47xx/53xx (ARM)**, Subtarget **Generic**, profile
   **Linksys EA6900**; Kernel modules → Wireless Drivers → `kmod-b43`: bus BCMA, firmware
   **784.2 from driver 6.30.163.46**, **Enable support for AC-PHYs**; with firmware squashing on, the core
   revisions must include **42** and the PHY types **AC**, or the build leaves the AC-PHY firmware out
   (`diffconfig` sets all of these, with a full `wpad` (`wpad-openssl`), `luci`, `irqbalance`, `iperf3`, `ethtool` and `ip-bridge`).
5. `make -j$(nproc)`. The images are in `bin/targets/bcm53xx/generic/`. On a fresh tree a `tools/...` package can fail
   at high `-j` (a race in the parallel host tools, seen on r38134): run `make -j1 tools/install` first, then `make -j$(nproc)`.
6. Install as in the main README, or upgrade a running EA6900 with
   `sysupgrade -v /tmp/openwrt-bcm53xx-generic-linksys_ea6900-squashfs.trx`.

After the first boot:
* `ls /lib/firmware/b43/ | grep 42` shows the three rev 42 files.
* `dmesg | grep b43` shows both radios, no warnings.
* `cat /proc/interrupts`: eth2 and the 2.4 GHz radio on CPU1, the 5 GHz radio on CPU0.

## How the driver patches are made

The source of the driver is Alessio Ferri's tree, not the patches: in
[b43-ac-wip](https://github.com/aleferri/b43-ac-wip) the folders `b43/` and `bcma/` hold whole kernel files, and
patches are a product of them. This kit's `816-02` and `816-03` were generated with his script, and you can do the
same to build a newer driver than the one we tested. Test the result before relying on it.

### What the scripts do

The scripts are in [b43-ac-wip/scripts](https://github.com/aleferri/b43-ac-wip/tree/main/scripts). Their comments are
in Italian; in short:

| Script | Does | Writes |
|---|---|---|
| `phase1-to-openwrt.sh <openwrt tree>` | makes the b43 patches for OpenWrt and copies them into the tree | `patches/816-*` and `patches/regen-base-openwrt` in the clone; `816-02`, `816-03` in the tree's `package/kernel/mac80211/patches/brcm/` |
| `regen-patches.sh` | the same for a plain Linux kernel (tag v7.2), the form for upstream; not needed for OpenWrt | `patches/0001`-`0003`, `patches/regen-base` |
| `carry.sh` | the engine of both, not run by itself | |

The `patches/` folder therefore holds the same three changes twice:

| Plain kernel | OpenWrt | What |
|---|---|---|
| `0001` | `880` | bcma/ssb |
| `0002` | `816-02` | b43 core changes, everything in `b43/` outside the AC-PHY files |
| `0003` | `816-03` | the AC-PHY: the `Makefile` and the files it builds under `CONFIG_B43_PHY_AC` |

`regen-base` and `regen-base-openwrt` are not patches: they record the base and the tree each set was generated from.

What `phase1-to-openwrt.sh` does, step by step:

1. Reads the backports version, tarball and hash from the tree's `package/kernel/mac80211/Makefile`.
2. Rebuilds the base: the b43 folder of that tarball (from the tree's `dl/`, or downloaded, hash checked) plus every
   b43 patch that comes before `816` in the package's patch order. It warns about b43 patches after `816`.
3. Applies the clone's current `816-*` to that base.
4. Three-way merge (`carry.sh`): brings in only what changed in `b43/` between the tree recorded in
   `regen-base-openwrt` and `HEAD`, with `CONFIG_B43` turned into `CPTCFG_B43`. A plain diff would not do: the patches
   also hold adaptations to their base that the tree does not have, and these must stay.
5. Splits the result back into `816-02` and `816-03`, keeping their messages and authors, records `HEAD` in
   `regen-base-openwrt`, and copies the patches to the tree with a line `Generated from b43-ac-wip <commit>`.

It does not commit anything, and it does not touch `880`: that patch sits on OpenWrt's kernel, not on backports.

### Generating them

Start from an OpenWrt tree with this kit applied ([Build](#build) steps 1 and 2).

1. A throwaway clone of b43-ac-wip, because the script rewrites files in it:
   ```sh
   git clone https://github.com/aleferri/b43-ac-wip.git && cd b43-ac-wip
   git log -1 --format=%h          # the commit you build: note it
   ```
   `b43/` must be committed; the script uses `HEAD`, not the working copy.
2. Generate and install the b43 patches, over the kit's copies (needs `git`, `curl`, `zstd`):
   ```sh
   scripts/phase1-to-openwrt.sh /path/to/openwrt
   grep -h 'Generated from' /path/to/openwrt/package/kernel/mac80211/patches/brcm/816-*
   ```
   Both lines must show your commit.
3. The kernel patch, which the script leaves alone:
   ```sh
   cp patches/880-*.patch /path/to/openwrt/target/linux/bcm53xx/patches-6.18/
   ```
4. Continue at [Build](#build) step 3. In a tree that was built before, first run
   `make target/linux/clean package/kernel/mac80211/clean`.

Things to watch:

* Do not copy `816-*` straight from the `patches/` folder: it is regenerated now and then and lags `b43/`.
* The tree must have no other b43 patches before `816`. The script's base would not match, and it stops with
  `816-02-... non si applica alla base` ("does not apply to the base"). The N-PHY/HT-PHY series of
  [openwrt/openwrt#25922](https://github.com/openwrt/openwrt/pull/25922) is such a case: the two do not combine yet.
* If a change in `b43/` collides with an adaptation, the merge stops with `conflitti` ("conflicts"), lists the files
  and leaves its work folder. Fix the files in `<folder>/tree`, run the two `git` commands it prints, then rerun the
  script with `CARRY_RESUME=<folder>`.
* `880` changes `struct ssb_sprom`: a `b43.ko` only loads on an image built with the same `880`.
* Newer OpenWrt trees may also need `EA6900.patch` or `broadcom.mk.diff` refreshed; `apply.sh` stops if they do not apply.

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

* No 802.11ac rates above VHT80. DFS channels are off in this build: the driver has radar detection behind
  `B43_DFS`, which needs `CFG80211_CERTIFICATION_ONUS`, and we have not tested it.
* RX descriptor underruns: up to about 30 per hour under continuous load in our soaks, without visible effect.
* **Software flow offloading** (Network → Firewall → Routing/NAT Offloading) does not work at the tested commit and
  makes routing *slower*. This applies to the published image as well. OpenWrt main at r38134 pins firewall4
  `e6f600c458`, which puts only `br-lan` and `wan` in the flowtable. Since openwrt/openwrt#25679, the kernel no
  longer offloads a flow whose port (here `lan1`-`lan4`) is not in the flowtable. Measured on the EA6900, wired LAN
  to WAN, upload/download: offloading off 293/336 Mbit/s, on 213/245, with firewall4 `3722eadc08` 621/738.
  firewall4 has the fix (openwrt/firewall4#108), and OpenWrt main has it since commit dab12e7663 (2026-11-12,
  "firewall4: update to Git HEAD (2026-11-08)"). The kit's commit `5c5a157852` is older: leave software offloading
  off, or bump firewall4 in your tree before step 5 (not needed when you build from main at dab12e7663 or later):
  ```sh
  sed -i 's/^PKG_SOURCE_DATE:=.*/PKG_SOURCE_DATE:=2026-11-08/
          s/^PKG_SOURCE_VERSION:=.*/PKG_SOURCE_VERSION:=3722eadc088c3ab81389596ca9796112b436583a/
          s/^PKG_MIRROR_HASH:=.*/PKG_MIRROR_HASH:=a95c6cfe419c7d4e22bda5608aa6e46c67dadc9c7096879702d614cc498759d0/' \
      package/network/config/firewall4/Makefile
  ```

## Reporting problems

Please open an issue in this repository with the output of `dmesg | grep -i b43` and `logread | tail -100`.
Problems in the driver itself are better reported at [aleferri/b43-ac-wip](https://github.com/aleferri/b43-ac-wip/issues).
