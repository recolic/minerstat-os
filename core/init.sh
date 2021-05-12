#!/bin/bash

OFFLINE_COUNT=0
OFFLINE_NUM=36
IS_ONLINE="YES"
DETECT="$(df -h | grep "20M" | grep "/dev/" | cut -f1 -d"2" | sed 's/dev//g' | sed 's/\///g' | sed 's/[0-9]*//g' | head -n1 | xargs)"
PART=$DETECT"1"

if [ "$DETECT" = "nvmenp" ]; then
  echo "Changeing header, NVM drive detected.."
  DETECT="$(df -h | grep "20M" | grep "/dev/" | cut -f1 -d"2" | sed 's/dev//g' | sed 's/\///g' | xargs | sed 's/.$//' | sed 's/\s.*$//' | xargs | sed 's/\p//g')"
  PART=$DETECT"p1"
fi

DISK="$(df -hm | grep $PART | awk '{print $2}')"

MONITOR_TYPE="unknown"
STRAPFILENAME="amdmemorytweak-stable"
DETECTA=$(lsmod | grep nvidia | wc -l)
DETECTB=$(lsmod | grep amdgpu | wc -l)


if grep -q experimental "/etc/lsb-release"; then
  STRAPFILENAME="amdmemorytweak"
fi

if [ "$DETECTA" -gt "0" ]; then
  echo "Hardware Monitor: Nvidia GPU found"
  MONITOR_TYPE="nvidia"
fi

echo "Checking for AMD APU"
IS_APU=$(timeout 40 sudo lspci -k | grep VGA | grep -cE "Kaveri|Beavercreek|Sumo|Wrestler|Kabini|Mullins|Temash|Trinity|Richland|Stoney|Carrizo|Raven|Renoir|Picasso|Van")
echo "AMD APU Num: $IS_APU"

if [ "$DETECTB" -gt "0" ]; then
  echo "Hardware Monitor: AMD GPU found"
  NUM_AMD=$(timeout 40 sudo lshw -C display | grep AMD | wc -l)
  if [ -z "$NUM_AMD" ]; then
    NUM_AMD=$(timeout 40 sudo lshw -C display | grep amdgpu | wc -l)
  fi
  echo "Number of AMD: $NUM_AMD"
  if [[ "$IS_APU" = "1" ]] && [[ "$NUM_AMD" = "1" ]]; then
    echo "AMD skipped seems only Internal GPU available"
  else
    echo "No APU found or higher than 1 number for AMD graphics"
    MONITOR_TYPE="amd"
  fi
fi

if [ "$MONITOR_TYPE" = "unknown" ]; then
  TEST_NVIDIA=$(nvidia-smi -L)
  NUM_AMD=$(timeout 40 sudo lshw -C display | grep AMD | wc -l)
  if [ -z "$NUM_AMD" ]; then
    NUM_AMD=$(timeout 40 sudo lshw -C display | grep amdgpu | wc -l)
  fi
  TEST_AMD=$NUM_AMD
  if [[ $TEST_NVIDIA == *"GPU 0"* ]]; then
    NVIDIA_FAN_NUM=$(sudo nvidia-settings -c :0 -q fans | grep "fan:" | wc -l)
  fi
  # recheck
  if [[ $NUM_AMD -gt 0 ]]; then
    echo "Hardware Monitor: AMD GPU found"
    MONITOR_TYPE="amd"
  fi

  if [[ $TEST_NVIDIA == *"GPU 0"* ]]; then
    echo "Hardware Monitor: Nvidia GPU found"
    MONITOR_TYPE="nvidia"
  fi
fi

echo "Final hardware to monitor: $MONITOR_TYPE"

# UEFI / LEGACY
[ -d /sys/firmware/efi ] && BOOTED="UEFI" || BOOTED="LEGACY"

# Extended Query without loop
# Internet
NET_DRIVER=""
NET_IFACE=$(timeout 2 route | grep '^default' | grep -o '[^ ]*$' | xargs)
if [[ ! -z "$NET_IFACE" ]]; then
  NET_DRIVER=$(timeout 2 sudo ethtool -i $NET_IFACE | grep driver | grep -oP "^driver:\K.*" | xargs)
fi

MOBO_TYPE=$(sudo timeout 5 dmidecode --string baseboard-product-name)
MOBO_TYPE="$MOBO_TYPE [$NET_DRIVER]"
if [ "$MOBO_TYPE" = "Default string" ]; then
  MOBO_TYPE="Unbranded [$NET_DRIVER]"
