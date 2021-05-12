#!/bin/bash

SYSLOAD=$(sudo cat /proc/loadavg | awk '{print $1}' | cut -f1 -d".")
sudo echo 1 > /proc/sys/kernel/sysrq #enable sysrq

# kill watchdog pings
sudo killall watchdog >/dev/null 2>&1

# sync, unmount, reboot
RAMLOG=""
RAMLOG=$(timeout 5 cat /dev/shm/miner.log | tac | head --lines 10 | tac)

# ro check
if [[ "$1" = "ro" ]]; then
  RAMLOG="$RAMLOG Device failure, read only filesystem. Rebooting.."
fi

if [[ "$1" = "fault" ]]; then
  RAMLOG="$RAMLOG amdgpu_vm_free_table fixing recursive fault but reboot is needed. Rebooting.."
fi

sudo echo s > /proc/sysrq-trigger #(*S*nc) Sync all cached disk operations to disk
sudo echo u > /proc/sysrq-trigger #(*U*mount) Umounts all mounted partitions

# attempt

TOKEN="$(cat /media/storage/config.js | grep 'global.accesskey' | sed 's/global.accesskey =//g' | sed 's/;//g' | sed 's/ //g' | sed 's/"//g' | sed 's/\\r//g' | sed 's/[^a-zA-Z0-9]*//g')"
WORKER="$(cat /media/storage/config.js | grep 'global.worker' | sed 's/global.worker =//g' | sed 's/;//g' | sed 's/ //g' | sed 's/"//g' | sed 's/\\r//g')"

function reboots () {
  RAMLOG="$RAMLOG - System reboot"
  timeout 4 sudo curl --insecure --connect-timeout 2 --max-time 3 --retry 0 --header "Content-type: application/x-www-form-urlencoded" --request POST --data "htoken=$TOKEN" --data "hworker=$WORKER" --data "mineLog=$RAMLOG" "https://api.minerstat.com:2053/v2/set_node_config_os2.php"
  # attempt to reboot rig with watchdog
  sudo /home/minerstat/minerstat-os/bin/watchdog-reboot.sh nosync
  # if upper failes reboot normally
  sudo echo b > /proc/sysrq-trigger # (re*B*oot) Reboots the system
}

function sdown () {
  if [[ "$1" != "powercycle" ]]; then
    RAMLOG="$RAMLOG - System shutdown"
  fi
  timeout 4 sudo curl --insecure --connect-timeout 2 --max-time 3 --retry 0 --header "Content-type: application/x-www-form-urlencoded" --request POST --data "htoken=$TOKEN" --data "hworker=$WORKER" --data "mineLog=$RAMLOG" "https://api.minerstat.com:2053/v2/set_node_config_os2.php"
  if [[ -f "/dev/shm/octo.pid" ]]; then
    timeout 5 sudo /home/minerstat/minerstat-os/bin/fan_controller_cli -w 0 -v 0
    sudo /home/minerstat/minerstat-os/core/octoctrl --shutdown
  fi
  P5=$(lsusb | grep "16c0:03e8")
  if [ ! -z "$P5" ]; then
    timeout 3 sudo /home/minerstat/minerstat-os/bin/watchdoginua $TIMEOUT testpower
  fi
  if [[ "$SYSLOAD" -gt 0 ]]; then
    # Shutdown forced
    sudo echo o > /proc/sysrq-trigger # (shutd*O*wn) Shutdown the system
    sleep 2
    sudo poweroff # just safety failover
  else
    # Shutdown
    sudo poweroff
  fi
}

if [[ "$1" = "shutdown" ]]; then
  sdown
  exit 1
fi

if [[ "$1" = "safeshutdown" ]]; then
  sudo poweroff
  exit 1
fi

if [[ "$1" = "powercycle" ]]; then
  RAMLOG="$RAMLOG - System power cycle"
  timeout 4 sudo curl --insecure --connect-timeout 2 --max-time 3 --retry 0 --header "Content-type: application/x-www-form-urlencoded" --request POST --data "htoken=$TOKEN" --data "hworker=$WORKER" --data "mineLog=$RAMLOG" "https://api.minerstat.com:2053/v2/set_node_config_os2.php"
  # Check it is supported, if not use normal reboot
  if [ -f "/sys/class/rtc/rtc0/wakealarm" ]; then
    sudo su -c "echo 0 > /sys/class/rtc/rtc0/wakealarm"
    sudo su -c "echo +30 > /sys/class/rtc/rtc0/wakealarm"
    sdown
  else
    # Reboot because wakealarm not supported
    reboots
  fi
  # If not $1 powercycle then probably just normal reboot so processing trough the script
  exit 1
fi

reboots
