#!/bin/bash
exec 2>/dev/null
echo "[0%] Running Clean jobs ..."
TESTLOGIN=$(timeout 2 systemctl list-jobs)
if [ "$TESTLOGIN" != "No jobs running." ]; then
  sudo systemctl restart systemd-logind.service &
fi
CL=/media/storage/opencl.txt
if [ ! -f "$CL" ]; then
  sudo su -c "echo 'amd' > $CL; echo '/opt/amdgpu-pro/lib/x86_64-linux-gnu/libamdocl64.so' > /etc/OpenCL/vendors/amdocl64.icd"
  echo "OpenCL switched to: amdgpu"
fi
#START SOCKET
# Only start if no sockets instance running
#SNUM=$(sudo su minerstat -c "screen -list | grep -c sockets")
#if [ "$SNUM" -lt "1" ]; then
#sudo su minerstat -c "screen -ls | grep sockets | cut -d. -f1 | awk '{print $1}' | xargs kill -9; screen -wipe; sudo killall sockets; screen -A -m -d -S sockets sudo bash /home/minerstat/minerstat-os/core/sockets" > /dev/null
#fi
#END SOCKET
echo "[10%] Checking services ..."
timeout 10 sudo systemctl mask apt-daily.service apt-daily-upgrade.service > /dev/null &
timeout 10 sudo apt-mark hold linux-generic linux-image-generic linux-headers-generic linux-firmware > /dev/null &
timeout 10 sudo systemctl disable thermald systemd-timesyncd.service > /dev/null &
timeout 10 sudo systemctl stop thermald systemd-timesyncd.service > /dev/null &
AUTOLOGIN=$(cat /lib/systemd/system/getty@.service | grep autologin)
AUTOLOGINE=$(cat /lib/systemd/system/getty@.service | grep -c ExecStart)
if [[ -z "$AUTOLOGIN" ]] || [[ "$AUTOLOGINE" != "1" ]]; then
  echo "Applying autologin settings.."
  sudo sed -i '/ExecStart/d' /lib/systemd/system/getty@.service
  sudo sed -i '/Type=idle/ i ExecStart=-/sbin/agetty --autologin minerstat --noclear %I $TERM' /lib/systemd/system/getty@.service
  timeout 10 sudo systemctl daemon-reload
  timeout 10 sudo systemctl restart getty@tty1
fi
timeout 10 sudo systemctl daemon-reload > /dev/null &
# Kernel panic auto reboot and clean older miner logs
timeout 10 sudo su -c "sudo echo 1 > /proc/sys/kernel/sysrq; sudo echo 20 > /proc/sys/kernel/panic; echo '' > /dev/shm/miner.log"
# Remove logs
timeout 10 find '/home/minerstat/minerstat-os/clients/claymore-eth' -name "*log.txt" -type f -delete
timeout 10 sudo find /var/log -type f -name "*.journal" -delete
timeout 10 sudo su -c "sudo service rsyslog stop"
#sudo su -c "systemctl disable rsyslog"
#sudo su -c "systemctl disable wpa_supplicant"
#echo "Log files deleted"
timeout 10 sudo dmesg -n 1
#sudo apt clean &
# Apply crontab + Fix slow start
echo "[20%] Setting env varibles ..."
sudo su -c "cp /home/minerstat/minerstat-os/core/minerstat /var/spool/cron/crontabs/minerstat; chmod 600 /var/spool/cron/crontabs/; chown minerstat /var/spool/cron/crontabs/minerstat; systemctl disable NetworkManager-wait-online.service; systemctl disable systemd-networkd-wait-online.service"
sudo chmod 1730 /var/spool/cron/crontabs
sudo chown root:crontab /var/spool/cron/crontabs
sudo service cron restart
sudo sed -i s/"TimeoutStartSec=5min"/"TimeoutStartSec=5sec"/ /etc/systemd/system/network-online.target.wants/networking.service
#sudo sed -i s/"timeout 300"/"timeout 5"/ /etc/dhcp/dhclient.conf
sudo sed -i s/"timeout 5"/"timeout 25"/ /etc/dhcp/dhclient.conf
sudo sed -i s/"#retry 60;"/"retry 30;"/ /etc/dhcp/dhclient.conf
# remove wget logs
timeout 3 sudo rm -rf /home/minerstat/minerstat-os/wget-log*
# Nvidia PCI_BUS_ID
sudo rm /etc/environment
sudo cp /home/minerstat/minerstat-os/core/environment /etc/environment
export CUDA_DEVICE_ORDER=PCI_BUS_ID
sudo su -c "export CUDA_DEVICE_ORDER=PCI_BUS_ID"
# libc-ares2 && libuv1-dev
# sudo apt-get --yes --force-yes install libcurl3/bionic | grep "install"
# Max performance
#export GPU_FORCE_64BIT_PTR=1 #causes problems
export GPU_USE_SYNC_OBJECTS=1
export GPU_MAX_ALLOC_PERCENT=100
export GPU_SINGLE_ALLOC_PERCENT=100
export GPU_MAX_HEAP_SIZE=100
# Check SSH Keys
screen -A -m -d -S sshgens sudo /home/minerstat/minerstat-os/core/ressh &
# .bashrc
sudo cp -fR /home/minerstat/minerstat-os/core/.bashrc /home/minerstat
# rocm for VEGA
export HSA_ENABLE_SDMA=0
# Hugepages (XMR) [Need more test, this required or not]