fi
BIOS_VERSION=$(sudo timeout 5 dmidecode --string bios-version)
MSOS_VERSION=$(cat /etc/lsb-release | grep DISTRIB_RELEASE= | head -n1 | sed 's/DISTRIB_RELEASE=//g')
MAC_ADDRESS=$(cat /sys/class/net/$(ip route show default | awk '/default/ {print $5}')/address)
if [ -z "$MAC_ADDRESS" ]; then
  MAC_ADDRESS=$(timeout 5 ifconfig -a | grep : | grep -vE "eth0|lo|wlan0" | grep ether | awk '{print $2}')
fi
CPU_TYPE=$(sudo timeout 15 dmidecode --string processor-version)

# For Ryzen CPUS
# lm-sensor need to be installed
if [[ "$CPU_TYPE" == *"Ryzen"* ]]; then
  SENTEST=$(timeout 3 which sensors)
  if [[ -z "$SENTEST" ]]; then
    sudo apt-get install -y lm-sensors >/dev/null 2>&1 &
    timeout 5 sudo modprobe k10temp force=1
  fi
fi

DISK_TYPE=$(timeout 5 lsblk -io KNAME,MODEL,SIZE | grep $DETECT | head -n1 | xargs | awk '{print $2,$3}')
# System & Graphics
NVIDIA_DRIVER=$(nvidia-settings --help | grep version | head -n 1 | awk '{print $3}' | xargs | xargs)
if [ -z "$NVIDIA_DRIVER" ]; then
  NVIDIA_DRIVER=$(timeout 5 nvidia-smi | grep "Driver Version" | xargs | sed 's/[^0-9. ]*//g' | xargs | cut -d ' ' -f 1 | xargs)
fi
if [ -z "$NVIDIA_DRIVER" ]; then
  NVIDIA_DRIVER=$(timeout 5 dpkg -l | grep nvidia-driver | grep ii | awk '{print $3}' | xargs | cut -d '-' -f 1)
fi
AMD_DRIVER=$(timeout 5 dpkg -l | grep opencl-amdgpu-pro-icd | head -n1 | awk '{print $3}' | xargs)
if [ -z "$AMD_DRIVER" ]; then
  AMD_DRIVER=$(timeout 5 dpkg -l | grep amdgpu-pro-rocr-opencl | head -n1 | awk '{print $3}' | xargs | cut -f1 -d"-")
fi
if [ -z "$AMD_DRIVER" ]; then
  AMD_DRIVER=$(timeout 5 dpkg -l | grep vulkan-amdgpu-pro | head -n1 | awk '{print $3}' | xargs)
fi
KERNEL_VERSION=$(timeout 5 uname -r)
UBUNTU_VERSION=$(timeout 5 cat /etc/os-release | grep "PRETTY_NAME" | sed 's/PRETTY_NAME="//g' | sed 's/"//g' | xargs)

# DETECT USB Drive version
USBD=""
USBCAP=""
DRIVE_VERSION=$(timeout 10 sudo lshw -c storage -c disk | grep -B 35 $DETECT | grep "driver=" | awk '{ print $2 }' | sed 's/......=//' | head -n 1)
DRIVE_CAP=$(timeout 10 sudo lshw -c storage -c disk | grep -B 35 $DETECT | grep "capabilities:" | head -n 1 | xargs)

if [[ -z "$DRIVE_VERSION" ]]; then
  DRIVE_VERSION=""
fi

if [[ -z "$DRIVE_CAP" ]]; then
  DRIVE_CAP=""
fi

# Check the USB/Drive Max Cap
if [[ $DRIVE_CAP == *"usb-2"* ]]; then
  USBCAP=" [USB 2.0]"
elif [[ $DRIVE_CAP == *"usb-3"* ]]; then
  USBCAP=" [USB 3.0]"
elif [[ $DRIVE_CAP == *"usb-1"* ]]; then
  USBCAP=" [USB 1.0]"
elif [[ $DRIVE_CAP == *"ahci"* ]]; then
  USBCAP=" [SATA]"
elif [[ $DRIVE_CAP == *"pata_via"* ]]; then
  USBCAP=" [PATA]"
elif [[ $DRIVE_CAP == *"ohci"* ]]; then
  USBCAP=" [USB 1.0]"
