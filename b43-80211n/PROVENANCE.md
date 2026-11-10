# Provenance and legal notes

This page explains where every part of the b43-80211n patch series comes from and how the
information was obtained. Anyone can check it. It covers **rc13** (patches 890–895, a
wifi-scripts patch and kernel patch 880 by Alessio Ferri, on top of Rosen Penev's
openwrt/openwrt#25922; rc12 had an older 880; rc11 was the same without 880; rc10 had the same patches
as 862–868, plus 864, on top of an older version of his series; rc9 was rc10 without 868 and
with the first version of 866) and the older stand-alone
series **rc8** (patches 820–839, in [patches-rc8](patches-rc8/)).

It is a factual record, not legal advice. Questions or corrections: please open an issue.

## Summary

* The patches of this repository are changes to the Linux **b43** driver (and, in rc9, one change
  to OpenWrt's wifi-scripts) and are licensed **GPL-2.0**, like the code they change.
* They are based on open source code (Linux b43, brcmsmac, bcma, ssb, mac80211 and ath9k), on the
  IEEE 802.11 standard, on source files Broadcom published under an open license, on patches by
  Rosen Penev (credited, with his authorship kept), and on our own measurements.
* The measurements are black-box observations of the hardware:
  * reading the router's registers back while Broadcom's own driver runs;
  * radio captures with an independent sniffer;
  * throughput and latency tests.
* Since rc12 there is one patch that is not ours: 880, a bcma/ssb kernel patch by Alessio Ferri, copied
  unchanged from his AC-PHY port of b43 (see *Sources per patch (rc13)*). Its own commit message
  names its sources.
* **No decompiled or disassembled Broadcom code is used in our patches since rc7, and no Broadcom code is
  copied.** One earlier patch, 822 in rc3–rc6, was ported from a decompiled Broadcom driver. For rc7 it was
  rewritten from open sources and measurements only; the full account is below. One later patch, 897
  (several APs on the BCM4331), uses two facts, an SHM address and a mask, that we first found by reading the
  disassembly of one function of Broadcom's wl driver. Both facts are documented without it: the address in
  Broadcom's own public header, the mask in the ucode that b43 loads (see *Patches 897 and 898*).
* This repository does not contain, and will not publish:
  * Broadcom's binary drivers;
  * decompiled or disassembled code;
  * firmware extracted by us;
  * the calibration data of our routers.

## Licenses of the sources

| Source | License | Used for |
|---|---|---|
| Linux b43 driver | GPL-2.0 | the code base all patches change |
| Linux brcmsmac (Broadcom's own open driver for older chips) | ISC | rates, TX headers, A-MPDU, block ack, duration rules, FIFO setup sequence |
| Linux bcma, ssb | GPL-2.0 | names of ChipCommon and board-flag bits |
| Linux mac80211, ath9k | GPL-2.0 | the mac80211 APIs; the block-ack window and power-save handling patterns |
| Broadcom header and source files published under the ISC license (e.g. in router GPL source releases) | ISC | names and meanings of BCM4331 chip-control bits and board flags (patch 822) |
| Rosen Penev's patches, openwrt/openwrt#25922 | GPL-2.0 (his Signed-off-by) | rc9: the base, not part of this repository; rc8: 839 (his patch, unchanged), 835 (based on his work) |
| OpenWrt wifi-scripts (`hostapd.uc`) | GPL-2.0 | rc9: the frame bursting default follows the existing 5 GHz (VHT) default there |

ISC is a permissive license and may be combined with GPL-2.0 code. brcmsmac is already part of the
Linux kernel under that license.

## How information was obtained

1. **Reading open source code**, mainly brcmsmac, which drives older Broadcom chips with the same
   MAC design. The commit text of each patch names the brcmsmac functions it follows.
2. **Reading the hardware state back** (black box). The router runs Broadcom's own driver: Netgear's
   firmware or DD-WRT. A small tool of our own then reads the chip's registers and PHY tables
   through `/dev/mem`. This shows *what values the hardware holds*, not how the driver computes
   them; it involves no Broadcom code. b43 was historically developed this way too, by
   comparing the hardware state against the vendor driver.
3. **Radio measurements**: an independent monitor-mode sniffer (MediaTek), time-aligned with the
   router's own receive log, plus iperf3 throughput tests, soak tests and phone tests.
4. **Firmware**: b43 needs Broadcom's ucode. The images use OpenWrt's standard b43 firmware package:
   at build time it downloads Broadcom's `broadcom-wl-5.100.138` driver release and extracts the
   ucode (version 666.2) with `b43-fwcutter`, as every OpenWrt build with b43 does. We did not
   modify or add firmware.

## Sources per patch (rc13)

rc13 is rc11 (below) plus one kernel patch and one dependency in OpenWrt's `broadcom.mk`:

| Patch | Author | Based on |
|---|---|---|
| 880 | Alessio Ferri | his work, copied unchanged from [aleferri/b43-ac-wip](https://github.com/aleferri/b43-ac-wip) `patches/` (commit [16eb94d](https://github.com/aleferri/b43-ac-wip/commit/16eb94d); rc12 had the version of [1e43a20](https://github.com/aleferri/b43-ac-wip/commit/1e43a20)); the same file as in our [EA6900 build kit](../linksys-ea6900/build-kit/). Per its commit message: the SPROM revision 11 field layout follows the public bcmdhd SROM parser table (`include/bcmsrom_tbl.h`, GPL-2.0); the power management and chip control values are bus captures of Broadcom's driver on BCM4360 rev 3 hardware; the rest is the existing Linux bcma, ssb and bcm47xx NVRAM code. His repository's [PROVENANCE.md](https://github.com/aleferri/b43-ac-wip/blob/main/PROVENANCE.md) documents the sources of his project as a whole |

`+@DRIVER_11AC_SUPPORT` in `kmod-b43` is ours and only an OpenWrt build option: it selects
hostapd's existing 802.11ac support and contains no driver code.

We did not change 880. On the R6400 we checked it by its effect only: the BCM4360's power
management unit is set up at boot, the 2.4 GHz radio and the watchdog work as with rc11.

## Sources per patch (rc11)

rc11 is applied on top of openwrt/openwrt#25922 at fe90f890dc, by Rosen Penev (rc9 and rc10:
at 0615bc0150). His series is not part of this repository; its sources are his to document.
It contains his own versions of several rc8 patches (821, 822, 823, 824, 826, 830, 831, 833,
837, 838), whose sources are listed in the rc8 table below, and, since fe90f890dc, two patches
by Erik Conijn under his own name (829, 32-bit table reads; 831, the R6400's analog PA control).
rc11's patches are rc10's, renumbered (862 → 890, 863 → 891, 865 → 892, 866 → 893,
867 → 894, 868 → 895); rc10's 864 is dropped, because his series now does the same.

| Patch | Author | Based on |
|---|---|---|
| 890 (862) | Erik Conijn | b43's own NAPI code in his series; the point was raised by the openwrt-ai review of openwrt/openwrt#25922 |
| 891 (863) | Erik Conijn | hardware read-back of PHY table 9 under Broadcom's driver (DD-WRT) on the R6400 v1; throughput and signal measured with and without the upload; board flags from Linux ssb/bcma |
| 892 (865) | Erik Conijn | b43 code only; the gain indices are the ones measured for rc8's 824 |
| 893 (866) | Erik Conijn | see *Patch 893* below: b43's open N-PHY calibration code, and measurements on the hardware |
| 894 (867) | Erik Conijn | brcmsmac `brcms_c_ampdu_shm_upd()` (the ucode limits for a 64 KiB A-MPDU) and the shared-memory names in brcmsmac's `d11.h`; throughput measurements |
| 895 (868) | Erik Conijn | brcmsmac `brcms_c_recv()`, which drops frames with `RXS_AMSDU_MASK` set in the RX status; the replay lockup observed on a Linksys EA6900 with an ath11k client; mac80211's replay check |
| wifi-scripts | Erik Conijn | OpenWrt's `hostapd.uc`, which already sets `tx_queue_data2_burst` 2.0 for VHT; throughput and latency measurements |

All carry `Assisted-by: Claude:claude-opus-5-5`. They were written with the help of an AI
assistant (Anthropic's Claude), which also helped run the measurements and keep this record.

## Patch 893: RX I/Q calibration

893 (rc9 and rc10: 866) estimates the I/Q imbalance of each of the BCM4331's three receive chains and writes a
compensation, on the operating channel (since rc10 once per PHY init, at 2.4 GHz only). It uses
only the receiver: no test tone, no loopback, no radio register writes.

| Part | Source |
|---|---|
| The estimator (start, wait time, sample count, then I power, Q power and I/Q product per chain) | Linux b43 `phy_n.c`, `b43_nphy_rx_iq_est()`, and the N-PHY register names in `phy_n.h` (`B43_NPHY_IQEST_*`, 0x129–0x12B; chain 1 at 0x12C, chain 2 at 0x134). The same estimator exists in brcmsmac (`wlc_phy_rx_iq_est_nphy`) |
| The coefficients a and b from an estimate | Linux b43 `b43_nphy_calc_rx_iq_comp()` for PHY rev ≥ 3 (a → COMPA, b → COMPB); the same in brcmsmac (`wlc_phy_calc_rx_iq_comp_nphy`). 866 does the same arithmetic in 64 bits |
| The compensation registers of chains 1 and 2 (0x09A/0x09B, 0x09C/0x09D) | Linux b43 `phy_n.h` (`B43_NPHY_C1_RXIQ_COMPA0` … `B43_NPHY_C2_RXIQ_COMPB1`) |
| The third chain: estimator results at 0x13A–0x13F, compensation at 0x09E/0x09F | Measured on the hardware (R6400 v1 and v2): the six registers after chain 2's hold a third, independent estimate in the same layout; the coefficients computed from it, written to 0x09E/0x09F (the next pair after chain 2's), bring that chain's image rejection from 25–27 dB to 48–52 dB, and the MCS 15 frame loss falls with it (below) |
| Use the quietest 8 of 32 estimates per chain | Own design, from 200 single estimates on the hardware: estimates taken while frames are on the air scatter by 5–12°, the quietest agree within 0.7° |
| Run after the transmit I/Q and LO calibration of Rosen Penev's series (rc11) | brcmsmac `wlc_phy_cal_perical_nphy_run()`, which calibrates TX first, then RX |
| Skip the calibration before the PHY is initialized; calibrate only the operating channel, once per PHY init, and write the stored result back when switching to it again; no calibration while no interface is up, on scan channels or on mac80211's off-channel default (`IEEE80211_CONF_OFFCHANNEL`); 2.4 GHz only | Own design (rc10), from b43's own init order, the mac80211 code that sets `IEEE80211_CONF_OFFCHANNEL`, and logs on the hardware |
| The effect | Measured: MPDU loss of a client at a fixed MCS 15, alternated blocks of 20 s, ~1 million frames per state (R6400 v1, channel 6: 32.8 % without, 2.1 % with); TCP throughput; residual image rejection in a 9.5-hour soak (42–70 dB) |

As for 822: the authors had earlier studied Broadcom's wl driver privately, and the address of
the third chain's registers was first noticed there. Every part of 893 can nevertheless be
checked without that study, and no value in 893 comes from it: the method and the
arithmetic are b43's own N-PHY code, and the third chain's registers are a fact anyone can
measure on the hardware as described above. No Broadcom calibration code, data or loopback
method is used.

## Patches 897 and 898: several APs on the BCM4331

897 lets the BCM4331 (core rev 29, ucode 784) run up to four APs on one channel; 898 gives it the block of four
MAC addresses that needs. Both were offered to Rosen Penev's series (openwrt/openwrt#25922) as part of
neheb-35f92b8/.

| Part | Source |
|---|---|
| The base address the ucode compares the receiver address with: SHM 0x640–0x644 | Broadcom's `d11.h`, as shipped in router GPL source trees: `SHM_MBSS_BASE_ADDR (0x320 * 2)` with `SHM_MBSS_BSSID0`–`2` in its first three words (e.g. the DD-WRT tree, `src/linux/brcm/linux-2.6.23/brcm/include/d11.h`, and the Asus/FreshTomato tree, `release/src-rt-6.x.4708/include/d11.h`). b43-tools cites the same header for other SHM addresses. Only the address is used; nothing of the header is copied |
| The mask: the low bits of the last address byte that are set in SHM 0x64c are ignored | The 784.2 ucode that b43 loads (`ucode29_mimo.fw`, extracted with b43-fwcutter from `broadcom-wl-6.30.163.46`, the file the b43 documentation tells users to download), read with the b43 project's disassembler b43-dasm: ucode 0x083B–0x0842 compares the receiver address with SHM words 0x320–0x322 under the mask built from word 0x326. That is studying the ucode we run to learn how to talk to it |
| All BSSIDs in one aligned block of four (898) | Follows from the mask; the locally administered form of the factory address is our own choice |
| Beacons of the further APs from mac80211 at the primary's TBTT on the voice queue; their group keys in software; handing over the beacon template | Based on Ville Takio's multi-AP change for the AC-PHY cores, 12028df in aleferri/b43-ac-wip (GPL, his Signed-off-by) |
| Spare rows of the address match table do not work for further BSSIDs | Measured on our R6400 v2: no acknowledgements to the addresses in rows 3, 6 and 12 |
| The effect | Measured on the R6400 v1 and v2: 1 to 4 SSIDs beacon and carry traffic; soaks under load (see the patch texts) |

How we found it, honestly: the match-table route had failed, so the ucode had to match further BSSIDs some other
way. The symbol name `wlc_write_mbss_basemac` in Broadcom's prebuilt wl objects (the build DD-WRT ships for the
R6400, which one of us runs) pointed to the function; the disassembly of that one function showed which SHM
offsets it writes, and that led us to the compare in the ucode. No other part of wl was read for this, and no wl
code is copied. We found the d11.h names only afterwards; with them and the ucode, every fact in 897 and 898 can
be checked without wl. The commit text of 897 says the same.

## Sources per patch (rc8)

| Patch | Author | Based on (as named in its commit text) |
|---|---|---|
| 820 | Erik Conijn | b43 DMA code and the Linux DMA API; observed on the router |
| 821 | Erik Conijn | b43 DMA code; brcmsmac's handling of frames that span several RX buffers |
| 822 | Erik Conijn | see *Patch 822* below: Broadcom's ISC-licensed chip-control names, Linux bcma, hardware read-back |
| 823 | Erik Conijn | b43's N-PHY table code and brcmsmac's `wlc_phy_read_table` (32-bit read order); read-back |
| 824 | Erik Conijn | throughput measured per TX gain index on both routers; b43's TX gain table; since rc8 the board-flag check (BFL_FEM or BFL_HGPA) and its wording as in Rosen Penev's version of this patch in openwrt/openwrt#25922 |
| 825 | Erik Conijn | brcmsmac's MCS path (`brcms_c_d11hdrs_mac80211`, `mcs_table`); mac80211 |
| 826 | Erik Conijn | brcmsmac `brcms_c_ampdu_macaddr_upd()`; sniffer capture of the empty BlockAck TA |
| 827 | Erik Conijn | brcmsmac `ampdu.c`/`dma.c`; ath9k's block-ack window tracking; mac80211; the radio hang check reads the ucode's MAC statistics laid out as in brcmsmac's `struct macstat` (`d11.h`) |
| 828 | Erik Conijn | brcmsmac's SGI bits and `mcs_table`; IEEE 802.11 |
| 829 | Erik Conijn | brcmsmac `brcms_c_ampdu_finalize()`, `brcms_c_compute_rtscts_dur()` |
| 830 | Erik Conijn | mac80211 power-save API; ath9k's pattern |
| 831 | Erik Conijn | brcmsmac `brcms_c_compute_frame_dur()`; IEEE 802.11 duration rules; sniffer |
| 832 | Erik Conijn | driver counters and an independent sniffer (RX descriptor underruns) |
| 833 | Erik Conijn | sniffer time-aligned with the router's receive log |
| 834 | Erik Conijn | mac80211 TXQ API (`wake_tx_queue`, `ieee80211_next_txq`) |
| 835 | Erik Conijn | Rosen Penev's rate-control status patch (openwrt/openwrt#25922), credited |
| 836 | Erik Conijn | brcmsmac `mcs_table` (two-stream rates); measurements incl. temperature |
| 837 | Erik Conijn | brcmsmac `brcms_b_corerev_fifofixup()` (FIFO setup sequence); FIFO sizes found by experiment |
| 838 | Erik Conijn | mac80211 rate-control API; own design, measured with a sniffer |
| 839 | Rosen Penev | his patch from openwrt/openwrt#25922, unchanged |

All patches by Erik Conijn carry `Assisted-by: Claude:claude-opus-5-5`. They were written with the
help of an AI assistant (Anthropic's Claude), which also helped run the measurements and keep
this record.

## Patch 822: history and rework

### What happened

Patch 822 sets up the BCM4331's external front end on boards such as the Netgear R6400; without it
the receiver is nearly deaf. Its first version (2026-10-13, published in rc3–rc6) was a port of a
part of Broadcom's PHY initialisation. That part was taken from a decompilation of Broadcom's
prebuilt wl 7.14.164.18 driver object, and its commit text said so. No other patch was written
that way.

On 2026-10-19 the patch was rewritten for rc7. Every value in it is now backed by an open source or
by a measurement of the hardware. Values that could only be explained by the decompiled code were
dropped.

To be clear: the rework was done by the same people who had read the decompiled code. Every
value of the rc7 version can nevertheless be checked without that code, using the sources
below.

### Every value of the rc7 version

| Part | rc7 value | Source |
|---|---|---|
| ChipCommon chip control: clear the digital external PA lines `EXTPA_EN` (bit 4) and `EXTPA_EN2` (bit 12) | bits cleared | Names: Linux `include/linux/bcma/bcma_driver_chipcommon.h`. Linux bcma sets both at boot for every BCM4331 (`bcma_pmu_workarounds()`), which is the deaf state. Broadcom's ISC-licensed `siutils.c` (`si_chipcontrl_epa4331`) clears the same bits to switch them off. |
| Chip control: set analog PA control `EXTPA_ANA_EN` (bit 24) | set | Name and meaning: Broadcom's ISC-licensed `sbchipc.h` (`CCTRL4331_EXTPA_ANA_EN`). Not named in Linux. |
| Chip control: external LNA on, `EXT_LNA` (bit 2), if the board has one | set if `BFL_EXTLNA` | Linux bcma (`BCMA_CHIPCTL_4331_EXT_LNA`) and ssb (`SSB_BFL_EXTLNA`) |
| Resulting chip control on the R6400 v1 and v2 | 0x00001010 at power-on → **0x01000004** | Read back under Broadcom's driver: **0x01000004** under Netgear's firmware (wl 6.37.15.24) and under DD-WRT (wl 7.14.164.18), stable across channel changes, interface restarts and a cold boot |
| PHY table 7 (RF sequencer) entry 0x90 | 0x08 → **0x46** | Read back under Broadcom's driver: 0x46. All other entries 0x10–0x1f and 0x90–0x9f already match with stock b43, except 0x98 (0x01 vs 0x74), which made no measurable difference in an A/B test and is not written |
| PHY register 0x259 | 0x2024 → **0x2444** | Read back under Broadcom's driver: 0x2444 at 802.11g, HT20 and HT40 |
| Condition | BCM4331, 2.4 GHz, board flag `BFL2_ANAPACTRL_2G`, chip package not 9 or 11 | Flag name and meaning ("2G ext PAs are controlled by analog PA ctrl lines"): Broadcom's ISC-licensed `bcmdevs.h`. Package split: Linux bcma (`bcma_chipco_bcm4331_ext_pa_lines_ctl()`), which wires the PA lines to GPIO 2/5 on packages 9 and 11 |

Dropped from the rc3–rc6 version:
* the PA reference LDO write: it wrote 0 to a field that reads 0 at power-on and under
  Broadcom's driver, so it changed nothing;
* the other RF sequencer writes: stock b43 already sets those entries to the same values;
* three conditions that only the decompiled code supported (a device ID, a board-flag bit and
  an `extpagain2g` value).

### Checks

* **Hardware state.** On both routers, from a cold start, the rc7 version leaves exactly the state
  the rc3–rc6 version left (chip control, table 7, PHY 0x259, regulator), and the state Broadcom's
  drivers set.
* **Behaviour.** A 100-minute soak test (access point and client, both on rc7's 822) gave the same
  throughput as rc5/rc6 (89.5 / 92.2 Mbit/s), with no stalls, hangs or receive errors.
* **Commit text.** The new 822 cites only the sources in the table above.

## Change log of this page

* 2026-10-19: first version, with rc7.
* 2026-10-22: rc8 (824 board-flag check, 827 hang check counters).
* 2026-10-26: rc9 (patches 862–867 and the wifi-scripts patch on top of openwrt/openwrt#25922;
  patch 866); the 822 account reworded, same facts.
* 2026-10-30: rc10 (866 reworked, 868 added).
* 2026-11-03: rc11 (rebased on openwrt/openwrt#25922 at fe90f890dc; renumbered 890–895; 864
  dropped; 893 runs after his new TX calibration).
* 2026-11-04: rc12 (rc11 + kernel patch 880 by Alessio Ferri).
* 2026-11-05: rc13 (newer 880, hostapd with 802.11ac).
* 2026-11-10: patches 897 and 898 (several APs on the BCM4331, neheb-35f92b8/); summary bullet on decompiled
  code extended for them.
