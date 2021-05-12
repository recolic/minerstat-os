#!/bin/bash

if [[ "$1" != "nosync" ]]; then
  sudo echo 1 > /proc/sys/kernel/sysrq #enable
  sudo echo s > /proc/sysrq-trigger #(*S*nc) Sync all cached disk operations to disk
fi

echo ""
echo "Sending reboot signal"
echo -e "  [i] If the computer not rebooting after this command watchdog not supported or not properly installed into the motherboard reset slot \r"
echo -e "  [i] Hint: Make sure no keyboard / mouse attached to the motherboard. Those can fail the watchdog script. \r"
echo ""

# recheck
check=""
# ANPIX USB WatchDog Card
P1=$(lsusb | grep "5131:2007")
if [ ! -z "$P1" ]; then
  check="5131:2007"
fi
# domybest USB Watchdog Card
P2=$(lsusb | grep "1a86:7523")
if [ ! -z "$P2" ]; then
  check="1a86:7523"
fi
# ALLOYSEED USB Watchdog
P3=$(lsusb | grep "0471:2379")
if [ ! -z "$P3" ]; then
  check="0471:2379"
fi
# QinHeng Electronics HL-340 USB-Serial adapter
P6=$(lsusb | grep "1a86:7523")
if [ ! -z "$P5" ]; then
  check="1a86:7523"
fi

# Try to find devpath
if [ ! -z "$check" ]; then
  sysbuspath=$(find /sys/bus/usb/devices/usb*/ -name dev | grep $check)
  pathedit=${sysbuspath%/dev}
  devname=$(udevadm info -q name -p $pathedit 2>/dev/null)
fi

# attempt to reboot rig with watchdog
if [ ! -z "$P1" ] || [ ! -z "$P2" ] || [ ! -z "$P3" ]; then
  if [ -z "$devname" ]; then
    sudo su -c "printf '\xFF\x55' >/dev/ttyUSB*"
    sudo su -c "printf '\xFF\x55' >/dev/hidraw*"
  else
    sudo su -c "printf '\xFF\x55' >/dev/$devname"
  fi
fi

if [ ! -z "$P6" ]; then
  # edit later
  # cat -v < /dev/ttyUSB0
  sudo su -c "printf '\xFF\x55' >/dev/ttyUSB0"
  sudo su -c "printf '\xFF' >/dev/ttyUSB0"
fi

sudo su -c "echo -n '~T1' >/dev/ttyACM*"

# Is octo or minerdude board ?
if [[ -f "/dev/shm/octo.pid" ]]; then
  timeout 5 sudo /home/minerstat/minerstat-os/bin/fan_controller_cli -w 0 -v 0
  sudo /home/minerstat/minerstat-os/core/octoctrl --reboot
fi
# watchdog in ua
P5=$(lsusb | grep "16c0:03e8")
if [ ! -z "$P5" ]; then
  timeout 3 sudo /home/minerstat/minerstat-os/bin/watchdoginua $TIMEOUT testreset
fi

# echo lsusb
echo "Listing detected USB devices"
echo -e "  [i] Check below your USB recognised or not \r"

sudo lsusb
