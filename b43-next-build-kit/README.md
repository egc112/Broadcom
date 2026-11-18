# b43-next build kit: OpenWrt with b43-next for the Broadcom (bcm53xx) routers

One kit for the **Linksys EA6900 v1** and the **Netgear R6400 v1 and v2**. It builds OpenWrt main with
[b43-next](https://github.com/aleferri/b43-next) as the Wi-Fi driver. b43-next is b43 with its own copies of
bcma and ssb, in one module that loads next to the kernel's. It drives the BCM4331 (HT-PHY, the 2.4 GHz radio
of the R6400) and the BCM4360 (AC-PHY, both radios of the EA6900 and the 5 GHz radio of the R6400).

Test version, 2026-11-18. It replaces the earlier EA6900 kit (b43-ac-wip, `linksys-ea6900/build-kit/`,
[last version](https://github.com/egc112/Broadcom/tree/d07f0a7/linksys-ea6900/build-kit)) and the R6400
patch series in [b43-80211n](../b43-80211n/): their work is in b43-next now.

## Contents

| File | What |
|---|---|
| `patches/Broadcom-1-EA6900-board.patch` | EA6900 board support (dts, image, board.d, nvram), as submitted in [openwrt/openwrt#26316](https://github.com/openwrt/openwrt/pull/26316) |
| `patches/Broadcom-2-b43-next-package.patch` | the `kmod-b43-next` package from [openwrt/openwrt#26717](https://github.com/openwrt/openwrt/pull/26717) at 96c3718543 (with the firmware as a separate `b43-firmware` package), pinned to b43-next fe3b1fd (ht-fixes: HT40 on the HT-PHY + the HT40- beacon fix); `tools/Makefile` also builds b43-fwcutter for `b43-firmware` |
| `patches/Broadcom-3-b43-next-devices.patch` | the R6400 v1, v2, v2-otp and the EA6900 get `kmod-b43-next` instead of kmod-b43 |
| `patches/Broadcom-4-irqbalance-enable.patch` | switches irqbalance on when it is installed (the package installs disabled) |
| `diffconfig` | EA6900, R6400 v1, R6400 v2 in one multi-profile build; kmod-b43-next, LuCI, irqbalance, iperf3, iw-full |
| `irqpin.rc.local` | a fixed IRQ layout for test comparisons only; not built in, copy it by hand to `/etc/rc.local` |
| `apply.sh` | applies the patches to an OpenWrt tree and puts the diffconfig in place |

## Build

Tested on OpenWrt main 5732bcbeff (2026-11-18). The R6400 itself is in OpenWrt main already.

    git clone https://git.openwrt.org/openwrt/openwrt.git && cd openwrt
    git checkout 5732bcbeff            # optional: the tested commit; newer main should work too
    /path/to/b43-next-build-kit/apply.sh .
    ./scripts/feeds update -a && ./scripts/feeds install -a
    make defconfig && make -j$(nproc)

Images: `bin/targets/bcm53xx/generic/`: `*linksys_ea6900-squashfs.trx`, `*netgear_r6400-v1-squashfs.chk`,
`*netgear_r6400-v2-squashfs.chk`. Install the EA6900 as described in [linksys-ea6900](../linksys-ea6900/).
At boot, `/etc/init.d/b43-next` hands the PCIe radios from the kernel's bcma to b43-next and moves their paths
in `/etc/config/wireless` along.

When openwrt#26717 gets merged into OpenWrt, `Broadcom-2` is no longer needed (apart from the pin). The same
goes for `Broadcom-1` once openwrt#26316 is merged.

## Tested (R6400 v2, 2026-11-17/18)

BCM4331 at 2.4 GHz, 4 SSIDs, DL-WRX36 client, TCP to a wired LAN host: HT20 about 150 up / 105 down, HT40
about 325 up / 210 down Mbit/s, MCS 23 (three streams). A 6-hour soak of b43-next (ht-fixes with our
block ack patch, two clients on two SSIDs) ran without errors. The EA6900 is tested with b43-next main (2.4 GHz 132-145 Mbit/s, 5 GHz
210 / 370), not yet with this kit's image.

## Known issues

- HT40- (control channel above the secondary, e.g. ch 11): fixed in this pin (aleferri/b43-next#35); before it,
  the first SSID's beacon went out on the secondary 20 MHz.
- With `legacy_rates` off (the OpenWrt default) the AP beacons at 6 Mb/s and does not answer probe
  requests sent at CCK rates; some scanners then show the AP coming and going. `option legacy_rates '1'`
  on the radio changes that.
- "PHY transmission error" lines in the log under heavy load in both directions; no failed frames, no
  effect on throughput.
- The R6400's 5 GHz radio (BCM4360): tested only briefly so far (R6400 v2, VHT80, 3 streams: about 290 up /
  410 down Mbit/s to a wired LAN host).

## Sources

| Part | Author | Based on |
|---|---|---|
| `Broadcom-1` | Erik Conijn | board support as submitted to OpenWrt and reviewed there, openwrt/openwrt#26316; no b43 code |
| `Broadcom-2` | Ville Takio (flatstik) | his openwrt/openwrt#26717, unchanged apart from two lines of ours: the b43-next pin (`PKG_SOURCE_*`, `PKG_MIRROR_HASH`) and the `tools/Makefile` condition |
| b43-next itself | Alessio Ferri and contributors | downloaded at build time; its sources are documented in its own repository |
| `Broadcom-3`, `Broadcom-4`, `diffconfig`, `apply.sh` | Erik Conijn | OpenWrt's own image Makefile and package configuration |
| `irqpin.rc.local` | Erik Conijn | throughput measurements on the EA6900 (2026-10-29) |

The b43 firmware (from Broadcom's driver 6.30.163.46) is downloaded at build time, as for OpenWrt's kmod-b43;
this repository contains no firmware or Broadcom code.
