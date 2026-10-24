# Linksys EA6900 v1 — OpenWrt (own build, TEST VERSION)

> **Status: test version, not in OpenWrt.** OpenWrt has no EA6900 support. These patches add it.
> Tested on one EA6900 v1 that was converted to the **Asus-style (XVortex) CFE** and ran DD-WRT
> before. Units with the stock Linksys CFE (dual boot) are **not** covered and not tested.
> **There is no wireless yet** (see *What works*).

## Hardware

| | |
|---|---|
| SoC | Broadcom BCM4708A0 (chip 53010 rev 0), 800 MHz, 2 cores |
| RAM / flash | 256 MiB / 128 MiB NAND (Spansion S34ML01G1, BCH-8) |
| Switch | BCM53011 (rev 3): WAN on port 0, LAN 1–4 on ports 1–4 |
| Wireless | **two BCM4360** (AC-PHY, 3x3): 2.4 GHz (nvram `0:devid=0x43A1`) and 5 GHz (`1:devid=0x43A2`), both PCI 14e4:4360, no SPROM: the calibration is in nvram |
| USB | port 1 = USB 3.0 (VBUS on GPIO 9), port 2 = USB 2.0 (VBUS on GPIO 10) |
| LEDs | one white Linksys logo LED with **two** drivers: GPIO 6 (active low) and GPIO 8 (active high); the port LEDs belong to the switch |
| Buttons | WPS = GPIO 7, Reset = GPIO 11 (both active low) |
| MACs (nvram) | LAN = `et0macaddr`, WAN = `wan_hwaddr` (= LAN + 1), 2.4 GHz = `0:macaddr`, 5 GHz = `1:macaddr` |

The GPIOs come from the CFE's default nvram (`gpio7=wps_button`, `reset_gpio=11`, `gpio9=usbport1`,
`gpio10=usbport2`) and from testing on the router. DD-WRT also drives GPIO 0, 1 and 2, but no
visible function was found; OpenWrt leaves them alone.

## Prerequisite: the Asus-style CFE

The stock Linksys CFE has the 32 KiB nvram limit and a dual-boot layout (`linux` / `linux2`).
Many EA6900 owners replaced it with an Asus RT-AC68U-based CFE (by XVortex), which has 64 KiB
nvram and the Asus **mini-CFE web recovery**. This guide assumes that CFE. Replacing the CFE is
**not** covered here; see the DD-WRT forum.

Check on DD-WRT: `nvram get nvram_space` gives `65536`, and `cat /proc/mtd` shows a single `linux`
partition (no `linux2`).

With this CFE the dual boot is gone: OpenWrt sees one firmware partition from 0x200000 to the end of
flash (126 MiB), so the overlay gets about 92 MiB.

## What works

| | |
|---|---|
| Ethernet: WAN + 4 LAN, MACs from nvram | works |
| USB 2.0 on both ports | works |
| USB 3.0 (SuperSpeed) when the stick is plugged in **after** boot | works |
| USB 3.0 stick **present at boot** | **unreliable**: sometimes detected after 30–50 s, sometimes not at all; replug it (see *Known limitations*) |
| Logo LED: blinks during boot/failsafe/upgrade, solid when up; WAN link LED on GPIO 8 | works |
| WPS button | works |
| Reset button | defined (GPIO 11), press not tested yet |
| sysupgrade with settings kept | works (without keeping settings: not tested) |
| **Wireless** | **no**: stock OpenWrt's b43 does not support the BCM4360 (AC-PHY): `b43-phy0 ERROR: FOUND UNSUPPORTED PHY (Analog 12, Type 11 (AC))`; brcmfmac does not support this chip either |

## Before you start

1. **Back up the CFE and nvram** (on DD-WRT, then copy the files off the router):

   ```sh
   dd if=/dev/mtd0 of=/tmp/mtd0-cfe.bin bs=131072
   dd if=/dev/mtd1 of=/tmp/mtd1-nvram.bin bs=131072
   nvram show > /tmp/nvram-show.txt   # contains your passwords and wifi keys
   ```

2. **Keep a DD-WRT `.trx` for the EA6900** as the way back. You can dump the running one:
   read the TRX length from bytes 4–7 of `/dev/mtd2` (little endian), then
   `dd if=/dev/mtd2 bs=131072 count=<length/131072, rounded up>` and cut the file to that length.
   Check it with `otrx check` from an OpenWrt build tree before you rely on it.

3. OpenWrt does **not** use nvram for its settings (they live in `/etc/config` on the UBI
   overlay). It only reads nvram: the MACs, and later the radio calibration. Do **not** erase
   nvram: the calibration is only there.

## Install from DD-WRT

1. DD-WRT → Administration → Firmware Upgrade: upload
   `openwrt-bcm53xx-generic-linksys_ea6900-squashfs.trx`. Choose **not** to reset to defaults.
   (DD-WRT writes EA6900 images to the `linux` partition when `bootpartition` is empty or 0, and checks
   only the TRX header and CRC.)
