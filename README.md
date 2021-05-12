![minerstat logo](https://cdn.rawgit.com/minerstat/minerstat-asic/master/docs/logo_full.svg)

# minerstat OS

**minerstat OS** is the most advanced ***open source*** crypto [mining OS](https://minerstat.com/software/mining-os) available. It will automatically configure and optimize itself to mine with your ***AMD or NVIDIA*** cards. ***You only need to download, flash it, set your token in the config file and boot it!***

This software **only works with [my.minerstat.com](https://my.minerstat.com) interface**

## Commands

```
miner         | Show mining client screen

agent         | Show minerstat agent + miner screen

mstart        | (Re)start mining

mstop         | Stop mining

mrecovery     | Restore system to default

mupdate       | Update system (clients, fixes, ...)

mreconf       | Simulate first boot: configure DHCP, creating fake dummy

mclock        | Fetch OC from the dashboard

mreboot       | Reboot the rig

mshutdown     | Shut down the rig

forcereboot   | Force Reboot (<0.1 sec)

forceshutdown | Power off (<0.1 sec)

mfind         | Find GPU (e.g. mfind 0 - will set fans to 0% except GPU0 for 5 seconds)

minfo         | Show welcome screen and msOS version

mlang         | Set keyboard layout (e.g. mlang de)

mswap         | Tool for swap file creation

mworker       | Change ACCESSKEY & WORKERNAME

mwifi         | Connect to Wireless networks easily

mled          | Toggle Nvidia LED Lights ON/OFF

atiflash      | AMD - Bios (.rom) Flasher

atiflashall   | AMD - Flash .rom to all available GPUs on the system

atidumpall    | AMD - Dump all bios from all available GPUs on the system.

mhelp         | List all available commands

```

## Information

You can see mining process by type `miner` to the terminal.

**Ctrl + A** | **Crtl + D** to safety close your running miner.

**Ctrl + C** command quit from the process / close minerstat.

## Private, Custom Miner Support

Example API [file](https://github.com/minerstat/minerstat-os/blob/master/api).

##

***© minerstat OÜ*** in 2018


***Contact:*** app [ @ ] minerstat.com


***Mail:*** Sepapaja tn 6, Lasnamäe district, Tallinn city, Harju county, 15551, Estonia

##
