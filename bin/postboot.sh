#!/bin/bash

NVIDIA="$(nvidia-smi -L)"
AMDDEVICE=$(lsmod | grep amdgpu | wc -l)

if grep -q experimental "/etc/lsb-release"; then
  if [ "$AMDDEVICE" -gt 0 ]; then
    echo "INFO: Seems you have AMD Device enabled, activating OpenCL Support."
    echo "INFO: Nvidia / AMD Mixing not supported. If you want to use OS on another rig, do mrecovery."
    sudo apt-get --yes --force-yes install libegl1-amdgpu-pro:amd64 libegl1-amdgpu-pro:i386
  fi
fi

echo -e "\033[1;34m==\033[0m Starting local web console ...\033[0m"
cd /home/minerstat/minerstat-os/bin
#./shellinaboxd --port 4200 -b --css "/home/minerstat/minerstat-os/core/white-on-black.css" --disable-ssl

if [ ! -z "$NVIDIA" ]; then

  if echo "$NVIDIA" | grep -iq "^GPU 0:"; then

    ETHPILLARGS=$(cat /media/storage/settings.txt 2>/dev/null | grep 'OHGODARGS="' | sed 's/OHGODARGS="//g' | sed 's/"//g')
    ETHPILLDELAY=$(cat /media/storage/settings.txt 2>/dev/null | grep 'OHGODADELAY=' | sed 's/[^0-9]*//g')
    NVIDIA_LED=$(cat /media/storage/settings.txt | grep "NVIDIA_LED=" | sed 's/[^=]*\(=.*\)/\1/' | tr --delete = | xargs)

    if [ "$NVIDIA_LED" = "OFF" ]; then
      sudo nvidia-settings --assign GPULogoBrightness=0 -c :0
    fi

    if grep -q experimental "/etc/lsb-release"; then
      CHECKAPTXN=$(dpkg -l | grep "libegl1-amdgpu-pro" | wc -l)
      if [ "$CHECKAPTXN" -gt "0" ]; then
        sudo dpkg --remove --force-all libegl1-amdgpu-pro:i386 libegl1-amdgpu-pro:amd64
      fi
    fi

    PILL=$(sudo screen -list | grep -c "ethboost")
    if [[ "$PILL" -lt "1" ]]; then
      if [ "$ETHPILLDELAY" != "999" ]; then
        cd /home/minerstat/minerstat-os/bin
        sudo chmod 777 /home/minerstat/minerstat-os/bin/OhGodAnETHlargementPill-r2
        sudo screen -A -m -d -S ethboost sudo bash ethpill.sh "$ETHPILLARGS"
      fi
    fi

  fi
fi

echo -e "\033[1;34m==\033[0m Initializing jobs ...\033[0m"
# Safety check for sockets, if double instance kill
SNUM=$(sudo su minerstat -c "screen -list | grep -c sockets")
if [ "$SNUM" != "1" ]; then
  sudo su minerstat -c "screen -ls | grep sockets | cut -d. -f1 | awk '{print $1}' | xargs kill -9; screen -wipe; sudo killall sockets; sleep 0.5; sudo killall sockets; screen -A -m -d -S sockets sudo bash /home/minerstat/minerstat-os/core/sockets" > /dev/null
fi
cd /home/minerstat/minerstat-os/bin
sudo bash jobs.sh $AMDDEVICE

sleep 1
sudo chvt 1

cd /home/minerstat/minerstat-os/core
sudo bash expand.sh

echo -e "\033[1;34m==\033[0m Waiting for console output ...\033[0m"

sudo chvt 1
#sudo su minerstat -c "sh /home/minerstat/minerstat-os/core/view"
#sleep 1