2. The first boot takes a few minutes: UBI is formatted and DD-WRT's `/jffs` area is erased.
   Do not power-cycle. The logo LED blinks while it boots and is solid when it is up.
3. Connect to a LAN port: OpenWrt is at **192.168.1.1**, user `root`, no password. Set a password.

## Install or recover with the mini CFE

The usual Asus CFE rescue procedure (not re-tested for this guide): switch the router off, hold the
**Reset** button, switch it on, and keep holding until the logo LED flashes slowly. Give your computer
the static address 192.168.1.2/24, open http://192.168.1.1 and upload a `.trx`:

* the OpenWrt `squashfs.trx` (or `initramfs.trx`) to install OpenWrt;
* your DD-WRT `.trx` to go back to DD-WRT.

Your CFE needs `boot_wait=on` in nvram for the TFTP rescue route; keep it.

## Upgrading OpenWrt

```sh
sysupgrade -v /tmp/openwrt-bcm53xx-generic-linksys_ea6900-squashfs.trx
```

If you keep the settings when upgrading from a build without the WAN LED, add the LED section once:

```sh
uci set system.led_wan=led
uci set system.led_wan.name='WAN'
uci set system.led_wan.sysfs='white:wan'
uci set system.led_wan.trigger='netdev'
uci set system.led_wan.dev='wan'
uci set system.led_wan.mode='link'
uci commit system; /etc/init.d/led restart
```

## Building

You need an OpenWrt build tree (tested with OpenWrt main r37507-4e16c2ed8f, kernel 6.18).

1. Apply the patches at the root of the tree:

   ```sh
   cd <openwrt>
   patch -p1 < patches/EA6900.patch
   patch -p1 < patches/usb-bcma-load-after-xhci.patch
   ```

   * `EA6900.patch`: the device tree (`327-ARM-dts-BCM5301X-add-Linksys-EA6900.patch`), the image
     definition `linksys_ea6900`, the MAC setup (`02_network`) and the WAN LED (`01_leds`). It also
     applies on top of the Netgear R6400 v2 patches.
   * `usb-bcma-load-after-xhci.patch`: loads `bcma-hcd` (which switches USB power on) after the xHCI
     driver instead of before it. This is a generic bcm53xx change; without it a USB 3.0 stick present
     at boot gets power before the USB 3.0 controller is running. It helps, but does not fix the boot
     problem completely (see *Known limitations*).

2. `make menuconfig`: Target System **Broadcom BCM47xx/53xx (ARM)**, Subtarget **Generic**,
   Target Profile **Linksys EA6900**. Add LuCI and anything else you want.
3. `make -j$(nproc)`. The images are in `bin/targets/bcm53xx/generic/`:
   `openwrt-bcm53xx-generic-linksys_ea6900-squashfs.trx` (install/upgrade) and `-initramfs.trx`.

## Flash layout (Asus-style CFE, as OpenWrt sees it)

| Offset | Size | Name | |
|---|---|---|---|
| 0x0000000 | 512 KiB | boot | the CFE |
| 0x0080000 | 1 MiB | nvram | live nvram (64 KiB used) |
| 0x0180000 | 512 KiB | nvram | an older, separate nvram image with Linksys stock values; not used, not written |
| 0x0200000 | 126 MiB | firmware | TRX: kernel (4 MiB) + UBI (rootfs + rootfs_data) |

## Known limitations

* **No wireless** (BCM4360, AC-PHY; see *What works*).
* **USB 3.0 stick present at boot**: the stick gets power before the USB 3.0 link can be trained,
  falls back to USB 2.0 and fails there (`usb usb2-port1: Cannot enable`, `error -71`). It
  sometimes recovers after 30–50 s. Workaround: replug the stick after boot. Hot-plugging is fine.
* Both logo LED drivers light the same LED, so after boot a WAN link change is not visible on its own.
* Do not `rmmod` the USB host drivers on this kernel: on the test unit that hung the router, which
  then rebooted.
* Only tested on one unit, with the XVortex CFE, coming from DD-WRT.

## Reporting problems

Open an issue with the output of `dmesg`, `cat /proc/mtd`, `logread | tail -100`, and for USB
`cat /sys/kernel/debug/usb/xhci/18023000.usb/ports/port01/portsc`.

## Credits

* The GPIO and switch facts come from the EA6900's own CFE nvram, DD-WRT's open source tree
  (`ledconfig.c`, `resetbutton.c`, `sysinit*.c`, `rc/mtd.c`) and testing on the router.
* The device tree builds on OpenWrt's bcm53xx support (EA6500 v2, EA9200, RT-AC68U, R6400 v1) and on
  Rosen Penev's USB VBUS regulator patches (371–373).

## License

GPL-2.0-or-later (the device tree is GPL-2.0-or-later OR MIT, like the other BCM5301X device trees).
