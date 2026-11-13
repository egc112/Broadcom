# Provenance and legal notes: Northstar FA research

This page records where every piece of knowledge and code in the Northstar FA work comes from, so that anyone
(OpenWrt or Linux maintainers, other driver developers) can check it before taking any of it. The goal is a
driver that can go upstream into OpenWrt and Linux, so every fact must have a source that is open and
verifiable.

It is a factual record, not legal advice. Questions or corrections: please open an issue.

## Summary

* Nothing has been published as code yet. The prototype (a loadable kernel module and two small kernel
  changes) exists only on our test router, as a test bed. The [README](README.md) describes what it does and what
  we measured.
* Everything is based on:
  * **open source code**: Broadcom's `et` Ethernet driver as Broadcom published it under the ISC license, and
    the Linux kernel (GPL-2.0);
  * **our own measurements** on our own routers.
* **No decompiled or disassembled code was used** for the FA work, no binary driver was analysed, and no
  firmware was extracted. The FA is driven by Broadcom's Ethernet driver, whose source code is public; Broadcom's
  closed Wi-Fi driver (`wl`) has nothing to do with it.
* Only **public** copies of the Broadcom source were used, each identified by repository and commit (see
  *Sources*).
* Broadcom's ISC-licensed code may be combined with GPL-2.0 code (as in the kernel's own `brcmsmac` and
  `brcmfmac` drivers), **provided Broadcom's copyright notice and the ISC permission notice are kept**. Any
  published driver code that is ported from it will carry that notice (see *For an upstream driver*).

## Licenses of the sources

| Source | License | Used for |
|---|---|---|
| Broadcom `et` driver: `et/sys/etc_fa.c`, `et/include/fa_core.h` | ISC (Broadcom copyright + permission notice) | FA register map, the three table formats (flow entry, next hop, pool), the software hash (a CRC-CCITT variant), the table access sequence, the FA-capable rule (`FA_CAPABLE()`), the init sequence |
| Broadcom `shared/bcmrobo.c` | ISC | the switch (CFP) rule that copies TCP FIN/RST to the spare port 5 (`robo_fa_aux_init()`) |
| Broadcom `include/ctf/hndctf.h` | ISC | names of the connection-tuple fields and NAT actions |
| Linux b53 switch driver, DSA, `tag_brcm` | GPL-2.0 | the code base the kernel changes modify; switch register access, FDB entries |
| Linux nftables flowtable (`nf_flow_table`) | GPL-2.0 | the offload interface the prototype implements (`TC_SETUP_FT`) |
| Linux `mtk_ppe_offload.c` (MediaTek PPE) | GPL-2.0 | pattern for parsing a flowtable rule into a hardware entry; no code copied |
| Linux `bcm_sf2_cfp.c`, `bcm_sf2_regs.h`, `b53_regs.h` | GPL-2.0 | switch CFP field and action names (TTL range, redirect), the port-5 Broadcom tag enable bit |
| Linux `nf_tables_api.c`, `nf_flow_table_core.c`, `net/core/dev.c` | GPL-2.0 | read to understand the order of flowtable unbind and teardown, and the VLAN untagging after a re-injected frame; no code copied |

## How the information was obtained

1. **Reading the public Broadcom source.** The `et` driver contains the complete FA support code: registers,
   table layouts, initialisation and the NAT entry format. It is part of the GPL source releases of router
   firmware and is mirrored publicly (see *Sources*).
2. **Reading the hardware state back** (black box). With Broadcom's own driver running (DD-WRT on the same
   routers), a small module of our own read the FA registers and tables. This showed *what values the hardware
   holds* (for example the TTL setting, `l3_napt_ctl = 0x00200000`); it involves no Broadcom code.
3. **Experiments on our own routers under OpenWrt**: writing entries and watching the FA's hit counters, its
   own flow ids on packets it sends to the CPU (which confirmed the hash), and the switch's port counters.
4. **Throughput and soak tests** (iperf3, many-connection and flow-churn tests), with a wired test PC.

Some results go **beyond** what Broadcom's code does, and come from experiments only:

* **Routing without NAT** (NAT action 0): Broadcom's driver only ever writes NAT entries. That an entry with no
  address rewrite works, and that the TTL is still lowered, was measured on the EA6900 (packets counted with
  TTL 63 at the receiver).
* **VLAN on the WAN port**: the tag operation per next hop (add an 802.1Q tag or none) is Broadcom's
  (`fa_napt_add()`). That the switch drops the FA's tagged output unless the VLAN table lists the ports as
  members, and that Linux's b53 driver leaves that entry empty for a VLAN on a standalone port, was found by
  experiment (switch discard counters, VLAN table read-back) and by reading the b53 source (`b53_vlan_add()`).