FILE=/media/storage/hugepage.txt
if [ -f "$FILE" ]; then
  HPAGE=$(cat /media/storage/hugepage.txt)
  if [ -z "$HPAGE" ]; then
    HPAGE=128
  fi
else
  HPAGE=128
fi

FILE_NVFLASH=/home/minerstat/minerstat-os/core2
if [ -d "$FILE_NVFLASH" ]; then
  sudo mv /home/minerstat/minerstat-os/core2 /home/minerstat/minerstat-os/core
fi

sudo su -c "echo $HPAGE > /proc/sys/vm/nr_hugepages; sysctl vm.nr_hugepages=$HPAGE; echo always > /sys/kernel/mm/transparent_hugepage/enabled; sysctl vm.dirty_background_ratio=20; sysctl vm.dirty_expire_centisecs=0; sysctl vm.dirty_ratio=80; sysctl vm.dirty_writeback_centisecs=0" > /dev/null 2>&1
# Auto OpenCL for/above v1.5
version=`cat /etc/lsb-release | grep "DISTRIB_RELEASE=" | sed 's/[^.0-9]*//g'`

echo "[30%] Validating hosts file ..."

# Fix ERROR Messages
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
# OpenCL
export OpenCL_ROOT=/opt/amdgpu-pro/lib/x86_64-linux-gnu
# FSCK
sudo sed -i s/"#FSCKFIX=no"/"FSCKFIX=yes"/ /etc/default/rcS
# Intel Energy-Efficient Ethernet
sudo ethtool --set-eee eth0 eee off 2>/dev/null
if [ ! -f "/etc/modprobe.d/e1000e.conf" ]; then
  echo "options e1000e EEE=0" | sudo tee /etc/modprobe.d/e1000e.conf
fi
# Clear clock cache
CCHECK=$(cat /home/minerstat/cache_date 2>/dev/null)
echo "#!/bin/bash" > /home/minerstat/clock_cache
# Validate hosts file
sudo bash /home/minerstat/minerstat-os/bin/hostfix.sh

echo "[40%] Generating device report ..."

# Memory Info
timeout 5 sudo chmod -R 777 * /home/minerstat/minerstat-os

if [ -z "$1" ]; then
  AMDDEVICE=$(timeout 40 sudo lspci -k | grep VGA | grep -vE "Kaveri|Beavercreek|Sumo|Wrestler|Kabini|Mullins|Temash|Trinity|Richland|Stoney|Carrizo|Raven|Renoir|Picasso|Van" | grep -c "AMD")
  if [ -z "$AMDDEVICE" ]; then
    AMDDEVICE=$(timeout 3 sudo lshw -C display | grep AMD | wc -l)
  fi
  if [ -z "$AMDDEVICE" ]; then
    AMDDEVICE=$(timeout 3 sudo lshw -C display | grep driver=amdgpu | wc -l)
  fi
  #if [ "$AMDDEVICE" = "0" ]; then
  #  AMDDEVICE=$(sudo lshw -C display | grep driver=amdgpu | wc -l)
  #fi
