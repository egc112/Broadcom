# Broadcom BCM4708/BCM4709 (bcm53xx) — patches and files

Patches and files for Broadcom BCM53xx ARM routers running OpenWrt, e.g. the Netgear R6400 and the Linksys EA6900.

| Folder | What |
|---|---|
| [b43-80211n](b43-80211n/) | **b43: 802.11n with A-MPDU for the BCM4331 2.4 GHz radio** (Netgear R6400 v1/v2): test version rc10, patches on top of Rosen Penev's openwrt/openwrt#25922 + build instructions (the older stand-alone rc8 is kept there too); [provenance and legal notes](b43-80211n/PROVENANCE.md). Test images: see [Releases](../../releases). |
| [linksys-ea6900](linksys-ea6900/) | **OpenWrt for the Linksys EA6900 v1** (with the Asus-style XVortex CFE): install from DD-WRT, recovery, patches for an own build. Test version, no wireless yet. |

Questions and test reports: please open an issue.