* **IPv6**: Broadcom's driver never adds IPv6 entries; its dump code only shows that they use two
  table slots and which word holds the valid bit (`_fa_napt_del()`). The rest was found by experiment on the
  EA6900: the hash (Broadcom's IPv4 CRC-CCITT input with 128-bit addresses, matched against the FA's own flow ids
  for 68 of 68 flows), the field layout of both slots (candidate entries written until the FA's hit counter moved,
  then each field confirmed by flipping single bits: every flip stopped the hits), the rule that a pair starts at
  slot 0 or 2 of a hash row, and that the FA routes IPv6 with the hop limit lowered (packets counted at a
  receiver). The module's IPv6 code (placing the slot pairs, the order of writing and clearing them) is new;
  it was checked by computing the hash and the slot contents on a PC and comparing them word by word with the
  entries that the FA had accepted, and then by the hit counter of every entry in a full table.
* **TTL / hop limit 1**: that the FA drops IPv4 TTL 1 silently and forwards IPv6 hop limit 1 as 0 was measured
  (packets counted at the receiver and on the router). The fix uses the switch's CFP "TTL range" field, which the
  Linux `bcm_sf2_cfp.c` driver and Broadcom's `bcmrobo.c` name but do not explain; its four values (TTL 0, 1,
  2–254, 255) were measured with copy rules and counters. The redirect action value and the port-5 Broadcom tag
  come from the Linux kernel (`bcm_sf2_regs.h`, `b53_regs.h`, `tag_brcm`); the tag's port field was checked on
  captured frames.
* **Firewall reload**: that Linux disconnects a flowtable from its driver before it removes the flowtable's
  connections was measured (the entries kept their hit counters rising) and then read in the kernel source
  (`nf_tables_api.c`: the flowtable is unregistered at commit, `nf_flow_table_free()` runs later). The fix is new
  code.
* **VLAN-tagged packets on port 5**: that the switch's TTL rule also catches tagged frames was measured; handing
  the frame to Linux with its tag kept relies on the kernel's receive loop untagging it again (`net/core/dev.c`,
  read in the source).
* **Hooking the FA into Linux's flowtable offload**, the DSA tag handling and the switch FDB handling are new
  code for Linux; Broadcom's driver works differently (its own CTF layer).

## For an upstream driver

What a published driver must do, so the provenance stays clean:

* **Keep Broadcom's notice** in every file that contains code ported from `etc_fa.c` / `fa_core.h` /
  `bcmrobo.c`: the copyright line and the ISC permission text, as `brcmsmac` does in the kernel. The private
  prototype does not carry it yet (it is not published); the first published version will.
* **Write new code where Linux has its own way**: the flowtable glue, DSA tagging and switch handling are written
  for Linux, not ported. Where the kernel already has an equivalent (for example its CRC-CCITT library), use it if
  it gives the same result as Broadcom's function.
* **Name the source of every fact** in the commit messages: the Broadcom file and function, or the experiment
  and its result.
* **No vendor binaries, firmware or private source trees**, now or later.

## Sources

* Broadcom `et` driver, `shared/bcmrobo.c`, `include/ctf/hndctf.h`, public copies used:
  * [FreshTomato-Project/freshtomato-arm](https://github.com/FreshTomato-Project/freshtomato-arm) at commit
    `08bcf264b81d2197cc966b642345edb96009851e`, `release/src-rt-7.14.114.x/src/` (`et/sys/etc_fa.c`,
    `et/include/fa_core.h`, `shared/bcmrobo.c`);
  * [mirror/dd-wrt](https://github.com/mirror/dd-wrt) at commit `fd537862c37524ab57a074c01d2d641235d95089`,
    `src/linux/universal/linux-4.14/brcm/arm/` (same files; `bcmrobo.c` from `linux-4.4/brcm/arm/shared`).

  Each file carries "Copyright (C) 2015, Broadcom Corporation" (2017 for the dd-wrt `bcmrobo.c`) and the ISC
  permission notice ("Permission to use, copy, modify, and/or distribute this software for any purpose with or
  without fee is hereby granted, provided that the above copyright notice and this permission notice appear in
  all copies").
* Linux kernel and OpenWrt source trees (b53, DSA, `tag_brcm`, `nf_flow_table`, `mtk_ppe_offload.c`).
* Our routers: Linksys EA6900 v1 (all FA experiments), Netgear R6400 v1 and v2 (FA-capable check).

## Who did what

The research, the prototype and this record are by Erik Conijn, written with the help of an AI assistant
(Anthropic's Claude), which also helped run the measurements and keep this record. Patches will carry
`Assisted-by: Claude:claude-opus-5-5`. All results were measured on the hardware.