fi
# SSL off for bad timedate bioses
timeout 5 sudo npm config set strict-ssl false
timeout 5 git config --global http.sslverify false
# Update motd.d
timeout 5 sudo chmod 777 /etc/update-motd.d/10-help-text
timeout 5 sudo cp /home/minerstat/minerstat-os/core/10-help-text /etc/update-motd.d
# disable wifi powersave
timeout 3 sudo sed -i 's/3/2/' /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf
# Update tmux design
if [ "$version" = "1.6.0" ]; then
  sudo cp -f /home/minerstat/minerstat-os/core/.tmux2.conf /home/minerstat/.tmux.conf
else
  sudo cp -f /home/minerstat/minerstat-os/core/.tmux.conf /home/minerstat
fi
# Tmate config
sudo cp /home/minerstat/minerstat-os/core/.tmate.conf /home/minerstat
echo "" | ssh-keygen -N "" &> /dev/null
# ssh pam
sudo chmod -R 600 /etc/ssh
TESTPAM=$(sudo cat /etc/ssh/sshd_config | grep UsePAM)
if [[ ! -z "$TESTPAM" ]] && [[ $TESTPAM == *"no"* ]]; then
  sudo sed -i 's/UsePAM no/UsePAM yes/' /etc/ssh/sshd_config
  sudo service sshd restart > /dev/null
fi
#sudo killall tmate
#/home/minerstat/minerstat-os/bin/tmate -S /tmp/tmate.sock new-session -d

echo "[50%] Restarting services ..."

# Update profile
sudo chmod 777 /etc/profile
sudo cp /home/minerstat/minerstat-os/core/profile /etc
# Restart listener, Maintenance Process, Also from now it can be updated in runtime (mupdate)
timeout 5 sudo su -c "screen -S listener -X quit" > /dev/null
timeout 5 sudo su minerstat -c "screen -S listener -X quit" > /dev/null
timeout 5 sudo su minerstat -c "screen -A -m -d -S listener sudo bash /home/minerstat/minerstat-os/core/init.sh"
# Disable UDEVD & JOURNAL
timeout 5 sudo systemctl stop systemd-udevd systemd-udevd-kernel.socket systemd-udevd-control.socket
timeout 5 sudo systemctl disable systemd-udevd systemd-udevd-kernel.socket systemd-udevd-control.socket
timeout 5 sudo su -c "sudo rm -rf /var/log/journal; sudo ln -s /dev/shm /var/log/journal"
timeout 5 sudo systemctl start systemd-journald.service systemd-journald.socket systemd-journald-dev-log.socket
# Create Shortcut for JQ
sudo ln -s /home/minerstat/minerstat-os/bin/jq /sbin &> /dev/null
# Remove ppfeaturemask to avoid kernel panics with old cards
#sudo chmod 777 /boot/grub/grub.cfg && sudo su -c "sed -Ei 's/amdgpu.ppfeaturemask=0xffffffff//g' /boot/grub/grub.cfg" && sudo chmod 444 /boot/grub/grub.cfg
# Restart fan curve if running
FNUM=$(sudo su -c "screen -list | grep -c curve")
if [ "$FNUM" -gt "0" ]; then
  sudo killall curve > /dev/null
  sleep 0.1
  sudo kill -9 $(sudo pidof curve) > /dev/null
  sleep 0.2
  sudo screen -A -m -d -S curve /home/minerstat/minerstat-os/core/curve
fi
# Safety layer
CURVE_FILE=/media/storage/fans.txt
if [ -f "$CURVE_FILE" ]; then
  sudo killall curve > /dev/null
  sleep 0.1
  sudo kill -9 $(sudo pidof curve) > /dev/null
  sleep 0.1
  sudo screen -A -m -d -S curve /home/minerstat/minerstat-os/core/curve
fi

echo "[60%] Validating Time/Date ..."

