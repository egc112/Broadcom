# b43-next build kit: OpenWrt with b43-next for the Broadcom (bcm53xx) routers

One kit for the **Linksys EA6900 v1** and the **Netgear R6400 v1 and v2**. It builds OpenWrt main with
[b43-next](https://github.com/aleferri/b43-next) as the Wi-Fi driver. b43-next is b43 with its own copies of
bcma and ssb, in one module that loads next to the kernel's. It drives the BCM4331 (HT-PHY, the 2.4 GHz radio
of the R6400) and the BCM4360 (AC-PHY, both radios of the EA6900 and the 5 GHz radio of the R6400).

Test version, 2026-11-21. Since this version the kit holds only what b43-next needs:
[openwrt/openwrt#26717](https://github.com/openwrt/openwrt/pull/26717) as it is, the EA6900 board and the device
selection. The flow accelerator, the CPU port change, irqbalance and RPS for Wi-Fi (`Broadcom-4` to `Broadcom-6`
until 2026-11-20) moved to the [bcm53xx performance kit](../bcm53xx-performance-kit/), for all bcm53xx boards. The
two kits work alone and together, see [Both kits](#both-kits-in-one-tree). Earlier versions: the
[kit of 2026-11-20](https://github.com/egc112/Broadcom/tree/a621936/b43-next-build-kit), the EA6900 kit
(b43-ac-wip, [last version](https://github.com/egc112/Broadcom/tree/d07f0a7/linksys-ea6900/build-kit)) and the
R6400 patch series in [b43-80211n](../b43-80211n/).

## Contents

| File | What |
|---|---|
| `patches/B43-1-EA6900-board.patch` | EA6900 board support (dts, image, board.d, nvram), as submitted in [openwrt/openwrt#26316](https://github.com/openwrt/openwrt/pull/26316); the same file as in the performance kit |
| `patches/B43-2-b43-next-openwrt-26717.patch` | [openwrt/openwrt#26717](https://github.com/openwrt/openwrt/pull/26717) at 6d8e2fc70f, unchanged: the `kmod-b43-next` package pinned to b43-next 625d906, aleferri's main of 2026-11-20, with its firmware 784.2 as a package of its own, `b43-firmware-784` (kmod-b43's `b43-firmware` keeps its own version choice); `tools/Makefile` builds b43-fwcutter for the firmware packages |
| `patches/B43-3-b43-next-devices.patch` | the R6400 v1, v2, v2-otp and the EA6900 get `kmod-b43-next` and `wpad-openssl` instead of kmod-b43 and wpad-basic-mbedtls |
| `diffconfig` | EA6900, R6400 v1, R6400 v2 in one multi-profile build; kmod-b43-next, LuCI, iperf3, iw-full |
| `apply.sh` | applies the patches to an OpenWrt tree and adds the diffconfig to its `.config` |

## Build

Tested on OpenWrt main 6bd48701ef (2026-11-21). The R6400 itself is in OpenWrt main already.

    git clone https://git.openwrt.org/openwrt/openwrt.git && cd openwrt
    git checkout 6bd48701ef            # optional: the tested commit; newer main should work too
    /path/to/b43-next-build-kit/apply.sh .
    ./scripts/feeds update -a && ./scripts/feeds install -a
    make defconfig && make -j$(nproc)

**Use `apply.sh`, not `patch` by hand.** It also works from a flat copy of both kits in one folder, where it is
called `B43-kit-apply.sh` or `Perf-kit-apply.sh` next to the `B43-*`/`Perf-*` patches and the `*-kit-diffconfig`.
Both kits contain the same EA6900 board patch; applied twice by hand, its image hunk goes in a second time with
fuzz, and the second `Device/linksys_ea6900` (without b43-next) wins. Its rejected hunks also leave `.rej` files in
`base-files/etc/board.d/`, which end up in the image. If that happened: `git checkout` the touched files (or start
from a clean tree) and use `apply.sh`.

**wpad and per-device packages.** The kit gives these devices `wpad-openssl` as a device package. Keep
`CONFIG_TARGET_PER_DEVICE_ROOTFS` ("Use a per-device root filesystem that adds profile packages") on: in a
multi-profile build without it, the device packages (the Wi-Fi driver, the wpad, the USB modules) do not end up
in the images. A device package is installed on top of your own selection, so two wpad variants in one image
stop the build with `unable to select packages ... conflicts`. To use another wpad, remove the kit's per device
in menuconfig (Target Devices, the device's packages field): `-wpad-openssl wpad-basic-mbedtls`.

Images: `bin/targets/bcm53xx/generic/`: `*linksys_ea6900-squashfs.trx`, `*netgear_r6400-v1-squashfs.chk`,
`*netgear_r6400-v2-squashfs.chk`. Install the EA6900 as described in [linksys-ea6900](../linksys-ea6900/).
At boot, `/etc/init.d/b43-next` hands the PCIe radios from the kernel's bcma to b43-next and moves their paths
in `/etc/config/wireless` along.

When openwrt#26717 gets merged into OpenWrt, `B43-2` is no longer needed; the same goes for `B43-1` once
openwrt#26316 is merged.

## Both kits in one tree

Apply both kits to the same tree, in either order, then build as above:

    /path/to/b43-next-build-kit/apply.sh .
    /path/to/bcm53xx-performance-kit/apply.sh .

`apply.sh` writes the checksums of the patches it applied to `.kit-applied` in the tree and skips a patch that is
there already: the EA6900 board patch is in both kits. The diffconfigs add up: all bcm53xx devices, and the
EA6900 and the R6400 v1 and v2 with b43-next. Both orders give the same tree.

## How this kit is made, and why

- **Only b43-next.** b43-next is on its way into OpenWrt via #26717; the flow accelerator and the CPU and IRQ
  settings apply to every Northstar router, whatever its Wi-Fi driver. They are in the
  [performance kit](../bcm53xx-performance-kit/#how-this-kit-is-made-and-why) now, which explains its own choices.
- **#26717 as it is.** Its own pin, 625d906, is aleferri's latest main, so the kit no longer needs lines of its
  own in it; once #26717 is merged, `B43-2` goes. `B43-1` (#26316) is unchanged as well.
- **kmod-b43-next as a module in the diffconfig (`=m`).** The three devices get it as a device package
  (`B43-3`). With `=y` it would go into every image of the build, also into those of other boards when this kit is
  combined with the performance kit, which builds all devices.
- **The board patch in both kits.** See the performance kit: `apply.sh` skips it, by checksum, when the other kit
  applied it already.

## Tested

2026-11-21, OpenWrt main 6bd48701ef, b43-next 625d906.

- **Builds:** this kit alone and together with the performance kit (both orders give the same tree).
- **R6400 v2**, image with both kits: BCM4331 and BCM4360 up, 4 SSIDs at 2.4 GHz and VHT80 at 5 GHz, no
  warnings.
- **EA6900**, both kits: both BCM4360 radios up (2.4 GHz HT20, 5 GHz VHT80), no warnings.
- **R6400 v1**, this kit alone: both radios up.
- No throughput run on this pin yet. Its seven commits since the previous pin 89dd44f are AC-PHY clean-ups
  (names, tables, code moved into place).

Earlier versions (pin 51b501e and 89dd44f, 2026-11-17/19): BCM4331 at 2.4 GHz, 4 SSIDs, DL-WRX36 client, TCP to a
wired LAN host: HT20 about 150 up / 105 down, HT40 about 325 up / 210 down Mbit/s, MCS 23 (three streams); a
2-hour soak with clients on both bands without stalls or errors; the 5 GHz radio (BCM4360, VHT80) about 360 down
/ 380 up Mbit/s. EA6900, MT6000 client, iperf3 to the router itself: 2.4 GHz 139-143 Mbit/s both ways, 5 GHz VHT80
372 down / 204-210 up Mbit/s.

## Known issues

- With `legacy_rates` off (the OpenWrt default) the AP beacons at 6 Mb/s and does not answer probe
  requests sent at CCK rates; some scanners then show the AP coming and going. `option legacy_rates '1'`
  on the radio changes that.
- "PHY transmission error": on the 5 GHz radio (BCM4360) now and then one warning at a `wifi` reload, harmless (the
  AC-PHY only logs it). On the 2.4 GHz radio (BCM4331) each error counts towards a controller restart after 1000,
  so report it if it does show up.
- The R6400's 5 GHz radio (BCM4360) at full upload speed: "RX descriptor underrun" warnings (34 in 2 hours); the
  RX ring was full and the driver empties it again, throughput unaffected. The EA6900 shows the same. RPS for the
  Wi-Fi interfaces (in the performance kit) avoids them in our runs.

## Sources

| Part | Author | Based on |
|---|---|---|
| `B43-1` | Erik Conijn | board support as submitted to OpenWrt and reviewed there, openwrt/openwrt#26316; no b43 code |
| `B43-2` | Ville Takio (flatstik) | his openwrt/openwrt#26717, unchanged |
| b43-next itself | Alessio Ferri and contributors | downloaded at build time; its sources are documented in its own repository |
| `B43-3`, `diffconfig`, `apply.sh` | Erik Conijn | OpenWrt's own image Makefile and package configuration |

The b43 firmware (from Broadcom's driver 6.30.163.46) is downloaded at build time, as for OpenWrt's kmod-b43;
the kit contains no firmware or Broadcom-derived code.