elif [[ $DRIVE_CAP == *"ehci"* ]]; then
  USBCAP=" [USB 2.0]"
elif [[ $DRIVE_CAP == *"xhci"* ]]; then
  USBCAP=" [USB 3.0]"
fi

# Check USB/Drive Port TYPE
if [[ "$DRIVE_VERSION" = "uas" ]]; then
  USBD=" [USB 3.0]"
elif [[ "$DRIVE_VERSION" = "ehci" ]]; then
  USBD=" [USB 2.0]"
elif [[ "$DRIVE_VERSION" = "ohci" ]]; then
  USBD=" [USB 1.0]"
elif [[ "$DRIVE_VERSION" = "xhci" ]]; then
  USBD=" [USB 3.0]"
elif [[ "$DRIVE_VERSION" = "uhci" ]]; then
  USBD=" [USB 1.0]"
elif [[ "$DRIVE_VERSION" = "ahci" ]]; then
  USBD=" [SATA]"
elif [[ "$DRIVE_VERSION" = "480Mbit" ]]; then
  USBD=" [USB 2.0]"
elif [[ "$DRIVE_VERSION" = "usb-storage" ]]; then
  USBD=" [USB 3.0]"
fi

# If empty
if [[ -z "$USBD" ]] && [[ ! -z "$DRIVE_VERSION" ]]; then
  USBD=" $DRIVE_VERSION"
else
  # Check both port n cap
  if [[ ! -z "$USBCAP" ]] && [[ ! -z "$DRIVE_CAP" ]]; then
    if [[ "$USBCAP" != "$USBD" ]]; then
      USBD="$USBCAP ->$USBD"
    fi
  fi
fi
DISK_TYPE="$DISK_TYPE$USBD"