# Time Date SYNC
timeout 5 sudo timedatectl set-ntp on &
DATES=$(timeout 3 curl -v --insecure --silent www.minerstat.com 2>&1 | grep Date | sed -e 's/< Date: //')
if [[ ! -z "$DATES" ]]; then
  sudo date -s "$(echo $DATES)"
else
  DATES=$(timeout 3 curl -v --insecure --silent google.com 2>&1 | grep Date | sed -e 's/< Date: //')
  if [[ ! -z "$DATES" ]]; then
    sudo date -s "$(echo $DATES)"
  fi
fi
# Copy PCIIDS
yes | sudo cp -rf /home/minerstat/minerstat-os/bin/pci.ids /usr/share/misc/pci.ids
# NVIDIA
timeout 5 sudo getent group nvidia-persistenced &>/dev/null || sudo groupadd -g 143 nvidia-persistenced &
timeout 5 sudo getent passwd nvidia-persistenced &>/dev/null || sudo useradd -c 'NVIDIA Persistence Daemon' -u 143 -g nvidia-persistenced -d '/' -s /sbin/nologin nvidia-persistenced &
# Safety check for sockets, if double instance kill
SNUM=$(sudo su minerstat -c "screen -list | grep -c sockets")
if [ "$SNUM" != "1" ]; then
  sudo su minerstat -c "screen -ls | grep sockets | cut -d. -f1 | awk '{print $1}' | xargs kill -9; screen -wipe; sudo killall sockets; sleep 0.5; sudo killall sockets; screen -A -m -d -S sockets sudo bash /home/minerstat/minerstat-os/core/sockets" > /dev/null
fi
# Check for watchdogs
SNUM=$(sudo su minerstat -c "screen -list | grep -c usbdog")
if [ "$SNUM" != "1" ]; then
  sudo su minerstat -c "screen -ls | grep usbdog | cut -d. -f1 | awk '{print $1}' | xargs kill -9; screen -wipe; sudo killall usbdog; sleep 0.5; sudo killall usbdog; screen -A -m -d -S usbdog sudo bash /home/minerstat/minerstat-os/watchdog" > /dev/null
fi
# TCP segmentation offload
TSOT=$(timeout 5 ethtool -k eth0 | grep tcp-segmentation-offload | xargs)
if [[ -z "$TSOT" ]] && [[ $TSOT != *"off"* ]]; then
  TETH=$(which ethtool)
  if [[ -z "$TETH" ]]; then
    timeout 5 sudo ethtool -K eth0 tso off
  fi
fi
echo "[70%] Checking X Server ..."
# Check XSERVER
XINST=$(which X)
if [[ -z "$XINST" ]]; then
  sudo apt-get update
  sudo apt-get -y install xorg --fix-missing
fi
# If uptime < 4 minutes then exit
UPTIME=$(awk '{print $1}' /proc/uptime | cut -f1 -d"." | xargs)
#NVIDIADEVICE=$(timeout 5 sudo lspci -k | grep VGA | grep -vE "Kaveri|Beavercreek|Sumo|Wrestler|Kabini|Mullins|Temash|Trinity|Richland|Stoney|Carrizo|Raven|Renoir|Picasso|Van" | grep -c "NVIDIA")
#if [ "$NVIDIADEVICE" = "0" ]; then
NVIDIADEVICE=$(timeout 3 sudo lshw -C display | grep "driver=nvidia" | wc -l)
#fi
if [ "$NVIDIADEVICE" = "0" ]; then
  NVIDIADEVICE=$(timeout 3 sudo lshw -C display | grep NVIDIA | wc -l)
