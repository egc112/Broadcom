# b43-next build kit: OpenWrt with b43-next for the Broadcom (bcm53xx) routers

One kit for the **Linksys EA6900 v1** and the **Netgear R6400 v1 and v2**. It builds OpenWrt main with
[b43-next](https://github.com/aleferri/b43-next) as the Wi-Fi driver. b43-next is b43 with its own copies of
bcma and ssb, in one module that loads next to the kernel's. It drives the BCM4331 (HT-PHY, the 2.4 GHz radio
of the R6400) and the BCM4360 (AC-PHY, both radios of the EA6900 and the 5 GHz radio of the R6400).

Test version, 2026-11-19. It replaces the earlier EA6900 kit (b43-ac-wip, `linksys-ea6900/build-kit/`,
[last version](https://github.com/egc112/Broadcom/tree/d07f0a7/linksys-ea6900/build-kit)) and the R6400
patch series in [b43-80211n](../b43-80211n/): their work is in b43-next now.

## Contents

| File | What |
|---|---|
| `patches/Broadcom-1-EA6900-board.patch` | EA6900 board support (dts, image, board.d, nvram), as submitted in [openwrt/openwrt#26316](https://github.com/openwrt/openwrt/pull/26316) |
| `patches/Broadcom-2-b43-next-package.patch` | the `kmod-b43-next` package from [openwrt/openwrt#26717](https://github.com/openwrt/openwrt/pull/26717) at 96c3718543 (with the firmware as a separate `b43-firmware` package), pinned to b43-next 4854b6f (main of 2026-11-19, with [aleferri/b43-next#39](https://github.com/aleferri/b43-next/pull/39) merged: AC aggregation epochs per TX FIFO, no throughput change in an A/B on the R6400 v2); `tools/Makefile` also builds b43-fwcutter for `b43-firmware` |
| `patches/Broadcom-3-b43-next-devices.patch` | the R6400 v1, v2, v2-otp and the EA6900 get `kmod-b43-next` and `wpad-openssl` instead of kmod-b43 and wpad-basic-mbedtls |
| `patches/Broadcom-4-irqbalance-enable.patch` | switches irqbalance on when it is installed (the package installs disabled) |
| `patches/Broadcom-5-wifi-rps-hotplug.patch` | a hotplug script that switches RPS on for the Wi-Fi AP interfaces, see [below](#rps-on-for-the-wi-fi-interfaces) |
| `diffconfig` | EA6900, R6400 v1, R6400 v2 in one multi-profile build; kmod-b43-next, LuCI, irqbalance, iperf3, iw-full |
| `irqpin.rc.local` | a fixed IRQ layout for test comparisons only; not built in, copy it by hand to `/etc/rc.local` |
| `apply.sh` | applies the patches to an OpenWrt tree and puts the diffconfig in place |

## Build

Tested on OpenWrt main 5732bcbeff (2026-11-18); the patches apply without offsets on main dc63bfff7a (2026-11-19). The R6400 itself is in OpenWrt main already.

    git clone https://git.openwrt.org/openwrt/openwrt.git && cd openwrt
    git checkout 5732bcbeff            # optional: the tested commit; newer main should work too
    /path/to/b43-next-build-kit/apply.sh .
    ./scripts/feeds update -a && ./scripts/feeds install -a
    make defconfig && make -j$(nproc)

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

When openwrt#26717 gets merged into OpenWrt, `Broadcom-2` is no longer needed (apart from the pin). The same
goes for `Broadcom-1` once openwrt#26316 is merged.

## RPS on for the Wi-Fi interfaces

On these two-core routers a radio's interrupt thread receives the frames and also
forwards them (bridge, Ethernet) on the same CPU; at full 5 GHz speed that CPU is the limit. RPS (receive packet
steering) hands the forwarding to the other CPU. OpenWrt's packet steering does not do it on bcm53xx: the
target's own `/usr/libexec/platform/packet-steering.sh` replaces the generic script and sets only `eth0` and
`br-lan`; and packet steering does not run again when `wifi` creates the AP interfaces, on any target. The kit
therefore sets RPS per AP interface with a hotplug script, `/etc/hotplug.d/net/30-wifi-rps`, built in by
`Broadcom-5-wifi-rps-hotplug.patch` (in bcm53xx's base-files, so on all bcm53xx images of the build):

    # RPS for the Wi-Fi AP interfaces: hand the forwarding to the CPU that does
    # not take the radio's interrupt. bcm53xx's packet steering skips Wi-Fi, and
    # packet steering does not run again when "wifi" creates the AP interfaces.
    [ "$ACTION" = add ] || exit 0
    case "$INTERFACE" in phy*-ap*) ;; *) exit 0 ;; esac
    irq=$(cat /sys/class/net/$INTERFACE/device/../irq 2>/dev/null) || exit 0
    aff=$(cat /proc/irq/$irq/smp_affinity 2>/dev/null) || exit 0
    case $((0x$aff)) in
    	1) echo 2 > /sys/class/net/$INTERFACE/queues/rx-0/rps_cpus ;;
    	2) echo 1 > /sys/class/net/$INTERFACE/queues/rx-0/rps_cpus ;;
    esac

It runs whenever an AP interface is created (boot, `wifi`, a radio reload). Check with
`cat /sys/class/net/phy*-ap*/queues/rx-0/rps_cpus`: 1 or 2, not 0. On an image built without the kit, copy the
script by hand to `/etc/hotplug.d/net/30-wifi-rps` and run `wifi`.

Measured on the R6400 v2 (5 GHz VHT80, MT6000 client, bridged to a wired PC, 60 s runs, 2026-11-19): upload 365
to 398 Mbit/s, download 319 to 349, and no "RX descriptor underrun" (without RPS about one every 4 minutes at full
upload). Do not give both CPUs (`3`): a single flow then lands on one CPU by hash, and in our runs it mostly
stayed on the busy one. The 2.4 GHz radio gets the same setting but was not measured on its own. At boot the script
waits in the background until irqbalance has pinned the radio's interrupt to one CPU (about 35 s after boot on the
R6400 v2) and logs what it set (`logread | grep wifi-rps`). If irqbalance moves a radio's interrupt later, the
setting does not follow until the next `wifi`.

## Tested (R6400 v2 and EA6900, 2026-11-17/18)

BCM4331 at 2.4 GHz, 4 SSIDs, DL-WRX36 client, TCP to a wired LAN host: HT20 about 150 up / 105 down, HT40 about
325 up / 210 down Mbit/s, MCS 23 (three streams). A 2-hour soak of this kit's image (with the previous pin
51b501e; the HT40- fix does not touch HT20; two clients at 2.4 GHz on two SSIDs, one at 5 GHz, each alone and
all at once) ran without stalls or errors; the 5 GHz radio (BCM4360, VHT80) gave about 360 down / 380 up Mbit/s
alone.

