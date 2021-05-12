if ! screen -list | grep -q "dummy"; then

  screen -A -m -d -S dummy sleep 86400
  screen -S listener -X quit # kill running process
  screen -A -m -d -S listener sudo sh /home/minerstat/minerstat-os/core/init.sh

  sudo echo "boot" > /home/minerstat/minerstat-os/bin/random.txt
  sudo find /var/log -type f -delete

  # Fix Slow start bug
  sudo systemctl disable NetworkManager-wait-online.service

  # FIX CTRL + ALT + F1
  screen -A -m -d -S chvt sudo watch -n1 sudo chvt 1

  #echo "-------- OVERCLOCKING ---------------------------"
  #cd /home/minerstat/minerstat-os/bin
  #sudo sh overclock.sh

  # Change hostname
  #WNAME=$(cat /media/storage/config.js | grep 'global.worker' | sed 's/global.worker =/"/g' | sed 's/"//g' | sed 's/;//g' | xargs)
  #sudo su -c "echo '$WNAME' > /etc/hostname"
  #sudo hostname -F /etc/hostname

  echo " "
  echo "-------- CONFIGURE NETWORK ADAPTERS --------------"
  SSID=$(cat /media/storage/network.txt | grep 'WIFISSID="' | sed 's/WIFISSID="//g' | sed 's/"//g' | xargs | wc -L)
  DHCP=$(cat /media/storage/network.txt | grep 'DHCP="' | sed 's/DHCP="//g' | sed 's/"//g')

  #sudo screen -A -m -d -S restartnet sudo /etc/init.d/networking restart

  HAVECONNECTION="true"

  while ! sudo ping minerstat.com. -w 1 | grep "0%"; do
    HAVECONNECTION="false"
    break
  done


  if [ "$HAVECONNECTION" != "true" ]
  then

    GET_GATEWAY=$(route -n -e -4 | awk {'print $2'} | grep -vE "0.0.0.0|IP|Gateway" | head -n1 | xargs)
    # systemd resolve casusing problems with 127.0.0.53
    if [ ! -z "$GET_GATEWAY" ]; then
      sudo su -c "echo 'nameserver $GET_GATEWAY' > /run/resolvconf/interface/systemd-resolved" 2>/dev/null
    fi
    sudo su -c 'echo "nameserver 1.1.1.1" >> /run/resolvconf/interface/systemd-resolved' 2>/dev/null
    sudo su -c 'echo "nameserver 1.0.0.1" >> /run/resolvconf/interface/systemd-resolved' 2>/dev/null
    sudo su -c 'echo "nameserver 8.8.8.8" >> /run/resolvconf/interface/systemd-resolved' 2>/dev/null
    sudo su -c 'echo "nameserver 8.8.4.4" >> /run/resolvconf/interface/systemd-resolved' 2>/dev/null
    if [ ! -z "$GET_GATEWAY" ]; then
      sudo su -c "echo 'nameserver $GET_GATEWAY' > /run/systemd/resolve/stub-resolv.conf" 2>/dev/null
    fi
    sudo su -c 'echo "nameserver 1.1.1.1" >> /run/systemd/resolve/stub-resolv.conf' 2>/dev/null
    sudo su -c 'echo "nameserver 1.0.0.1" >> /run/systemd/resolve/stub-resolv.conf' 2>/dev/null
    sudo su -c 'echo "nameserver 8.8.8.8" >> /run/systemd/resolve/stub-resolv.conf' 2>/dev/null
    sudo su -c 'echo "nameserver 8.8.4.4" >> /run/systemd/resolve/stub-resolv.conf' 2>/dev/null
    sudo su -c 'echo options edns0 >> /run/systemd/resolve/stub-resolv.conf' 2>/dev/null
    # China
    sudo su -c 'echo "nameserver 114.114.114.114" >> /etc/resolv.conf' 2>/dev/null
    sudo su -c 'echo "nameserver 114.114.115.115" >> /etc/resolv.conf' 2>/dev/null

    if [ "$SSID" -gt 0 ]; then
      cd /home/minerstat/minerstat-os/core
      sudo sh wifi.sh

    else

      if [ "$DHCP" != "NO" ]
      then
        cd /home/minerstat/minerstat-os/bin
        sudo sh dhcp.sh
      else
        cd /home/minerstat/minerstat-os/bin
        sudo sh static.sh
      fi

    fi


  fi

  # Rewrite
  sudo systemctl stop systemd-resolved
  GET_GATEWAY=$(route -n -e -4 | awk {'print $2'} | grep -vE "0.0.0.0|IP|Gateway" | head -n1 | xargs)
  sudo su -c 'echo "" > /etc/resolv.conf' 2>/dev/null
  if [ ! -z "$GET_GATEWAY" ]; then
    sudo su -c "echo 'nameserver $GET_GATEWAY' >> /etc/resolv.conf" 2>/dev/null
  fi
  sudo su -c 'echo "nameserver 1.1.1.1" >> /etc/resolv.conf' 2>/dev/null
  sudo su -c 'echo "nameserver 1.0.0.1" >> /etc/resolv.conf' 2>/dev/null
  sudo su -c 'echo "nameserver 8.8.8.8" >> /etc/resolv.conf' 2>/dev/null
  sudo su -c 'echo "nameserver 8.8.4.4" >> /etc/resolv.conf' 2>/dev/null
  # China
  sudo su -c 'echo "nameserver 114.114.114.114" >> /etc/resolv.conf' 2>/dev/null
  sudo su -c 'echo "nameserver 114.114.115.115" >> /etc/resolv.conf' 2>/dev/null
  # IPV6
  sudo su -c 'echo nameserver 2606:4700:4700::1111 >> /etc/resolv.conf' 2>/dev/null
  sudo su -c 'echo nameserver 2606:4700:4700::1001 >> /etc/resolv.conf' 2>/dev/null
  sudo systemd-resolve --flush-caches

  sleep 1

  while ! sudo ping minerstat.com. -w 1 | grep "0%"; do
    sudo service network-manager restart
    sudo /usr/sbin/netplan apply
    break
  done

  echo "-------- WAITING FOR CONNECTION -----------------"
  echo ""

  echo "Waiting for DNS resolve.."
  echo "It can take a few moments! You may see ping messages for a while"
  echo ""

  nslookup api.minerstat.com

  echo ""

  while ! sudo ping minerstat.com. -w 1 | grep "0%"; do
    sudo /home/minerstat/minerstat-os/core/dnser
    sleep 3
  done

  echo ""
  echo "-------- AUTO UPDATE MINERSTAT ------------------"
  echo ""
  cd /home/minerstat/minerstat-os
  sudo sh git.sh
  echo ""

  echo "-------- RUNNING JOBS ---------------------------"
  cd /home/minerstat/minerstat-os/bin
  sudo sh jobs.sh
  echo ""

  cd /home/minerstat/minerstat-os/core
  sudo sh expand.sh

  CHECKAPT=$(dpkg -l | grep libnetpacket-perl | wc -l)

  if [ ! "$CHECKAPT" -gt "0" ]; then
    sudo apt --yes --force-yes --fix-broken install
    sudo apt-get --yes --force-yes install libnetpacket-perl  libnet-pcap-perl libnet-rawip-perl
  fi

  #########################
  # <IF EXPERIMENTAL
  if grep -q experimental "/etc/lsb-release"; then

    AMDDEVICE=$(timeout 40 sudo lspci -k | grep VGA | grep -vE "Kaveri|Beavercreek|Sumo|Wrestler|Kabini|Mullins|Temash|Trinity|Richland|Stoney|Carrizo|Raven|Renoir|Picasso|Van" | grep -c "AMD")
    if [ -z "$AMDDEVICE" ]; then
      AMDDEVICE=$(timeout 3 sudo lshw -C display | grep AMD | wc -l)
    fi
    if [ -z "$AMDDEVICE" ]; then
      AMDDEVICE=$(timeout 3 sudo lshw -C display | grep driver=amdgpu | wc -l)
    fi
    if [ "$AMDDEVICE" -gt 0 ]; then
      echo "INFO: Seems you have AMD Device enabled, activating OpenCL Support."
      echo "INFO: Nvidia / AMD Mixing not supported. If you want to use OS on another rig, do mrecovery."
      sudo apt-get --yes --force-yes install libegl1-amdgpu-pro:amd64 libegl1-amdgpu-pro:i386
    fi

    # Solve AMDGPU XORG bug
    NVIDIA="$(nvidia-smi -L)"
    if [ ! -z "$NVIDIA" ]; then
      if echo "$NVIDIA" | grep -iq "^GPU 0:" ;then
        # Solves NVIDIA-SETTINGS OC ISSUE
        # amdgpu_device_initialize: amdgpu_get_auth (1) failed (-1)
        sudo apt --yes --force-yes --fix-broken install
        sudo apt-get --yes --force-yes install cuda-libraries-10-0 cuda-cudart-10-0
        sudo apt-get --yes --force-yes install libcurl4
        sudo dpkg --remove --force-all libegl1-amdgpu-pro:i386 libegl1-amdgpu-pro:amd64
        # To enable back AMD-OpenCL
        # sudo apt-get install libegl1-amdgpu-pro:amd64 libegl1-amdgpu-pro:i386
      fi
    fi

  fi
  # />
  #########################

  echo ""
  echo "-------- INSTALLING FAKE DUMMY PLUG ------------"
  echo "Please wait.."
  sleep 1
  #sudo update-grub
  #sudo nvidia-xconfig -a --allow-empty-initial-configuration --cool-bits=28 --use-display-device="DFP-0" --connected-monitor="DFP-0" --enable-all-gpus
  sudo nvidia-xconfig -a --allow-empty-initial-configuration --cool-bits=31 --use-display-device="DFP-0" --connected-monitor="DFP-0" &
  sudo sed -i s/"DPMS"/"NODPMS"/ /etc/X11/xorg.conf
  sudo service gdm stop >/dev/null
  #screen -A -m -d -S display sudo X
  sleep 5

  sudo chvt 1

  echo ""


  echo "-------- REBOOT IN 3 SEC -----------"
  sleep 2
  sudo reboot -f
fi