while true
do

  echo "-*- BACKGROUND SERVICE -*-"

  # reboot if read-only
  if findmnt -n -o OPTIONS /dev/"$PART" | egrep "^ro,|,ro,|,ro$"; then
    sudo bash /home/minerstat/minerstat-os/bin/reboot.sh ro
  fi

  RESPONSE="null"

  #HOSTNAME
  TOKEN="$(cat /media/storage/config.js | grep 'global.accesskey' | sed 's/global.accesskey =//g' | sed 's/;//g' | sed 's/ //g' | sed 's/"//g' | sed 's/\\r//g' | sed 's/[^a-zA-Z0-9]*//g')"
  WORKER="$(cat /media/storage/config.js | grep 'global.worker' | sed 's/global.worker =//g' | sed 's/;//g' | sed 's/ //g' | sed 's/"//g' | sed 's/\\r//g')"

  echo ""
  echo "$TOKEN"
  echo "$WORKER"

  #FREE SPACE in Megabyte - SDA1
  STR1="$(timeout 5 df -hm | grep $DISK | awk '{print $4}')"
  if [ -z "$STR1" ]; then
    STR1="$(timeout 5 df -hm | grep sdb1 | awk '{print $4}')"
  fi

  echo "Free Space: $STR1"

  #CPU USAGE
  #STR2="$(mpstat | awk '$13 ~ /[0-9.]+/ { print 100 - $13 }')"
  STR2=$(timeout 5 grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage ""}')

  echo "CPU Usage: $STR2"

  #REMOTE IP ADDRESS
  #STR4="$(wget -qO- http://ipecho.net/plain ; echo)"

  #LOCAL IP ADDRESS
  STR3="$(timeout 5 ifconfig | grep "inet" | grep -v "inet6" | grep -vE "127.0.0.1|169.254|172.17." | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | head -n 1 | grep -o -E '[.0-9]+')"
  echo "Local IP: $STR3"

  #FREE MEMORY
  STR5="$(timeout 5 free -m | grep 'Mem' | awk '{print $7}')"
  echo "Free Memory: $STR5"

  # TELEPROXY ID
  TELEID=$(timeout 5 sudo /home/minerstat/minerstat-os/bin/tmate -S /tmp/tmate.sock display -p '#{tmate_ssh}' | cut -f1 -d"@" | sed 's/.* //')
  echo "TeleID: $TELEID"

  # SYSTEM UPTIME
  SYSTIME=$(timeout 5 awk '{print $1}' /proc/uptime | xargs)
  echo "SYS UPTIM: $SYSTIME"

  # MINER logs
  RAMLOG=""

  if [ -f "/home/minerstat/snapshot.pid" ]; then
    RAMLOG=""
  else
    RAMLOG=$(timeout 5 cat /dev/shm/miner.log | tac | head --lines 10 | tac)
  fi

  echo "RAMLOG"

  # Extended Query with loop

  if [[ "$CPU_TYPE" != *"Ryzen"* ]]; then
    CPU_TEMP=$(timeout 5 cat /sys/class/thermal/thermal_zone*/temp 2> /dev/null | column -s $'\t' -t | sed 's/\(.\)..$/.\1/' | tac | head -n 1)
  else
    CPU_TEMP=$(timeout 5 sudo sensors 2> /dev/null | grep -A 2 k10temp-pci | grep -E "temp1|Tdie" | awk '{print $2}' | sed 's/[^0-9.]//g')
  fi

  if [ -z "$CPU_TEMP" ]; then
    CPU_TEMP="0"
  fi
  #CPU_USAGE=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage ""}')

  #echo "Remote IP: $STR4"
  echo ""

  IS_ONLINE="YES"
  echo "NETCHECK"

  #while ! ping -c 1 -W 1 api.minerstat.com | grep "0%"; do
  #  OFFLINE_COUNT=$(($OFFLINE_COUNT + $OFFLINE_NUM))
  #  echo "$OFFLINE_COUNT"
  #  IS_ONLINE="NO"
  #  break
  #done

  PING=$(timeout 10 ping -c 1 -W 1 api.minerstat.com)

  if [[ $PING != *"0% packet loss"* ]]; then
    OFFLINE_COUNT=$(($OFFLINE_COUNT + $OFFLINE_NUM))
    echo "$OFFLINE_COUNT"
    IS_ONLINE="NO"
  fi

  if [[ "$IS_ONLINE" = "YES" ]]; then

    OFFLINE_COUNT=0

    echo "online"

    #SEND INFO
    #echo "wget done"

    echo "monitor logs $MONITOR_TYPE"

    # If octominer
    if [[ -f "/dev/shm/octo.pid" ]]; then
      timeout 5 sudo /home/minerstat/minerstat-os/bin/fan_controller_cli -h > /dev/shm/octo_cache.txt 2>&1
      PSUMETER=$(cat /dev/shm/octo_cache.txt | grep Pac | awk '{print $10}' | sed 's/[^0-9.]//g' | cut -f1 -d"." | xargs)
    fi

    if [ "$MONITOR_TYPE" = "amd" ]; then
      AMDINFO=$(sudo timeout 15 /home/minerstat/minerstat-os/bin/gpuinfo amd3)
      QUERYPOWER=$(sudo timeout 5 /home/minerstat/minerstat-os/bin/rocm-smi -P | grep 'Average Graphics Package Power:' | sort -V | sed 's/.*://' | sed 's/W/''/g' | xargs)
      HWMEMORY=$(cat /home/minerstat/minerstat-os/bin/amdmeminfo.txt)
      sudo chmod 777 /dev/shm/amdmeminfo.txt
      if [ ! -f "/dev/shm/amdmeminfo.txt" ]; then
        timeout 30 sudo timeout 10 /home/minerstat/minerstat-os/bin/amdmeminfo -s -q > /dev/shm/amdmeminfo.txt &
        sudo cp -rf /dev/shm/amdmeminfo.txt /home/minerstat/minerstat-os/bin
        sudo chmod 777 /home/minerstat/minerstat-os/bin/amdmeminfo.txt
        # fix issue with meminfo file
        RBC=$(cat /dev/shm/amdmeminfo.txt)
        if [[ $RBC == *"libamdocl"* ]]; then
          sed -i '/libamdocl/d' /dev/shm/amdmeminfo.txt
        fi
        HWMEMORY=$(sudo cat /dev/shm/amdmeminfo.txt)
      fi
      if [ -z "$HWMEMORY" ] || [ -f "/dev/shm/amdmeminfo.txt" ]; then
        HWMEMORY=$(sudo cat /dev/shm/amdmeminfo.txt)
      fi
      if [ -z "$AMDINFO" ]; then
        AMDINFO=$(sudo /home/minerstat/minerstat-os/bin/amdcovc)
      fi
      HWSTRAPS=$(cd /home/minerstat/minerstat-os/bin/; sudo ./"$STRAPFILENAME" --current-minerstat)
      # ?token=$TOKEN&worker=$WORKER&space=$STR1&cpu=$STR2&localip=$STR3&freemem=$STR5&teleid=$TELEID&systime=$SYSTIME&mobo=$MOBO_TYPE&bios=$BIOS_VERSION&msos=$MSOS_VERSION&mac=$MAC_ADDRESS&cputype=$CPU_TYPE&cpu_usage=$CPU_USAGE&cpu_temp=$CPU_TEMP&disk_type=$DISK_TYPE&nvidiad=$NVIDIA_DRIVER&amdd=$AMD_DRIVER&kernel=$KERNEL_VERSION&ubuntu=$UBUNTU_VERSION"
      RESPONSE=$(sudo curl --insecure --connect-timeout 15 --max-time 25 --retry 0 --header "Content-type: application/x-www-form-urlencoded" --request POST --data "htoken=$TOKEN" --data "hworker=$WORKER" --data "hwType=amd" --data "hwData=$AMDINFO" --data "hwPower=$QUERYPOWER" --data "hwMemory=$HWMEMORY" --data "hwStrap=$HWSTRAPS" --data "mineLog=$RAMLOG" --data "space=$STR1" --data "cpu=$STR2" --data "localip=$STR3" --data "freemem=$STR5" --data "teleid=$TELEID" --data "systime=$SYSTIME" --data "mobo=$MOBO_TYPE" --data "bios=$BIOS_VERSION" --data "msos=$MSOS_VERSION" --data "mac=$MAC_ADDRESS" --data "cputype=$CPU_TYPE" --data "cpu_usage=$CPU_USAGE" --data "cpu_temp=$CPU_TEMP" --data "disk_type=$DISK_TYPE" --data "nvidiad=$NVIDIA_DRIVER" --data "amdd=$AMD_DRIVER" --data "kernel=$KERNEL_VERSION" --data "ubuntu=$UBUNTU_VERSION" --data "uefi=$BOOTED" --data "consumption=$PSUMETER" "https://api.minerstat.com:2053/v2/set_node_config_os2.php")
    fi

    if [ "$MONITOR_TYPE" = "nvidia" ]; then
      QUERYNVIDIA=$(sudo timeout 15 /home/minerstat/minerstat-os/bin/gpuinfo nvidia)
      # NVIDIA DRIVER CRASH WATCHDOG
      TESTVIDIA=$(sudo timeout 10 nvidia-smi --query-gpu=count --format=csv,noheader | grep "lost" | xargs)
      if [[ $QUERYNVIDIA == *"failed"* ]]; then
        QUERYNVIDIA=$(echo $QUERYNVIDIA | tr -d "'")
      fi
      if [[ $TESTVIDIA == *"failed"* ]]; then
        TESTVIDIA=$(echo $TESTVIDIA | tr -d "'")
      fi
      RAMLOG="$RAMLOG $TESTVIDIA"
      RESPONSE=$(sudo curl --insecure --connect-timeout 15 --max-time 25 --retry 0 --header "Content-type: application/x-www-form-urlencoded" --request POST --data "htoken=$TOKEN" --data "hworker=$WORKER" --data "hwType=nvidia" --data "hwData=$QUERYNVIDIA" --data "mineLog=$RAMLOG" --data "space=$STR1" --data "cpu=$STR2" --data "localip=$STR3" --data "freemem=$STR5" --data "teleid=$TELEID" --data "systime=$SYSTIME" --data "mobo=$MOBO_TYPE" --data "bios=$BIOS_VERSION" --data "msos=$MSOS_VERSION" --data "mac=$MAC_ADDRESS" --data "cputype=$CPU_TYPE" --data "cpu_usage=$CPU_USAGE" --data "cpu_temp=$CPU_TEMP" --data "disk_type=$DISK_TYPE" --data "nvidiad=$NVIDIA_DRIVER" --data "amdd=$AMD_DRIVER" --data "kernel=$KERNEL_VERSION" --data "ubuntu=$UBUNTU_VERSION" --data "uefi=$BOOTED" --data "consumption=$PSUMETER" "https://api.minerstat.com:2053/v2/set_node_config_os2.php")
    fi

    if [ "$MONITOR_TYPE" = "unknown" ]; then
      QUERYNVIDIA=""
      RESPONSE=$(sudo curl --insecure --connect-timeout 15 --max-time 25 --retry 0 --header "Content-type: application/x-www-form-urlencoded" --request POST --data "htoken=$TOKEN" --data "hworker=$WORKER" --data "hwType=nvidia" --data "hwData=$QUERYNVIDIA" --data "mineLog=$RAMLOG" --data "space=$STR1" --data "cpu=$STR2" --data "localip=$STR3" --data "freemem=$STR5" --data "teleid=$TELEID" --data "systime=$SYSTIME" --data "mobo=$MOBO_TYPE" --data "bios=$BIOS_VERSION" --data "msos=$MSOS_VERSION" --data "mac=$MAC_ADDRESS" --data "cputype=$CPU_TYPE" --data "cpu_usage=$CPU_USAGE" --data "cpu_temp=$CPU_TEMP" --data "disk_type=$DISK_TYPE" --data "nvidiad=$NVIDIA_DRIVER" --data "amdd=$AMD_DRIVER" --data "kernel=$KERNEL_VERSION" --data "ubuntu=$UBUNTU_VERSION" --data "uefi=$BOOTED" --data "consumption=$PSUMETER" "https://api.minerstat.com:2053/v2/set_node_config_os2.php")
    fi

    echo "-*- MINERSTAT LISTENER -*-"

    echo "RESPONSE: $RESPONSE"

  fi

  if [[ "$IS_ONLINE" = "NO" ]]; then
    echo "offline"
    if [ "$OFFLINE_COUNT" = "360" ]; then
      # Reboot after 10 min of connection lost
      RESPONSE="REBOOT"
    fi
  fi

  echo "response check"

  if [ -f "/dev/shm/maintenance.pid" ]; then
    echo "Maintenance mode, all remote commands disabled."
    if [ $RESPONSE = "CONSOLE" ]; then
      RESPONSE="CONSOLE"
    else
      RESPONSE="null"
    fi
  fi

  if [ $RESPONSE = "REBOOT" ]; then
    sudo bash /home/minerstat/minerstat-os/bin/reboot.sh
  fi

  if [ $RESPONSE = "FORCEREBOOT" ]; then
    sudo bash /home/minerstat/minerstat-os/bin/reboot.sh
  fi

  if [ $RESPONSE = "POWERCYCLE" ]; then
    sudo bash /home/minerstat/minerstat-os/bin/reboot.sh powercycle
  fi

  if [ $RESPONSE = "SHUTDOWN" ]; then
    sudo bash /home/minerstat/minerstat-os/bin/reboot.sh shutdown
  fi

  if [ $RESPONSE = "SAFESHUTDOWN" ]; then
    sudo bash /home/minerstat/minerstat-os/bin/reboot.sh safeshutdown
  fi

  if [ $RESPONSE = "FLASH" ]; then
    sudo bash /home/minerstat/minerstat-os/bin/getflash.sh
  fi

  if [ $RESPONSE = "DIRECT" ]; then
    sudo bash /home/minerstat/minerstat-os/bin/getdirect.sh &
  fi

  if [ $RESPONSE = "GETBIOS" ]; then
    sudo bash /home/minerstat/minerstat-os/bin/getbios.sh
  fi

  if [[ $RESPONSE == *"WORKERNAME"* ]]; then
    echo "-------------------------------------------"
    BL=""
    MA="WORKERNAME "
    WN=$(echo $RESPONSE | sed "s/$MA/$BL/" | xargs | xargs)
    echo "New AccessKey: $TOKEN"
    echo "New Worker Name: $WN"
    echo
    echo "stop" > /tmp/stop.pid;
    sudo node /home/minerstat/minerstat-os/stop.js
    sudo su minerstat -c "screen -X -S minerstat-console quit";
    sudo su -c "sudo screen -X -S minew quit"
    sudo echo global.accesskey = '"'$TOKEN'";' > /media/storage/config.js
    sudo echo global.worker = '"'$WN'";' >> /media/storage/config.js
    sudo cp /media/storage/config.js /home/minerstat/minerstat-os/
    echo "Validate Config..."
    echo
    sudo cat /media/storage/config.js
    screen -A -m -d -S namechange sudo bash /home/minerstat/minerstat-os/core/namenstart
    echo "-------------------------------------------"
  fi

  if [ $RESPONSE = "INSTANTOC" ]; then
    echo "-------------------------------------------"
    screen -A -m -d -S instantoc sudo /home/minerstat/minerstat-os/bin/overclock.sh instant &
    echo "-------------------------------------------"
  fi

  if [ $RESPONSE = "SETFANS" ]; then
    echo "-------------------------------------------"
    screen -A -m -d -S instantoc sudo /home/minerstat/minerstat-os/bin/setfans.sh &
    echo "-------------------------------------------"
  fi

  if [ $RESPONSE = "DOWNLOADWATTS" ] || [ $RESPONSE = "RESTARTWATTS" ]; then
    echo "-------------------------------------------"
    screen -A -m -d -S overclocks sudo /home/minerstat/minerstat-os/bin/overclock.sh &
    if [ ! -f "/tmp/stop.pid" ]; then
      RESPONSE="RESTART"
    fi
    echo "-------------------------------------------"
  fi

  if [ $RESPONSE = "DIAG" ]; then
    echo "-------------------------------------------"
    screen -A -m -d -S diag sudo /home/minerstat/minerstat-os/core/diag
    echo "-------------------------------------------"
  fi

  if [ $RESPONSE = "UPDATE" ]; then
    echo "-------------------------------------------"
    sudo bash /home/minerstat/minerstat-os/git.sh
    echo "-------------------------------------------"
  fi

  if [ $RESPONSE = "CONSOLE" ]; then
    sudo killall tmate
    sudo killall tmate
    sudo su minerstat -c "sudo /bin/sh /home/minerstat/minerstat-os/core/rmate"
    sleep 1
    TELEID=$(sudo /home/minerstat/minerstat-os/bin/tmate -S /tmp/tmate.sock display -p '#{tmate_ssh}' | cut -f1 -d"@" | sed 's/.* //')
    echo "TeleID: $TELEID"
    wget -o /dev/null -qO- "https://api.minerstat.com:2053/v2/set_os_status.php?token=$TOKEN&worker=$WORKER&space=$STR1&cpu=$STR2&localip=$STR3&freemem=$STR5&teleid=$TELEID&systime=$SYSTIME&mobo=$MOBO_TYPE&bios=$BIOS_VERSION&msos=$MSOS_VERSION&mac=$MAC_ADDRESS&cputype=$CPU_TYPE&cpu_usage=$CPU_USAGE&cpu_temp=$CPU_TEMP&disk_type=$DISK_TYPE&nvidiad=$NVIDIA_DRIVER&amdd=$AMD_DRIVER&kernel=$KERNEL_VERSION&ubuntu=$UBUNTU_VERSION" ; echo
  fi

  if [ $RESPONSE = "RESTART" ] || [ $RESPONSE = "START" ] || [ $RESPONSE = "NODERESTART" ] || [ $RESPONSE = "RESTARTNODE" ]; then
    sudo su -c "sudo rm /tmp/stop.pid"
    sudo su -c "sudo screen -X -S minew quit"
    sudo su -c "sudo screen -X -S fakescreen quit"
    sudo su -c "screen -ls minew | grep -E '\s+[0-9]+\.' | awk -F ' ' '{print $1}' | while read s; do screen -XS $s quit; done"
    sudo su minerstat -c "screen -X -S fakescreen quit"
    sudo su minerstat -c "screen -ls minerstat-console | grep -E '\s+[0-9]+\.' | awk -F ' ' '{print $1}' | while read s; do screen -XS $s quit; done"
    sudo killall node
    sudo su minerstat -c "screen -A -m -d -S fakescreen sh /home/minerstat/minerstat-os/bin/fakescreen.sh"
    sleep 2
    sudo su minerstat -c "screen -A -m -d -S minerstat-console sudo /home/minerstat/minerstat-os/launcher.sh"
  fi

  if [ $RESPONSE = "STOP" ]; then
    echo "stop" > /tmp/stop.pid;
    sudo su -c "echo "" > /dev/shm/miner.log"
    sudo su -c "echo 'stop' > /tmp/stop.pid"
    sudo su minerstat -c "screen -X -S minerstat-console quit";
    sudo su -c "sudo screen -X -S minew quit"
    sudo node /home/minerstat/minerstat-os/stop.js
    sleep 2
    sudo su -c "sudo screen -X -S minew quit"
    sudo su minerstat -c "screen -X -S minerstat-console quit";
  fi

  #if [ $RESPONSE = "RECOVERY" ]; then
  #  cd /tmp; sudo screen -wipe; wget https://raw.githubusercontent.com/minerstat/minerstat-os/master/core/recovery.sh; sudo chmod 777 recovery.sh; nohup sh recovery.sh &
  #fi

  if [ $RESPONSE = "null" ]; then
    echo "No remote command pending..";
  fi

  sleep 17

done