fi
if [ "$NVIDIADEVICE" != "0" ]; then
  #if echo "$NVIDIA" | grep -iq "^GPU 0:" ;then
  DONVIDIA="YES"
  # Check XSERVER
  XORG=$(timeout 5 nvidia-smi | grep -c Xorg)
  SNUM=$(sudo su minerstat -c "screen -list | grep -c display2")
  # Only check during boot
  CHECK_ERR=0
  if [ "$UPTIME" -lt "240" ]; then
    # Unknown Error
    FANMAX=$(cat /media/storage/fans.txt 2>/dev/null | grep "FANMAX=" | xargs | sed 's/[^0-9]*//g')
    if [ -z "$FANMAX" ]; then
      FANMAX=70
    fi
    timeout 10 sudo rm /dev/shm/nverr.txt &> /dev/null
    CHECK_ERR=$(timeout 10 sudo nvidia-settings --verbose -c :0 -a GPUFanControlState=1 -a GPUTargetFanSpeed="$FANMAX" &> /dev/shm/nverr.txt)
    CHECK_ERR=$(cat /dev/shm/nverr.txt | grep -c "Unknown Error")
  fi
  if [[ "$SNUM" != "1" ]] || [[ "$XORG" -lt 1 ]] || [[ "$XORG" -lt $NVIDIADEVICE ]] || [[ "$CHECK_ERR" -gt 0 ]]; then
    sudo su -c "timeout 10 sudo screen -X -S display quit" > /dev/null
    timeout 10 screen -X -S display quit > /dev/null
    timeout 10 screen -X -S display2 quit > /dev/null
    sudo timeout 10 killall X > /dev/null
    sudo timeout 10 killall Xorg > /dev/null
    sudo timeout 5 kill -9 $(sudo pidof Xorg) > /dev/null
    sudo timeout 5 rm /tmp/.X0-lock > /dev/null
    echo "device num: $NVIDIADEVICE"
    EGPU=""
    EGPU_FETCH=$(sudo timeout 10 nvidia-xconfig -A | grep -c "egpu")
    if [[ "$EGPU_FETCH" -gt 0 ]]; then
      EGPU="--egpu"
    fi
    # Remove previous xorg config
    sudo rm -f /etc/X11/xorg.conf
    sudo su -c "echo '' > /etc/X11/xorg.conf"
    sudo nvidia-xconfig --preserve-busid --preserve-driver-name
    # Generate new xorg
    if [[ "$NVIDIADEVICE" -gt 1 ]]; then
      sudo timeout 30 nvidia-xconfig -a --allow-empty-initial-configuration --cool-bits=31 --use-display-device="DFP-0" --connected-monitor="DFP-0" --custom-edid="DFP-0:/home/minerstat/minerstat-os/bin/edid.bin" --use-edid --use-edid-dpi --preserve-driver-name --preserve-busid --enable-all-gpus $EGPU
    else
      sudo timeout 30 nvidia-xconfig -a --allow-empty-initial-configuration --cool-bits=31 --use-display-device="DFP-0" --connected-monitor="DFP-0" --custom-edid="DFP-0:/home/minerstat/minerstat-os/bin/edid.bin" --use-edid --use-edid-dpi --preserve-driver-name --preserve-busid $EGPU
    fi
    sudo sed -i s/"DPMS"/"NODPMS"/ /etc/X11/xorg.conf > /dev/null
    sudo sed -i 's/UseEdid" "True"/UseEdid" "True"\n    Option         "IgnoreEDID" "False"/g' /etc/X11/xorg.conf
    sudo su minerstat -c "screen -A -m -d -S display2 sudo X :0" > /dev/null
  fi
fi
echo "[80%] Updating plugins ..."
# lanflare
if [ "$UPTIME" -lt "240" ]; then
  # only changeme
  TESTC=$(cat /home/minerstat/minerstat-os/config.js | grep -c 'global.accesskey = "CHANGEME"')
  if [[ "$TESTC" -gt "0" ]]; then
    if [ ! -f "/dev/shm/gpudata_sort.txt" ]; then
      sudo bash /home/minerstat/minerstat-os/core/gputable > /dev/null 2>&1
    fi
    TESTSC=$(ps aux | grep -c lanflare.pyc)
    # check for 2 instead of 1, as aux checking grep too
    if [[ "$TESTC" = "1" ]]; then
      screen -A -m -d -S discovery sudo bash /home/minerstat/minerstat-os/bin/lanflare
    fi
  fi
fi
# nvidia-settings fix for Segmentation fault
CHECKAPTXN=$(dpkg -l | grep "libegl1-amdgpu-pro" | wc -l)
if [ "$CHECKAPTXN" -gt "0" ]; then
  if [ "$NVIDIADEVICE" -gt 0 ]; then
    sudo dpkg --remove --force-all libegl1-amdgpu-pro:i386 libegl1-amdgpu-pro:amd64
  fi