EA6900 with an image built from this kit (2026-11-18), MT6000 client, iperf3 to the router itself: 2.4 GHz
139-143 Mbit/s both ways, 5 GHz VHT80 372 down / 204-210 up Mbit/s; no driver warnings.

## Known issues

- HT40- (control channel above the secondary, e.g. ch 11): fixed in this pin (aleferri/b43-next#35); before it,
  the first SSID's beacon went out on the secondary 20 MHz.
- With `legacy_rates` off (the OpenWrt default) the AP beacons at 6 Mb/s and does not answer probe
  requests sent at CCK rates; some scanners then show the AP coming and going. `option legacy_rates '1'`
  on the radio changes that.
- "PHY transmission error": on the 5 GHz radio (BCM4360) now and then one warning at a `wifi` reload, harmless (the
  AC-PHY only logs it). On the 2.4 GHz radio (BCM4331) none on this image in 2 h 40 min of load on both bands
  (2026-11-18); there each error counts towards a controller restart after 1000, so report it if it does show up.
- The R6400's 5 GHz radio (BCM4360) at full upload speed: "RX descriptor underrun" warnings (34 in 2 hours); the
  RX ring was full and the driver empties it again, throughput unaffected. The EA6900 shows the same. With RPS on
  (see above) none in our runs on the R6400 v2.

## Sources

| Part | Author | Based on |
|---|---|---|
| `Broadcom-1` | Erik Conijn | board support as submitted to OpenWrt and reviewed there, openwrt/openwrt#26316; no b43 code |
| `Broadcom-2` | Ville Takio (flatstik) | his openwrt/openwrt#26717, unchanged apart from two lines of ours: the b43-next pin (`PKG_SOURCE_*`, `PKG_MIRROR_HASH`) and the `tools/Makefile` condition |
| b43-next itself | Alessio Ferri and contributors | downloaded at build time; its sources are documented in its own repository |
| `Broadcom-3`, `Broadcom-4`, `Broadcom-5`, `diffconfig`, `apply.sh` | Erik Conijn | OpenWrt's own image Makefile and package configuration |
| `irqpin.rc.local` | Erik Conijn | throughput measurements on the EA6900 (2026-10-29) |

The b43 firmware (from Broadcom's driver 6.30.163.46) is downloaded at build time, as for OpenWrt's kmod-b43;
this repository contains no firmware or Broadcom code.
