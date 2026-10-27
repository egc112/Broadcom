# Linksys EA6900 v1 — OpenWrt (own build, TEST VERSION)

> **Status: test version, not in OpenWrt.** OpenWrt has no EA6900 support. These patches add it.
> Tested on one EA6900 v1 that was converted to the **Asus-style (XVortex) CFE** and ran DD-WRT
> before. Units with the stock Linksys CFE (dual boot) are **not** covered and not tested.
> **There is no wireless yet** (see *What works*).
> **EA6900 v1 only.** The EA6900 v2 is a different router (MediaTek MT7621) and needs other firmware.

## Hardware

| | |
|---|---|
| FCC / IC ID | Q87-EA6900 / 3839A-EA6900 |
| Power supply | 12 V DC, 3.5 A |
| SoC | Broadcom BCM4708A0 (chip 53010 rev 0), 800 MHz, 2 cores |
| RAM / flash | 256 MiB / 128 MiB NAND (Spansion S34ML01G1, BCH-8) |
| Switch | BCM53011 (rev 3): WAN on port 0, LAN 1–4 on ports 1–4 |
| Wireless | **two BCM4360** (AC-PHY, 3x3): 2.4 GHz (nvram `0:devid=0x43A1`) and 5 GHz (`1:devid=0x43A2`), both PCI 14e4:4360, no SPROM: the calibration is in nvram |
| Front ends | external power amplifiers: 3× Skyworks SE2623L (2.4 GHz), 3× Skyworks SE5003L1 (5 GHz) ([SmallNetBuilder](https://www.smallnetbuilder.com/wireless/wireless-reviews/linksys-ea6900-wireless-ac-router-smart-wi-fi-dual-band-ac1900-reviewed/)) |
| Antennas | 3 external dual-band antennas, detachable (RP-SMA) |
| Serial | 6-pin header inside (pinout not documented here; not used for this port) |
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
**not** covered here; see the guide by Crashman and egc in the
[DD-WRT forum](https://forum.dd-wrt.com/phpBB2/viewtopic.php?t=291230) (credits: @Xvortex, @Cybrnook,
@Crashman, @RMerlin). In short: dump the stock CFE and nvram, put your own `et0macaddr`,
`0:macaddr`, `1:macaddr` and `secret_code` (WPS PIN) into the Xvortex CFE with CFEEdit, and write it
to `mtd0`.

Check on DD-WRT: `nvram get nvram_space` gives `65536`, and `cat /proc/mtd` shows a single `linux`
partition (no `linux2`).

With this CFE the dual boot is gone: OpenWrt sees one firmware partition from 0x200000 to the end of
flash (126 MiB), so the overlay gets about 92 MiB.

Losing the dual boot is not a loss: the mini CFE web recovery (see below) can always put a new
image on the router, whatever state the firmware is in, because it lives in the CFE, which OpenWrt
never writes. In return you get four times the firmware space (126 MiB instead of about 31 MiB). The
only difference: the stock dual boot falls back to the other image by itself, while the mini CFE
needs a computer on a LAN port.

**Stock Linksys CFE (untested):** the stock layout keeps two images of about 31 MiB each in the
first 64 MiB of flash, at 0x200000 and 0x2100000 (see the
[DD-WRT wiki](https://wiki.dd-wrt.com/wiki/Linksys_EA6900); the upper 64 MiB is not used by the
stock firmware). The device tree has no fixed partitions, so OpenWrt's partition parser finds both
images and uses the one that `bootpartition` points to. The first image ends where the second
begins (31 MiB); the second runs to the end of the flash. The stock CFE counts incomplete boots in
nvram (`partialboots`, `maxpartialboots`, default 3) and switches to the other image when the
firmware does not reset that counter. DD-WRT resets it on every boot; OpenWrt does not. Reports
from stock-CFE units are welcome.

## What works

| | |
|---|---|
| Ethernet: WAN + 4 LAN, MACs from nvram | works |
| USB 2.0 on both ports | works |
| USB 3.0 (SuperSpeed) when the stick is plugged in **after** boot | works |
| USB 3.0 stick **present at boot** | **unreliable**: sometimes detected after 30–50 s, sometimes not at all; replug it (see *Known limitations*) |
| Logo LED: blinks during boot/failsafe/upgrade, solid when up; WAN link LED on GPIO 8 | works |
| WPS button | works |
| Reset button: short press reboots, hold 5 s or longer resets to defaults | works |
| Failsafe: tap Reset or WPS while the logo blinks during boot | works (LAN port 1 only) |
| sysupgrade, with and without keeping settings | works |
| Mini CFE web recovery | works (see *Install or recover with the mini CFE*) |
| **Wireless** | **no**: stock OpenWrt's b43 does not support the BCM4360 (AC-PHY): `b43-phy0 ERROR: FOUND UNSUPPORTED PHY (Analog 12, Type 11 (AC))`; brcmfmac does not support this chip either |

## Before you start

1. **Back up the CFE and nvram** (on DD-WRT, then copy the files off the router):

   ```sh
   dd if=/dev/mtd0 of=/tmp/mtd0-cfe.bin bs=131072
   dd if=/dev/mtd1 of=/tmp/mtd1-nvram.bin bs=131072
   nvram show > /tmp/nvram-show.txt   # contains your passwords and wifi keys
   ```

2. **Keep a DD-WRT image for the EA6900** as the way back: the `linksys-ea6900-webflash.bin` you
   installed (DD-WRT names it `.bin`, but it is a TRX file, the same format as OpenWrt's `.trx`).
   You can also dump the running one:
   read the TRX length from bytes 4–7 of `/dev/mtd2` (little endian), then
   `dd if=/dev/mtd2 bs=131072 count=<length/131072, rounded up>` and cut the file to that length.
   Check it with `otrx check` from an OpenWrt build tree before you rely on it.

3. OpenWrt does **not** use nvram for its settings (they live in `/etc/config` on the UBI
   overlay). It only reads nvram: the MACs, and later the radio calibration. Do **not** erase
   nvram, and do **not** erase the Linksys `devinfo` area at 0x180000 (see *Flash layout*): it
   holds the factory radio calibration. After installing OpenWrt, back it up as well (it is
   `mtd2` there):

   ```sh
   dd if=/dev/mtd2 of=/tmp/mtd2-devinfo.bin bs=131072   # contains your serial number and WPS PIN
   ```

4. **Give the mini CFE a known address.** The mini CFE uses the LAN address in nvram
   (`lan_ipaddr`), and DD-WRT stores its own LAN address there. If you changed DD-WRT's LAN address,
   set it back to 192.168.1.1 before you install (Setup → Basic Setup → Local IP Address, save and
   apply). A reset to defaults also does it, but that erases all of nvram. Without this step, the
   mini CFE answers on your old DD-WRT address, not on 192.168.1.1.

## Install from DD-WRT

1. DD-WRT → Administration → Firmware Upgrade: upload
   `openwrt-bcm53xx-generic-linksys_ea6900-squashfs.trx`. Choose **not** to reset to defaults.
   (DD-WRT writes EA6900 images to the `linux` partition when `bootpartition` is empty or 0, and checks
   only the TRX header and CRC.) If the web upgrade fails (after the CFE swap the partition layout
   differs from stock), copy the file to `/tmp` and run `write /tmp/<file> linux` over SSH, or
   use the mini CFE (below).
2. The first boot takes a few minutes: UBI is formatted and DD-WRT's `/jffs` area is erased.
   Do not power-cycle. The logo LED blinks while it boots and is solid when it is up.
3. Connect to a LAN port: OpenWrt is at **192.168.1.1**, user `root`, no password. Set a password.

## Install or recover with the mini CFE

**The mini CFE does not always use 192.168.1.1.** It takes its address from nvram (`lan_ipaddr`), so
after DD-WRT it is usually your last DD-WRT LAN address. OpenWrt itself never changes nvram. Check it
beforehand, in OpenWrt or DD-WRT:

```sh
nvram get lan_ipaddr
nvram get lan_netmask
```

To set it to 192.168.1.1 from OpenWrt (the `nvram` tool is in the default image; it writes the
`nvram` partition, not the `devinfo` area):

```sh
nvram set lan_ipaddr=192.168.1.1
nvram set lan_netmask=255.255.255.0
nvram commit
```

Do not switch the router off during the commit. OpenWrt does not use these values, so nothing else
changes. Tested on our router: the mini CFE answered on 192.168.1.1 afterwards.

If the router no longer boots and you do not know the address: give the computer a wide netmask
(for example 192.168.0.2 / 255.255.0.0), enter the mini CFE and run an ARP scan of that range
(`nmap -sn 192.168.0.0/16` or `arp-scan`; not tested yet). A normal ping scan only reaches the
computer's own subnet.

1. Switch the router off, hold the **Reset** button, switch it on and keep holding until the logo
   LED goes off (8 to 12 seconds in our tests), then let go. In rescue mode the logo blinks very
   slowly: about 25 seconds on, 25 seconds off. This is not a boot loop.
2. Connect the computer to **LAN port 1** and give it a static address in that subnet,
   for example 192.168.1.2/24 for `lan_ipaddr=192.168.1.1`. `ping` answers with TTL 100 (the CFE).
3. Open `http://<lan_ipaddr>` (plain http, not https) in a **private (incognito) window**; in a normal
   window the page sometimes does not show. Upload the image. If the upload stays at "uploading" and
   the router keeps blinking slowly, nothing was written: try another browser (in our test one
   browser hung, Edge worked). When the upload is complete, the router reboots by itself.

What to upload:

* **To recover OpenWrt:** the `initramfs.trx`. It runs from RAM, at 192.168.1.1 with no password.
  Then flash the `squashfs.trx` from it with sysupgrade or LuCI (without keeping settings) and
  restore your settings backup. This route is tested.
* Uploading the `squashfs.trx` directly is not tested yet. The CFE writes it raw over the old
  flash contents; use the initramfs route until someone confirms it.
* **Back to DD-WRT:** DD-WRT's `linksys-ea6900-webflash.bin` (or your dump).

Your CFE needs `boot_wait=on` in nvram for the TFTP rescue route; keep it.

**Do not hold WPS while switching on.** Holding WPS at power-on for about 20 seconds (until the logo
flashes) makes the CFE reset nvram to its defaults. The MACs come back from the CFE (if they were
set with CFEEdit), but anything else in nvram, including radio calibration added later, is gone.

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

1. Apply the patch at the root of the tree:

   ```sh
   cd <openwrt>
   patch -p1 < patches/EA6900.patch
   ```

   `EA6900.patch` adds the device tree (`327-ARM-dts-BCM5301X-add-Linksys-EA6900.patch`), the image
   definition `linksys_ea6900`, the MAC setup (`02_network`) and the WAN LED (`01_leds`). It also
   applies on top of the Netgear R6400 v2 patches.

2. `make menuconfig`: Target System **Broadcom BCM47xx/53xx (ARM)**, Subtarget **Generic**,
   Target Profile **Linksys EA6900**. Add LuCI and anything else you want.
3. `make -j$(nproc)`. The images are in `bin/targets/bcm53xx/generic/`:
   `openwrt-bcm53xx-generic-linksys_ea6900-squashfs.trx` (install/upgrade) and `-initramfs.trx`.

## Flash layout (Asus-style CFE, as OpenWrt sees it)

| Offset | Size | Name | |
|---|---|---|---|
| 0x0000000 | 512 KiB | boot | the CFE |
| 0x0080000 | 1 MiB | nvram | live nvram (64 KiB used) |
| 0x0180000 | 512 KiB | nvram | Linksys **devinfo** (OpenWrt names it a second "nvram"): the unit's factory radio calibration, MAC, model, serial number, WPS PIN and default passphrase. OpenWrt does not use or write it. **Never erase it.** |
| 0x0200000 | 126 MiB | firmware | TRX: kernel (4 MiB) + UBI (rootfs + rootfs_data) |

## Known limitations

* **No wireless** (BCM4360, AC-PHY; see *What works*).
* **USB 3.0 stick present at boot**: its first USB 3.0 link training fails, the xHCI port stays in
  `Link:Polling`, and the stick keeps switching to USB 2.0 and back (`usb usb2-port1: Cannot enable`,
  `error -71`). It sometimes recovers after 30–60 s. Until its power is cut, the stick does not train
  again. Switching USB power on later (after xHCI, after the USB 2.0 core, with up to 2 s extra wait)
  did not help in 24 test boots, so the cause is not the power-on order. Workaround: replug the stick
  after boot. Hot-plugging is fine.
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
