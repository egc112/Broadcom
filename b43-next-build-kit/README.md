# b43-next kit: OpenWrt with b43-next for the Broadcom (bcm53xx) routers

For the **Netgear R6400 v1 and v2**, the **Netgear R7000** (not tested yet) and, with the
[EA6900 board kit](../ea6900-board-kit/), the **Linksys EA6900 v1**. It builds OpenWrt main with [b43-next](https://github.com/aleferri/b43-next) as the Wi-Fi driver. b43-next
is b43 with its own copies of bcma and ssb, in one module that loads next to the kernel's. It drives the BCM4331
(HT-PHY, the 2.4 GHz radio of the R6400) and the BCM4360 (AC-PHY, both radios of the EA6900 and the R7000, and the 5 GHz
radio of the R6400).

Test version, 2026-11-26. Changes since 2026-11-25: `2-B43-1` is the current #26717 (c3b21ea4cc), which splits
firmware 784.2 into one package per PHY type, so the R6400 lines in `2-B43-2` add `b43-firmware-784-ht` for their
BCM4331 (see [Which firmware each radio needs](#which-firmware-each-radio-needs)). #26717 now applies to OpenWrt
main as it is, so the kit's own fit-up for the brcmsmac removal is gone. Earlier versions: the
[kit of 2026-11-25](https://github.com/egc112/Broadcom/tree/189dc0e/b43-next-build-kit), the
[kit of 2026-11-22](https://github.com/egc112/Broadcom/tree/499c3ea/b43-next-build-kit), the EA6900 kit
(b43-ac-wip, [last version](https://github.com/egc112/Broadcom/tree/d07f0a7/linksys-ea6900/build-kit)) and the
R6400 patch series in [b43-80211n](../b43-80211n/).

## Contents

| File | What |
|---|---|
| `patches/2-B43-1-b43-next-openwrt-26717.patch` | [openwrt/openwrt#26717](https://github.com/openwrt/openwrt/pull/26717) at c3b21ea4cc: the `kmod-b43-next` package pinned to b43-next 625d906, aleferri's main of 2026-11-20, and its firmware 784.2 in one package per PHY type (`b43-firmware-784-ac`, `-ht`, `-n`, `-lp`, `-g`, `-lcn`); kmod-b43 keeps `b43-firmware` (5.100.138). With [openwrt/openwrt#26255](https://github.com/openwrt/openwrt/pull/26255) at c6749e76c9, which #26717 depends on: it passes `CONFLICTS` to apk, so apk does not install kmod-b43 next to kmod-b43-next |
| `patches/2-B43-2-b43-next-devices.patch` | the R6400 v1, v2 and v2-otp get `kmod-b43-next` and `b43-firmware-784-ht` instead of kmod-b43, with OpenWrt's default wpad; the R7000, which has no Wi-Fi driver in OpenWrt, gets them too (2026-11-25: the kits apply and the R7000 profile selects them; not built or flashed yet) |
| `patches/2-B43-3-EA6900.patch` | the same for the EA6900; needs the EA6900 board kit, `apply.sh` skips it without the board |
| `diffconfig` | R6400 v1 and v2 and the R7000 in one multi-profile build; kmod-b43-next, LuCI, iperf3, iw-full (the EA6900 comes from the board kit's diffconfig) |
| `apply.sh` | applies the patches to an OpenWrt tree and adds the diffconfig to its `.config` |

## Build

Tested on OpenWrt main f76496253d (2026-11-26). The R6400 itself is in OpenWrt main already.

    git clone https://git.openwrt.org/openwrt/openwrt.git && cd openwrt
    /path/to/ea6900-board-kit/apply.sh .         # only for the EA6900, and always first
    /path/to/b43-next-build-kit/apply.sh .
    /path/to/bcm53xx-performance-kit/apply.sh .  # optional: the flow accelerator
    ./scripts/feeds update -a && ./scripts/feeds install -a
    make defconfig && make -j$(nproc)

**By hand instead of `apply.sh`:** `patch -p1 < file` for each patch in name order, after the EA6900 board kit;
without that kit, leave out `2-B43-3-EA6900.patch`. Then add the diffconfig lines to `.config`. With all kits
copied into one folder, every `*.patch` in name order gives the same tree as the three `apply.sh` runs.

**wpad and per-device packages.** The devices get OpenWrt's default wpad (`$(IEEE8021X)`, today
`wpad-basic-mbedtls`), as in OpenWrt's own device lines. Keep `CONFIG_TARGET_PER_DEVICE_ROOTFS` ("Use a per-device
root filesystem that adds profile packages") on: in a multi-profile build without it, the device packages (the Wi-Fi
driver, the wpad, the USB modules) do not end up in the images. A device package is installed on top of your own
selection, so selecting another wpad in menuconfig gives two wpad variants in one image and stops the build with
`unable to select packages ... conflicts`. For another wpad in all devices, change the `IEEE8021X :=` line at the
top of `target/linux/bcm53xx/image/Makefile` instead (for example to `wpad-openssl`).

Images: `bin/targets/bcm53xx/generic/`: `*netgear_r6400-v1-squashfs.chk`, `*netgear_r6400-v2-squashfs.chk`,
`*linksys_ea6900-squashfs.trx`. At boot, `/etc/init.d/b43-next` hands the PCIe radios from the kernel's bcma to
b43-next and moves their paths in `/etc/config/wireless` along.

When openwrt#26717 is merged into OpenWrt, `2-B43-1` is no longer needed.

## How this kit is made, and why

- **Only b43-next.** The flow accelerator and the CPU and IRQ settings apply to every Northstar router, whatever
  its Wi-Fi driver; they are in the [FA kit](../bcm53xx-performance-kit/#how-this-kit-is-made-and-why).
- **The EA6900 apart.** Only EA6900 owners need its board support, so it is a kit of its own, applied first
  (`1-`). The EA6900 line of the device selection is `2-B43-3-EA6900`: it changes a line that the board patch
  adds, so it cannot be in `2-B43-2`, which has to apply without the board. This also ends the shared board patch
  of the earlier kits, and with it the checksum list (`.kit-applied`) of the old `apply.sh`.
- **#26717 as it is, plus #26255.** #26717 is based on current main and applies unchanged. It depends on #26255
  (open), which earlier versions of #26717 carried themselves; the kit adds it in front, so `2-B43-1` is the two
  PRs' diffs one after the other.
- **The firmware by PHY type.** `kmod-b43-next` pulls in only the AC-PHY firmware. Each device line adds the
  package of every other radio type the device has, which for the boards in this kit means `-ht` on the R6400.
- **kmod-b43-next as a module in the diffconfig (`=m`).** The devices get it as a device package. With `=y` it
  would go into every image of the build, also into those of other boards when this kit is combined with the FA
  kit, which builds all devices.

## Tested

2026-11-23, OpenWrt main f8145e6545: the three kits apply in every combination (each alone, any two, all three
in order) and from one flat folder in name order; the kernel patches apply with and without the EA6900 board kit.
All three kits built together from their diffconfigs alone: all 40 bcm53xx devices, the R6400 v1, v2 and v2-otp
and the EA6900 with `kmod-b43-next` and `wpad-openssl`, every other device with OpenWrt's own Wi-Fi packages.
Not flashed yet with these exact files.
2026-11-25, OpenWrt main 64c777f3af: the R7000 added and the devices on OpenWrt's default wpad; the three kits
apply, and `make defconfig` gives the R6400 v1, the R7000 and the EA6900 `wpad-basic-mbedtls kmod-b43-next`.
2026-11-26, OpenWrt main f76496253d (#26717 c3b21ea4cc, #26255 c6749e76c9): the three kits apply in every
combination and from one flat folder in name order. All three kits built together (all 40 bcm53xx devices): the
R6400 v1, v2 and v2-otp images have `b43-next.ko` with the AC- and HT-PHY firmware in `/lib/firmware/b43-784`, the
R7000 and EA6900 images `b43-next.ko` with the AC-PHY files only; no image has both `b43.ko` and `b43-next.ko`. Not
flashed yet with these exact files.

Radios, 2026-11-21 (main 6bd48701ef, b43-next 625d906, the same b43-next and device selection):

- **R6400 v2**: BCM4331 and BCM4360 up, 4 SSIDs at 2.4 GHz and VHT80 at 5 GHz, no warnings.
- **EA6900**: both BCM4360 radios up (2.4 GHz HT20, 5 GHz VHT80), no warnings. On 2026-11-23 also with
  #26789 v3 under it.
- **R6400 v1**: both radios up.

Earlier versions (pin 51b501e and 89dd44f, 2026-11-17/19): BCM4331 at 2.4 GHz, 4 SSIDs, DL-WRX36 client, TCP to a
wired LAN host: HT20 about 150 up / 105 down, HT40 about 325 up / 210 down Mbit/s, MCS 23 (three streams); a
2-hour soak with clients on both bands without stalls or errors; the 5 GHz radio (BCM4360, VHT80) about 360 down
/ 380 up Mbit/s. EA6900, MT6000 client, iperf3 to the router itself: 2.4 GHz 139-143 Mbit/s both ways, 5 GHz VHT80
372 down / 204-210 up Mbit/s.

## Which firmware each radio needs

b43-next loads firmware 784.2 from `/lib/firmware/b43-784`. #26717 splits it into one package per PHY type, from
the file list of `b43-fwsquash.py`; `kmod-b43-next` pulls in `b43-firmware-784-ac`, any other type has to be on the
device's `DEVICE_PACKAGES` line. The PHY type and core revision of a radio are in its boot log, e.g.
`b43-phy0: Broadcom 43217 WLAN found (core revision 30)` and `Found PHY: Analog 9, Type 4 (N), Revision 17`.

| Package | PHY (boot log `Type`) | Core revisions | Radios | Boards with b43-next |
|---|---|---|---|---|
| `b43-firmware-784-ac`, comes with `kmod-b43-next` | AC (11) | 40, 42 | BCM4352, BCM4360 (42) | R6400 v1/v2 5 GHz, R7000 and EA6900 both radios; ASUS RT-AC56U 5 GHz, RT-AC68U / RT-AC66U B1 both radios (#26718, #26719) |
| `b43-firmware-784-ht` | HT (7) | 26, 29 | BCM4331 (29) | R6400 v1/v2 2.4 GHz |
| `b43-firmware-784-n` | N (4) | 11-12, 16-19, 22-23, 25, 28, 30 | BCM43217 (30), BCM43227 | ASUS RT-AC56U 2.4 GHz (#26718) |
| `b43-firmware-784-lp` | LP (5) | 13-15 | | |
| `b43-firmware-784-g` | A (0), G (2) | 5-10, 13 (13 also needs `ucode13.fw` from `-lp`) | | |
| `b43-firmware-784-lcn` | LCN (8), LCN40 (10) | 24, 25, 28; 33 | | |

The core revisions are those of the microcode files in each package (the 2026-11-26 build). 784.2 has no
microcode for core revisions 2-4, so those cores are not covered. For the boards in this kit: the R6400 v1, v2 and
v2-otp get `-ht` on their line in `2-B43-2`; the R7000 and the EA6900 need nothing extra. A board on kmod-b43
keeps `b43-firmware` (5.100.138, in `/lib/firmware/b43`) and is not affected.

## Known issues

- With `legacy_rates` off (the OpenWrt default) the AP beacons at 6 Mb/s and does not answer probe
  requests sent at CCK rates; some scanners then show the AP coming and going. `option legacy_rates '1'`
  on the radio changes that.
- "PHY transmission error": on the 5 GHz radio (BCM4360) now and then one warning at a `wifi` reload, harmless (the
  AC-PHY only logs it). On the 2.4 GHz radio (BCM4331) each error counts towards a controller restart after 1000,
  so report it if it does show up.
- The R6400's 5 GHz radio (BCM4360) at full upload speed: "RX descriptor underrun" warnings (34 in 2 hours); the
  RX ring was full and the driver empties it again, throughput unaffected. The EA6900 shows the same. RPS for the
  Wi-Fi interfaces (in the FA kit) avoids them in our runs.

## Sources

| Part | Author | Based on |
|---|---|---|
| `2-B43-1` | Ville Takio (flatstik); #26255 by Josef Schlehofer (BKPepe) | openwrt/openwrt#26717 and #26255, unchanged |
| b43-next itself | Alessio Ferri and contributors | downloaded at build time; its sources are documented in its own repository |
| `2-B43-2`, `2-B43-3`, `diffconfig`, `apply.sh` | Erik Conijn | OpenWrt's own image Makefile and package configuration |

The b43 firmware (from Broadcom's driver 6.30.163.46) is downloaded at build time, as for OpenWrt's kmod-b43;
the kit contains no firmware or Broadcom-derived code.
