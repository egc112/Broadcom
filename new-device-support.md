# Getting a Broadcom Northstar router supported in OpenWrt

How to bring a Broadcom ARM router (OpenWrt target **bcm53xx**: BCM4708, BCM4709, BCM47094) that OpenWrt does
not support yet into OpenWrt: the board itself, its Wi-Fi with [b43-next](https://github.com/aleferri/b43-next),
and the hardware flow accelerator (FA). The worked example is the **Linksys EA6900 v1**, added this way in
[openwrt/openwrt#26316](https://github.com/openwrt/openwrt/pull/26316).

Status 2026-11-25. Several of the pull requests this page builds on are not merged yet (see
[The pull requests](#the-pull-requests)); details may change with them.

## Three parts, three pull requests

| Part | What it gives | Depends on | EA6900 example |
|---|---|---|---|
| **1. Board** | OpenWrt boots, wired ports, USB, LEDs, buttons, sysupgrade | nothing | [#26316](https://github.com/openwrt/openwrt/pull/26316) |
| **2. Wi-Fi** | `kmod-b43-next` as the board's Wi-Fi driver | the board, and [#26717](https://github.com/openwrt/openwrt/pull/26717) (b43-next) | one line in the board's image definition |
| **3. FA** | hardware NAT/routing offload at gigabit speed | the board, [#25131](https://github.com/openwrt/openwrt/pull/25131) (CPU port 8) and an FA driver | port 5 and the WAN MAC in the DTS |

Keep them apart. A board pull request that also brings a new Wi-Fi driver or offload is harder to review, and
each part can be merged when its own dependencies are in. The [build kits](README.md) follow the same split: the
EA6900 board kit, then the EA6900 parts of the b43-next kit and the FA kit.

## Before you start

- **A way back that does not need OpenWrt.** A serial console, or the bootloader's own recovery: CFE TFTP or its
  mini web server (the ASUS rescue mode), Netgear's NMRP. Try it once before the first OpenWrt flash, and keep a
  known-good image of the current firmware for it. The EA6900 port was done without serial, through the mini CFE
  of an ASUS-style CFE.
- **Backups, read-only.** Copy the CFE and nvram partitions off the router (`dd` of their mtd devices), and save
  `nvram show`. The nvram dump holds passwords and keys: keep it private.
- **Do not write nvram or the CFE** while porting. OpenWrt only reads nvram (MAC addresses, Wi-Fi calibration);
  its own configuration is in UCI.

## 1. Collect the board's facts

Everything below can be read from the running stock firmware, DD-WRT or FreshTomato, over SSH or telnet, without
changing anything. The CFE's built-in default nvram (`strings` of the CFE partition) is a good source for the
GPIOs and the calibration.

| What | Where to look | EA6900 v1 |
|---|---|---|
| SoC and switch | `dmesg` (chip id, `robo id`), `/proc/cpuinfo` | BCM4708A0, switch BCM53011 |
| RAM | `/proc/meminfo` | 256 MiB (128 MiB of it highmem) |
| Flash, ECC | `dmesg`, `/proc/mtd` | 128 MiB NAND, BCH-8 |
| Partitions, dual boot | `/proc/mtd`, nvram `bootpartition`, `partialboots` | one `linux` TRX at 0x200000 (dual boot gone with the ASUS-style CFE) |
| nvram | `/proc/mtd`, `nvram_space` | at 0x80000, 64 KiB |
| Switch ports | nvram `vlan1ports` (LAN), `vlan2ports` (WAN) | `1 2 3 4 5*` / `0 5u`: WAN = port 0, LAN 1-4 = ports 1-4 |
| MAC addresses | nvram `et0macaddr`, `wan_hwaddr`, `0:macaddr`, `1:macaddr` | LAN = et0macaddr, WAN = +1 |
| Radios | nvram `0:devid`, `1:devid`, or `lspci -nn` | two BCM4360, `0x43a1` (2.4 GHz) and `0x43a2` (5 GHz) |
| Wi-Fi calibration | nvram `0:`/`1:` sets (or `pci/1/1/...`), `sromrev` | in nvram, sromrev 11, `femctrl` 3 |
| Buttons, LEDs, USB power | CFE default nvram (`gpioN=...`, `reset_gpio`), then test each one | WPS 7, reset 11, USB VBUS 9 (USB 3.0) and 10 (USB 2.0), LEDs 6 and 8 |
| Console | `dmesg` | ttyS0, 115200 |

Confirm every GPIO by hand on the router (switch it, look what changes): the defaults are not always right. On
the EA6900 the second LED pin turned out to drive the same logo LED as the first.

**Find the nearest supported board.** Same vendor, same SoC, same flash: its DTS is the template. For the EA6900
that was the EA6500 v2 (same Linksys family, RAM and NAND); the differences were the WAN port (0, not 4), a second
USB power GPIO, the LEDs and the reset button.

## 2. The board

### Files

| File | What to add |
|---|---|
| `target/linux/bcm53xx/patches-6.18/3xx-ARM-dts-BCM5301X-add-<board>.patch` | the new `.dts` and its line in `arch/arm/boot/dts/broadcom/Makefile`; run `make target/linux/refresh` |
| `target/linux/bcm53xx/image/Makefile` | `define Device/<vendor>_<model>`, `DEVICE_PACKAGES` without a Wi-Fi driver (that is part 2) |
| `target/linux/bcm53xx/base-files/etc/board.d/02_network` | the board in the list that takes the MACs from `et0macaddr` |
| `target/linux/bcm53xx/base-files/etc/board.d/01_leds` | LED triggers, e.g. the WAN LED on the `wan` link |
| `package/utils/nvram/files/nvram-bcm53xx.init` | Linksys and other dual-image boards: clear `partialboots`, or the CFE switches to the other image after a few boots (bump `PKG_RELEASE`) |

### The DTS: switch on CPU port 8

Write the switch in the layout of [#25131](https://github.com/openwrt/openwrt/pull/25131): **port 8** (IMP0,
`gmac2`) is the CPU port, ports 5 and 7 are disabled, and `gmac2` takes the board's MAC address. Port 8 is the right CPU port for three reasons:

1. **It is the switch's management port** (IMP0). The switch sends some frames to its management port whatever
   port is set as the CPU port: frames it cannot place, such as a VLAN that is not in its VLAN table (the miss
   path), and management frames. With the CPU on port 5 these end on port 8, where nobody listens.
2. **That makes a VLAN-tagged WAN work**, as some ISPs require (for example `wan.35` with PPPoE):
   [openwrt/openwrt#13691](https://github.com/openwrt/openwrt/issues/13691), broken on bcm53xx since OpenWrt 23.05,
   is what #25131 fixes. The trade-off, measured in #25131: since the miss path now ends at the CPU, VLAN frames
   still reach the CPU after their VLAN interface is deleted; the kernel drops them instead of the switch.
3. **The flow accelerator sits in front of it**, so this is also the layout part 3 builds on.
`bcm-ns.dtsi` already connects port 8 to `gmac2`, port 5 to `gmac0` and port 7 to `gmac1`.

**Every Northstar router with the SoC's built-in switch has port 8, with or without an FA.** The switch in the
BCM4708, BCM4709 and BCM47094 always has the three CPU-capable ports 5, 7 and 8, wired to `gmac0`, `gmac1` and
`gmac2`. On chips with an FA, the FA sits between `gmac2` and port 8; on chips without one, port 8 is a plain CPU
port. That is why #25131 moves every bcm53xx board with a switch to port 8, FA or not; only boards without the
built-in switch (the Meraki MR26 and MR32) keep their old conduit.

From the EA6900 DTS:

```dts
	nvram@1c080000 {
		compatible = "brcm,nvram";
		reg = <0x1c080000 0x100000>;

		et0macaddr: et0macaddr {
			#nvmem-cell-cells = <1>;
		};
	};
...
&gmac2 {
	nvmem-cells = <&et0macaddr 0>;
	nvmem-cell-names = "mac-address";
};

&srab {
	status = "okay";

	ports {
		port@0 {
			label = "wan";
		};

		port@1 {
			label = "lan1";
		};
		...
		port@4 {
			label = "lan4";
		};

		port@5 {
			status = "disabled";
		};

		port@7 {
			status = "disabled";
		};

		port@8 {
			label = "cpu";
		};
	};
};
```

Do not set `dsa-tag-protocol` in a board DTS: the tag is the business of the FA driver (part 3).

Until #25131 is merged, the other bcm53xx boards in OpenWrt still use port 5 as their CPU port, so a new board
on port 8 is the odd one out. Say why in the pull request; the EA6900 commit message does ("The CPU port is switch
port 8 (IMP0, gmac2), the switch's management port").

The full EA6900 DTS, image definition and board.d lines:
[`ea6900-board-kit/patches/1-EA6900-1-board.patch`](ea6900-board-kit/patches/1-EA6900-1-board.patch).

### Test

1. **Initramfs first.** Build an initramfs image and boot it through the recovery: everything runs from RAM, so a
   wrong flash or ECC setting cannot damage anything.
2. Check: every switch port, WAN DHCP, the MAC addresses (the same as the stock firmware's), both USB ports with a
   stick, every LED and button, `/proc/mtd`, `nvram show`.
3. Then the squashfs image, and: ten cold boots, warm reboots, sysupgrade with and without keeping the settings,
   and the recovery once more.

## 3. Wi-Fi with b43-next

### Does b43-next drive the radios?

b43-next drives the BCM4360 and BCM4352 (802.11ac), the BCM4331 and the N-PHY chips (802.11n). OpenWrt's boot log
names each radio chip, even before it has a driver; from an R6400 v2:

    bcma-pci-bridge 0000:01:00.0: bus1: Found chip with id 0x4331, rev 0x02 and package 0x08
    bcma-pci-bridge 0001:01:00.0: bus2: Found chip with id 0x4360, rev 0x03 and package 0x01

In nvram the `devid` can be a board-specific variant (the EA6900's `0x43a1`/`0x43a2` are both BCM4360). Newer chips (BCM43602, BCM4366, Wi-Fi 6) are not covered by
b43-next.

### Calibration data (SPROM)

The radio needs its board's calibration: TX power, the power amplifier and receive gain values, the front-end
type (`femctrl`).

- **The usual case on these routers:** the values are in the router's nvram, as `0:`/`1:` sets or `pci/1/1/...`
  (the EA6900), or in the chip's own SROM/OTP. The driver reads them itself.
- **Harder:** they are elsewhere in flash, in a vendor format (for example a Meraki board-config partition). Then
  they have to be extracted and turned into a fallback SPROM first.

Check b43-next's `dmesg` lines after the first load: the SPROM revision it found, and no errors about missing
calibration.

### The change: a checklist

If OpenWrt already has the router (part 2 done) and b43-next drives its radios, it comes down to this:

1. **The driver package:** [#26717](https://github.com/openwrt/openwrt/pull/26717) (in the b43-next kit:
   `2-B43-1`) adds `kmod-b43-next` and its firmware to OpenWrt.
2. **One line in `target/linux/bcm53xx/image/Makefile`:** the device's `DEVICE_PACKAGES` gets
   `$(IEEE8021X) kmod-b43-next`, OpenWrt's default wpad plus the driver. For the R7000 (two BCM4360):

   ```make
   define Device/netgear_r7000
     DEVICE_MODEL := R7000
     DEVICE_PACKAGES := $(IEEE8021X) kmod-b43-next $(USB3_PACKAGES)
     ...
   ```

   A device that had `$(B43)` (kmod-b43) gets this *instead*: `kmod-b43-next` conflicts with `kmod-b43`, and
   `$(B43)` already brings a wpad.
3. **Firmware for the other radio types:** the 802.11ac files (BCM4352, BCM4360) come with `kmod-b43-next`. A
   BCM4331 also needs `b43-firmware-784-ht` on the same line (the R6400), an N-PHY chip `b43-firmware-784-n`;
   the [table in the b43-next kit](b43-next-build-kit/README.md#which-firmware-each-radio-needs) has every type.
4. **In menuconfig: `kmod-b43-next` as `M`** (Kernel modules, Wireless Drivers; a package, not a kernel option).
   It then goes only into the images of the devices whose line lists it; `*` would put it into every image of the
   build. Keep "Use a per-device root filesystem that adds profile packages" on in a multi-device build.
5. **After the first boot, check the calibration data:** `Using SPROM revision ... provided by platform` (or the
   chip's own SROM) for each radio, and no `Invalid SPROM` without a fallback after it. A supported chip without its
   board's values does not work properly.

For another wpad on all devices, change the `IEEE8021X :=` line at the top of the same Makefile (for example to
`wpad-openssl`); selecting a second wpad in menuconfig stops the build with a package conflict.

Test both bands as access points with a client, a throughput run per band, and a soak of an hour or more. Post the
results in #26717 or a small device pull request on top of it, as
[#26718](https://github.com/openwrt/openwrt/pull/26718) (RT-AC56U) and
[#26719](https://github.com/openwrt/openwrt/pull/26719) (RT-AC68U, RT-AC66U B1) do.

## 4. The flow accelerator (FA)

### Does the router have one?

Every BCM47094 (chip id 53030) has it. A BCM4708/BCM4709 (chip id 53010 or 53018) has it when the switch revision
is 3 or higher. Both are in OpenWrt's boot log; from an R6400 v2:

    bcma-host-soc 18000000.axi: bus0: Found chip with id 53030, rev 0x00 and package 0x02
    b53-srab-switch 18007000.ethernet-switch: found switch: BCM53011, rev 0

Chip id 53030 decides here: a BCM47094 has the FA even though its switch reports revision 0.

The board must also have **switch port 5 free**: the FA uses it (see below). On the RT-AC87U, for example, port 5
is the link to its Quantenna 5 GHz chip, so that board cannot use the FA.

### Port 5: a second CPU port

The FA forwards a known connection by itself, but some packets must reach the CPU **past** it: TCP FIN and RST
and TTL 1 in both drivers, and in Florian Fainelli's driver also TCP SYN, TTL 0, oversized packets and packets not
addressed to the router.
Through port 8 they would go through the FA, so the switch sends them to port 5, connected to `gmac0`, which
bypasses it. Both FA drivers need this: ours ([#26789](https://github.com/openwrt/openwrt/pull/26789)) uses the
FA only on boards with port 5 open, and Florian's refuses hardware offload without it.

On top of the board DTS, the FA part opens port 5 again. The EA6900 lines (`329` in the FA kit; `bcm-ns.dtsi`
already gives port 5 its `ethernet = <&gmac0>`):

```dts
		port@5 {
			fixed-link {
				speed = <1000>;
				full-duplex;
			};
		};
```

and gives the WAN port its own MAC address from nvram (`385`), so the port keeps it when it moves between the two
CPU ports:

```dts
		port@0 {
			label = "wan";

			nvmem-cells = <&et0macaddr 1>;
			nvmem-cell-names = "mac-address";
		};
```

#26789 opens port 5 on the RT-N18U and the EA6900, the FA kit on all 32 boards that can use it.

### New boards and port 5

A board added with port 5 closed gets no FA, with either driver, until someone opens port 5 for it. So every
FA-capable board with a free port 5 should end up with port 5 open. When depends on what is in OpenWrt:

- **The FA driver is in OpenWrt:** add the board with port 5 open from the start, as above.
- **Not yet (today):** keep port 5 disabled in the board pull request, and say in it that the board is FA-capable
  and has port 5 free, so the FA pull request can include it. Opening port 5 before the FA driver is in is not
  harmless: with two CPU ports, OpenWrt main keeps port 8 as the default only on BCM58xx (`703`), so on a BCM5301x
  board DSA would put all ports on port 5 (`gmac0`) and undo the port 8 layout. #26789 extends that rule to
  BCM5301x.

A new FA-capable board with port 5 open, once the FA driver is in OpenWrt (the EA6900's switch with `329` and
`385` applied; `bcm-ns.dtsi` gives port 5 its `ethernet = <&gmac0>` and port 8 its `ethernet = <&gmac2>`):

```dts
&gmac2 {
	nvmem-cells = <&et0macaddr 0>;
	nvmem-cell-names = "mac-address";
};

&srab {
	status = "okay";

	ports {
		port@0 {
			label = "wan";

			nvmem-cells = <&et0macaddr 1>;
			nvmem-cell-names = "mac-address";
		};

		port@1 {
			label = "lan1";
		};
		...
		port@4 {
			label = "lan4";
		};

		/* second CPU port, for the frames that must bypass the FA */
		port@5 {
			fixed-link {
				speed = <1000>;
				full-duplex;
			};
		};

		port@7 {
			status = "disabled";
		};

		port@8 {
			label = "cpu";
		};
	};
};
```

Compared with the board-only DTS, port 5 is no longer `disabled` and has a fixed link, and the WAN port takes its own
MAC address from nvram (here `et0macaddr` + 1, as the stock firmware does), so it keeps it when it moves between
the two CPU ports. With Florian's driver the FA node and the `gmac2` phandle come on top (see below).

To avoid forgetting boards, port 5 could also be opened once for all FA-capable boards (in the SoC's `.dtsi` or the
FA patch), with an opt-out for the few boards that use port 5 for something else, instead of board by board.

### Two drivers, one board layout

| | Ours, [#26789](https://github.com/openwrt/openwrt/pull/26789) | Florian Fainelli's netdev series ([v1](https://patchwork.kernel.org/project/netdevbpf/list/?series=1213213), v2 announced) |
|---|---|---|
| Ports | port 8 data through the FA, port 5 exceptions | the same |
| FA in the DTS | nothing: the driver finds the FA by the chip id | an FA node (`brcm,bcm4708-fa`, `-53011-fa`, `-53012-fa`) and `brcm,flow-accelerator = <&fa>` on `gmac2`; no board is enabled by the series |
| Tag | the switch boots with the regular tag; at boot with hardware flow offloading on, it moves to the prepended tag. So: **reboot after switching hardware offloading on or off** | a new `brcm-fa` tag, chosen by b53 at probe when the DTS describes the FA; no reboot step, but no way to take the FA tag out of the path without changing the DTS |
| Chips | BCM4708, BCM4709, BCM47094 | BCM4708, BCM53011, BCM53012 (tested on BCM53012 only); BCM47094 later |
| Traffic | IPv4 NAT and routing, IPv6, VLAN WAN, ports in a bridge (OpenWrt's `br-lan`) | IPv4 TCP/UDP NAT on standalone ports; bridges, IPv6, VLAN and plain routing are refused |

**The reboot with our driver only switches the tag.** The ports are in the DTS and are there from every boot:
port 8 as the CPU port and port 5 open as the second one. At a normal boot with software and hardware flow
offloading on, a preinit hook moves both conduits from the regular `brcm` tag to `brcm-prepend` ("switched eth0
eth2 to brcm-prepend for hardware flow offloading" in the boot log); only then does the FA get the traffic it can
offload. Without port 5 open, our driver does not use the FA, whatever the tag.

**With Florian's v1, every board needs FA lines in its DTS**, on top of port 8 and port 5:

```dts
/ {
	fa: flow-accelerator@18027c00 {
		compatible = "brcm,bcm53012-fa";	/* or brcm,bcm4708-fa, brcm,bcm53011-fa */
		reg = <0x18027c00 0xc0>;
	};
};

&gmac2 {
	brcm,flow-accelerator = <&fa>;
};
```

The phandle is what makes b53 choose the `brcm-fa` tag at boot. The FA is part of the SoC, but a BCM4708/BCM4709
has it only from switch revision 3, which a device tree cannot tell; so the board decides. That means a DTS change
for every existing board, and one more thing to remember for every new board, as with port 5. BCM47094 boards have
no compatible in v1. v2 may change this, for example with the node in the SoC `.dtsi` and only the phandle per
board.

So a board DTS in the port 8 layout, with port 5 opened by the FA part, fits both drivers.

In short: ours is simpler for board support (no FA lines in any DTS) and offloads more of a default OpenWrt setup
(bridged LAN, IPv6, VLAN WAN, BCM47094), at the cost of a reboot after switching hardware offloading on or off and
some OpenWrt-specific code (the tag switch in b53 and a preinit hook). Florian's needs no reboot and no tag switch,
but every board needs FA lines in its DTS. His series, by the b53 and bgmac maintainer, is the one headed for the
Linux kernel; #26789 serves OpenWrt until it is there.

## The pull requests

| Pull request | What | Status 2026-11-25 |
|---|---|---|
| [#26316](https://github.com/openwrt/openwrt/pull/26316) | Linksys EA6900 v1 board | open |
| [#25131](https://github.com/openwrt/openwrt/pull/25131) | port 8 as the CPU port on all bcm53xx boards (strrs) | open |
| [#26717](https://github.com/openwrt/openwrt/pull/26717) | `kmod-b43-next` | open |
| [#26718](https://github.com/openwrt/openwrt/pull/26718), [#26719](https://github.com/openwrt/openwrt/pull/26719) | b43-next on the RT-AC56U, RT-AC68U and RT-AC66U B1 | open, after #26717 |
| [#26789](https://github.com/openwrt/openwrt/pull/26789) | the FA driver for OpenWrt (with #25131's port 8) | open |
| [netdev series 1213213](https://patchwork.kernel.org/project/netdevbpf/list/?series=1213213) | Florian Fainelli's FA driver for the Linux kernel | v1 under review |

Until they are merged, the [build kits](README.md) put them together for the R6400 v1/v2 and the EA6900. Questions
and reports of new boards: please open an issue.
