# Provenance: b43 AC-PHY patches for the EA6900

This page records where the patches in this folder come from and how the information was
obtained. It is a factual record, not legal advice. Questions or corrections: please open an issue.

## What this folder holds

Patches for Alessio Ferri's experimental b43 AC-PHY driver,
[aleferri/b43-ac-wip](https://github.com/aleferri/b43-ac-wip), the base they apply to. That
project and its own sources are documented in its
[PROVENANCE.md](https://github.com/aleferri/b43-ac-wip/blob/main/PROVENANCE.md). The patches
here are offered to it as well; it is free to take, rework or drop them. Status on
2026-11-02: five are merged there
([#8](https://github.com/aleferri/b43-ac-wip/pull/8), [#9](https://github.com/aleferri/b43-ac-wip/pull/9),
[#12](https://github.com/aleferri/b43-ac-wip/pull/12), [#14](https://github.com/aleferri/b43-ac-wip/pull/14),
[#15](https://github.com/aleferri/b43-ac-wip/pull/15)); the RX DMA burst patch is open there as
[#13](https://github.com/aleferri/b43-ac-wip/pull/13). A finding about PHY register 0x?724 (the TSSI floor
written during the temperature measurement is a constant, not an SROM value) was reported as
[issue #16](https://github.com/aleferri/b43-ac-wip/issues/16) and fixed there by its author.

The patches are changes to the Linux b43 driver and are licensed **GPL-2.0**, like the code
they change.

## How information was obtained

1. **Bus traces of the stock driver (black box).** On our own Netgear R7000 (BCM4709, two
   BCM4360, the same radio and front-end type as the EA6900) Broadcom's driver `wl` runs under
   DD-WRT. A kernel module from the b43-ac-wip project, `wl-mmio-trap`, records every access
   to the chip's register window while `wl` brings the radio up: which register is written,
   with which value, in which order. It does not look into `wl` itself; it watches the bus.
   This shows *what the hardware is told*, not how the driver computes it, and involves no
   Broadcom code. The captures are public:
   `router-data/r7000/mmio-cold-2g6.zip` and `mmio-cold-5g36-80.zip` in b43-ac-wip.
2. **Our own driver traced the same way.** A private debug patch records every PHY and radio
   access of b43 during a bring-up, so the two sequences can be compared op by op.
3. **Read-back of the stock driver's state.** On the same R7000, with `wl` running, a small
   tool reads PHY tables and registers back through the chip's register window (read only, as
   any register dump). This shows the values `wl` left in the hardware. It was used to find
   which table entries differ from b43's, for the 2.4 GHz FEM control table (published as
   `router-data/r7000/fem-table-2g-ch6.txt` in b43-ac-wip) and for one PMU register bit.
4. **Board data.** The R7000's radio nvram values, public in b43-ac-wip as
   `router-data/r7000/nvram-radios.txt`.
5. **Measurements** on the EA6900: calibration and TSSI results read back from the hardware,
   iperf3 throughput tests in both directions on both bands, and A/B tests (with and without
   a change).
6. **Open-source drivers.** The Linux `bgmac` driver programs the same DMA engine on the
   same SoC family (Northstar); its RX burst and prefetch values are used as they are.
7. **Board-data variation on the R7000.** To see which board value a register depends on, one radio
   nvram variable of the R7000 is changed in RAM only (never committed), `wl` is reloaded so it
   reads it, and the bring-up is traced again as in 1. Used for issue #16 (tssifloor removed) and to
   check other people's patches against the stock driver.

## Not used, not published

* No decompiled or disassembled Broadcom code is used in *our* patches (this folder and our patches
  in the build kit): knowledge from studying the `wl` binary does not go into a patch we publish.
  The build kit also carries Alessio Ferri's driver unchanged; its sources are his, see *Build kit*.
* This repository does not contain Broadcom's binary drivers, firmware extracted by us, images, or
  the calibration data of our routers. The build kit downloads the b43 firmware at build time.
* Private stopgaps that copy calibration *results* of the stock driver into b43 are not
  published.

## Sources per patch

| Patch | Author | Based on | b43-ac-wip |
|---|---|---|---|
| `0001-b43-AC-PHY-2.4-GHz-values-for-the-calibration-radio-setup.patch` | Erik Conijn | b43-ac-wip's own code (the six radio MODs at two places); the values on 2.4 GHz from the R7000 bus trace at 2.4 GHz ch 6 (records cited in the code); before/after measurements on the EA6900 (calibration results, throughput) | [#8](https://github.com/aleferri/b43-ac-wip/pull/8) (merged) |
| `0001-b43-AC-PHY-use-the-2.4-GHz-AvVmid-entry-on-2.4-GHz.patch` | Erik Conijn | b43-ac-wip's own AvVmid table and its comment that band 0 is 2.4 GHz; the R7000's pdgain2g from its public nvram; the value wl writes at 2.4 GHz from the R7000 bus trace (records cited in the code); the table entries that differ found by read-back on the R7000; before/after TSSI measurements on the EA6900 | [#9](https://github.com/aleferri/b43-ac-wip/pull/9) (merged) |
| `0001-b43-AC-PHY-LOFT-LUT-base-is-0-on-2.4-GHz.patch` | Erik Conijn | b43-ac-wip's own fill and reset passes; the values wl writes at 2.4 and 5 GHz from the R7000 bus traces (records cited in the code); read-back of the LUTs on the EA6900 after bring-up | [#12](https://github.com/aleferri/b43-ac-wip/pull/12) (merged) |
| `0001-b43-AC-PHY-program-the-RX-DMA-burst-length-and-prefe.patch` | Erik Conijn | the RX values of the Linux `bgmac` driver (`bgmac_dma_rx_enable()`) for the same DMA engine; throughput measurements on the EA6900 | [#13](https://github.com/aleferri/b43-ac-wip/pull/13) (open) |
| `0001-b43-AC-PHY-femctrl-3-FEM-tables-sub-0-and-sub-3.patch` | Erik Conijn | b43-ac-wip's own FEM table mechanism; the 5 GHz table and PHY 0x040a from the R7000 bus trace (records cited in the code); the 2.4 GHz table and the PMU regctl value by read-back on the R7000 (the read-back file is part of the patch); an A/B test of the PMU bit on the EA6900; throughput measurements | [#14](https://github.com/aleferri/b43-ac-wip/pull/14) (merged) |
| `0001-b43-AC-PHY-mdelay-for-the-5.85-ms-delay.patch` | Erik Conijn | a build fix: ARM's `udelay()` limit; the delay itself is b43-ac-wip's | [#15](https://github.com/aleferri/b43-ac-wip/pull/15) (merged) |

The patches are independent of each other; each applies on its own to b43-ac-wip
`main` at 7ae3a61, and all six apply together.

All carry `Assisted-by: Claude:claude-opus-5-5`. They were written with the help of an AI
assistant (Claude Code), which also did the trace comparison; every change was tested on the
hardware.

## Build kit

[`../build-kit/`](../build-kit/) is a recipe for the image we test: a plain OpenWrt tree plus the parts
below. Tested on OpenWrt main r37507-4e16c2ed8f, 2026-11-02. Alessio Ferri's driver is included
unchanged and documented by his own provenance; the sources of our own patches follow the rules of
this document and are listed below.

| Part | Author | Based on |
|---|---|---|
| `patches/board/EA6900.patch` | Erik Conijn | board support as submitted to OpenWrt and reviewed there, [openwrt/openwrt#26316](https://github.com/openwrt/openwrt/pull/26316); no b43 code |
| `patches/board/broadcom.mk.diff` | Erik Conijn | OpenWrt's own `broadcom.mk`: an AC-PHY option next to the existing PHY options, and a firmware entry written like the existing ones for the firmware of Broadcom's driver 6.30.163.46 |
| `patches/kernel/880-*`, `patches/mac80211/816-02-*`, `816-03-*` | Alessio Ferri | his work, copied unchanged from b43-ac-wip `patches/` (commits [1e43a20](https://github.com/aleferri/b43-ac-wip/commit/1e43a20) and [8c234e6](https://github.com/aleferri/b43-ac-wip/commit/8c234e6)); its sources are documented in his [PROVENANCE.md](https://github.com/aleferri/b43-ac-wip/blob/main/PROVENANCE.md), among them data from Broadcom's GPL-released `wl` objects |
| `patches/mac80211/817-*`, `818-*` | Alessio Ferri | his code: the diffs of b43-ac-wip's `b43/` between the 816 base and commits [3517def](https://github.com/aleferri/b43-ac-wip/commit/3517def) and [bc63d98](https://github.com/aleferri/b43-ac-wip/commit/bc63d98), made by us with `git diff`, nothing added; same sources as above |
| `patches/mac80211/904`, `906`, `917`, `942`, `946`, `949` | Erik Conijn | the patches of this folder, see *Sources per patch* |
| `patches/mac80211/926` | Erik Conijn | the TX values of the Linux `bgmac` driver for the same DMA engine; throughput measurements on the EA6900. In b43-ac-wip as [#6](https://github.com/aleferri/b43-ac-wip/pull/6) (merged) |
| `patches/mac80211/934`, `935`, `936` | Erik Conijn | profiles (`perf`) of b43 on the EA6900 and b43's own code: locking and DMA cache handling, no Broadcom data. In #6 |
| `patches/mac80211/939` | Erik Conijn | the A-MSDU bit of the RX status as named in the Linux `brcmsmac` driver, which drops such frames too; the faulty frame as received on the EA6900. In #6 |
| `patches/mac80211/950` | Erik Conijn | R7000 bus trace with `tssifloor2g/5g` removed from its nvram (method 7); reported as [issue #16](https://github.com/aleferri/b43-ac-wip/issues/16), fixed in b43-ac-wip by its author |
| `files/`, `diffconfig`, `apply.sh` | Erik Conijn | interrupt layout from throughput measurements on the EA6900; the configuration of the tested image |

**Firmware.** b43 needs Broadcom's firmware. The kit does not contain it: the build downloads
`broadcom-wl-6.30.163.46.tar.bz2`, the tarball the b43 project documented at lwfinger.com, from the
Gentoo mirror (or the Web Archive copy of the original site, byte-identical), checks its SHA-256 and
extracts the files with b43-fwcutter, as OpenWrt does for the other b43 firmware versions.

The kit's patches, `apply.sh` and README were written with the help of an AI assistant (Claude Code);
the patches carry `Assisted-by: Claude:claude-opus-5-5`. Every image built from the kit was tested on
the EA6900, the last one in a soak.
