# Provenance: b43 AC-PHY patches for the EA6900

This page records where the patches in this folder come from and how the information was
obtained. It is a factual record, not legal advice. Questions or corrections: please open an issue.

## What this folder holds

Patches for Alessio Ferri's experimental b43 AC-PHY driver,
[aleferri/b43-ac-wip](https://github.com/aleferri/b43-ac-wip), the base they apply to. That
project and its own sources are documented in its
[PROVENANCE.md](https://github.com/aleferri/b43-ac-wip/blob/main/PROVENANCE.md). The patches
here are offered to it as well; it is free to take, rework or drop them.

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
   tool reads PHY tables back through the chip's register window (read only, as any register
   dump). This shows the values `wl` left in the hardware. It was used to find which table
   entries differ from b43's.
4. **Board data.** The R7000's radio nvram values, public in b43-ac-wip as
   `router-data/r7000/nvram-radios.txt`.
5. **Measurements** on the EA6900: calibration and TSSI results read back from the hardware,
   and iperf3 throughput tests in both directions on both bands.

## Not used, not published

* No decompiled or disassembled Broadcom code is used in these patches, and none is published
  here: knowledge from studying the `wl` binary does not go into a published patch.
* This repository does not contain Broadcom's binary drivers, firmware extracted by us, or the
  calibration data of our routers.
* Private stopgaps that copy calibration *results* of the stock driver into b43 are not
  published.

## Sources per patch

| Patch | Author | Based on |
|---|---|---|
| `0001-b43-AC-PHY-2.4-GHz-values-for-the-calibration-radio-setup.patch` | Erik Conijn | b43-ac-wip's own code (the six radio MODs at two places); the values on 2.4 GHz from the R7000 bus trace at 2.4 GHz ch 6 (records cited in the code); before/after measurements on the EA6900 (calibration results, throughput) |
| `0001-b43-AC-PHY-use-the-2.4-GHz-AvVmid-entry-on-2.4-GHz.patch` | Erik Conijn | b43-ac-wip's own AvVmid table and its comment that band 0 is 2.4 GHz; the R7000's pdgain2g from its public nvram; the value wl writes at 2.4 GHz from the R7000 bus trace (records cited in the code); the table entries that differ found by read-back on the R7000; before/after TSSI measurements on the EA6900 |

The two patches are independent of each other; each applies on its own to b43-ac-wip
`main` at 7ae3a61.

All carry `Assisted-by: Claude:claude-opus-5-5`. They were written with the help of an AI
assistant (Claude Code), which also did the trace comparison; every change was tested on the
hardware.
