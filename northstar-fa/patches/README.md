# Northstar FA driver patches for OpenWrt (work in progress)

Kernel patches for OpenWrt's `bcm53xx` target (`target/linux/bcm53xx/patches-6.18`, Linux 6.18) that drive the
flow accelerator (FA) of the BCM4708/BCM4709 from the Ethernet driver (bgmac), with the switch rules in the switch
driver (b53). Put them in that directory and build; the board's device tree turns the FA on (328, 329 do this for
the Linksys EA6900). State, measurements and provenance: see the [README](../README.md) and
[PROVENANCE](../PROVENANCE.md).

They need OpenWrt main as of 2026-11-14 or later: they build on patches 701 (Rafał Miłecki) and 702/703 (Rosen
Penev, openwrt/openwrt#26005: a second CPU port for b53), which are already in OpenWrt.

| Patch | What it does | Tested |
|---|---|---|
| 328 | EA6900 device tree: use the FA tag on port 8 | yes |
| 329 | EA6900 device tree: port 5 (eth0) for the switch's trap rules | yes |
| 721 | tag_brcm: accept the FA's lookup opcode | yes |
| 722 | b53: allow the prepended tag on Northstar port 8 | yes |
| 723 | bgmac: set up the FA, following the tagger | yes |
| 724 | bgmac: offload IPv4 flows (routing, NAT) through the nftables flowtable | yes |
| 725 | tag_brcm: leave frames from another CPU port to the bridge | yes |
| 726 | b53: trap TTL 0/1 in front of the FA | yes |
| 727 | b53: trap TCP FIN and RST in front of the FA | yes |
| 728 | b53: the same traps for IPv6, and `b53_fa_trap_active()` | yes |
| 729 | bgmac: offload IPv6 flows | yes |
| 730 | b53: keep VLAN members for the FA (`b53_fa_vlan()`) | yes |
| 731 | bgmac: offload flows over 802.1Q uppers (VLAN WAN) | yes |

Not yet submitted anywhere. Each commit message names its sources and the measurements behind it.