fi

echo "[90%] Checking for new devices ..."

# Detect octo
sudo /home/minerstat/minerstat-os/core/octoctrl --detect > /dev/null 2>&1 &
# Update mini lcd screen
#if [[ -f "/dev/shm/octo.pid" ]]; then
#  sudo /home/minerstat/minerstat-os/core/octoctrl --display > /dev/null 2>&1
#fi
if [ "$1" -gt 0 ] || [ "$AMDDEVICE" -gt 0 ]; then
  #sudo /home/minerstat/minerstat-os/bin/amdmeminfo -s -o -q > /home/minerstat/minerstat-os/bin/amdmeminfo.txt &
  TEST=$(cat /dev/shm/amdmeminfo.txt)
  if [ -z "$TEST" ]; then
    timeout 5 sudo rm /home/minerstat/minerstat-os/bin/amdmeminfo.txt
    timeout 5 sudo rm /dev/shm/amdmeminfo.txt
    sudo chmod 777 /dev/shm/amdmeminfo.txt
    timeout 30 sudo /home/minerstat/minerstat-os/bin/amdmeminfo -s -q > /dev/shm/amdmeminfo.txt &
    sudo chmod 777 /dev/shm/amdmeminfo.txt
    # fix issue with meminfo file
    RBC=$(cat /dev/shm/amdmeminfo.txt)
    if [[ $RBC == *"libamdocl"* ]]; then
      sed -i '/libamdocl/d' /dev/shm/amdmeminfo.txt
    fi
    sudo cp -rf /dev/shm/amdmeminfo.txt /home/minerstat/minerstat-os/bin
    sudo chmod 777 /home/minerstat/minerstat-os/bin/amdmeminfo.txt
  fi
  CHECKPY=$(dpkg -l | grep python3-pip)
  if [[ -z $CHECKPY ]]; then
    sudo apt-get update
    sudo apt-get -y install python3-pip --fix-missing
    sudo su minerstat -c "pip3 install setuptools"
    sudo su minerstat -c "pip3 install git+https://labs.minerstat.farm/repo/upp"
    sudo su -c "pip3 install git+https://labs.minerstat.farm/repo/upp"
  fi
  # Check UPP installed
  FILE=/home/minerstat/.local/bin/upp
  if [ ! -f "$FILE" ]; then
    sudo su minerstat -c "pip3 install setuptools"
    sudo su minerstat -c "pip3 install git+https://labs.minerstat.farm/repo/upp"
    sudo su -c "pip3 install git+https://labs.minerstat.farm/repo/upp"
  fi
fi
if [ -f "/etc/netplan/minerstat.yaml" ]; then
  if ! grep -q dhcp-identifier "/etc/netplan/minerstat.yaml"; then
    INTERFACE="$(sudo cat /proc/net/dev | grep -vE lo | tail -n1 | awk -F '\\:' '{print $1}' | xargs)"
    if [ "$INTERFACE" = "eth0" ]; then
      sudo echo "network:" > /etc/netplan/minerstat.yaml
      sudo echo " version: 2" >> /etc/netplan/minerstat.yaml
      sudo echo " renderer: networkd" >> /etc/netplan/minerstat.yaml
      sudo echo " ethernets:" >> /etc/netplan/minerstat.yaml
      sudo echo "   eth0:" >> /etc/netplan/minerstat.yaml
      sudo echo "     dhcp4: yes" >> /etc/netplan/minerstat.yaml
      sudo echo "     dhcp-identifier: mac" >> /etc/netplan/minerstat.yaml
      sudo echo "     dhcp6: no" >> /etc/netplan/minerstat.yaml
      sudo echo "     nameservers:" >> /etc/netplan/minerstat.yaml
      sudo echo "         addresses: [1.1.1.1, 1.0.0.1]" >> /etc/netplan/minerstat.yaml
      sudo /usr/sbin/netplan apply
    fi
  fi
fi

echo "[100%] Done"
