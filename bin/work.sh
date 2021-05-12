#!/bin/bash
#exec 2>/dev/null

if ! screen -list | grep -q "dummy"; then
  screen -A -m -d -S dummy sleep 22176000

  # Stop before OC
  sudo su -c "echo 'stopboot' > /tmp/stop.pid"
  echo "stop" > /tmp/justbooted.pid;
  screen -A -m -d -S just sudo bash /home/minerstat/minerstat-os/core/justboot

  screen -S listener -X quit > /dev/null # kill running process
  screen -A -m -d -S listener sudo bash /home/minerstat/minerstat-os/core/init.sh

  TESTLOGIN=$(timeout 2 systemctl list-jobs)
  if [ "$TESTLOGIN" != "No jobs running." ]; then
    sudo systemctl restart systemd-logind.service &
  fi

  # validate OC
  screen -A -m -d -S checkclock sudo bash /home/minerstat/minerstat-os/core/checkclock

  # FIX CTRL + ALT + F1
  #sudo systemctl start nvidia-persistenced > /dev/null &
  screen -A -m -d -S chvt sudo /home/minerstat/minerstat-os/bin/chvta

  NVIDIA="$(nvidia-smi -L)"
  AMDDEVICE=$(lsmod | grep amdgpu | wc -l)
  NVIDIADEVICE=$(lsmod | grep nvidia | wc -l)

  echo -e "\033[1;34m==\033[0m Configuring network adapters ...\033[0m"
  SSID=$(cat /media/storage/network.txt | grep 'WIFISSID="' | sed 's/WIFISSID="//g' | sed 's/"//g' | xargs | wc -L)
  DHCP=$(cat /media/storage/network.txt | grep "DHCP=" | sed 's/DHCP=//g' | sed 's/"//g')

  echo -e "\033[1;34m==\033[0m Waiting for connection ...\033[0m"

  sleep 1
  HAVECONNECTION="true"
  ping -c1 1.1.1.1 -w 1 &>/dev/null && HAVECONNECTION="true" || HAVECONNECTION="false"
  if [ "$HAVECONNECTION" = "false" ]; then
    if [ "$SSID" -gt 0 ]; then
      cd /home/minerstat/minerstat-os/core
      sudo bash wifi.sh

    else

      if [ "$DHCP" != "NO" ]; then
        cd /home/minerstat/minerstat-os/bin
        sudo bash /home/minerstat/minerstat-os/core/dhcp
        #sudo dhclient -v -r
      else
        cd /home/minerstat/minerstat-os/bin
        sudo bash static.sh
      fi
    fi
  fi

  # Cache management
  ping -c1 104.24.98.231 -w 1 &>/dev/null && HAVECONNECTION="true" || HAVECONNECTION="false"
  if [ "$HAVECONNECTION" = "false" ]; then
    sudo timeout 10 service network-manager restart
    sudo timeout 10 /usr/sbin/netplan apply
    sudo timeout 10 /home/minerstat/minerstat-os/core/dnser
    sleep 2
  fi

  ping -c1 api.minerstat.com -w 1 &>/dev/null && HAVECONNECTION="true" || HAVECONNECTION="false"
  if [ "$HAVECONNECTION" = "false" ]; then
    sudo timeout 10 /home/minerstat/minerstat-os/core/dnser
    sleep 2
  fi

  echo -e "\033[1;34m==\033[0m Updating the system ...\033[0m"

  #sudo update-pciids
  cd /home/minerstat/minerstat-os
  sudo bash git.sh

  sudo chmod -R 777 /home/minerstat/minerstat-os/*

  #echo "Moving MSOS config.js to / (LINUX)"
  sudo cp -rf "/media/storage/config.js" "/home/minerstat/minerstat-os/"

  sleep 0.2
  #sudo service dgm stop > /dev/null &
  sudo chvt 1

  echo -e "\033[1;34m==\033[0m Overclocking ...\033[0m"
  cd /home/minerstat/minerstat-os/
  sudo node stop > /dev/null
  sudo su minerstat -c "screen -X -S minerstat-console quit" > /dev/null
  sudo su -c "echo 'stop' > /tmp/stop.pid"
  sudo su -c "sudo screen -X -S minew quit" > /dev/null
  cd /home/minerstat/minerstat-os/bin

  TOKEN="$(cat /media/storage/config.js | grep 'global.accesskey' | sed 's/global.accesskey =//g' | sed 's/;//g' | sed 's/ //g' | sed 's/"//g' | sed 's/\\r//g' | sed 's/[^a-zA-Z0-9]*//g')"
  WORKER="$(cat /media/storage/config.js | grep 'global.worker' | sed 's/global.worker =//g' | sed 's/;//g' | sed 's/ //g' | sed 's/"//g' | sed 's/\\r//g')"

  # Remove pending commands
  timeout 5 wget -o /dev/null -qO- --timeout=10 "https://api.minerstat.com/v2/set_node_config.php?token=$TOKEN&worker=$WORKER" &>/dev/null &

  # PCI_BUS_ID
  if [ "$AMDDEVICE" -gt 0 ]; then

    HWMEMORY=$(cd /home/minerstat/minerstat-os/bin/; cat amdmeminfo.txt)
    if [ -z "$HWMEMORY" ] || [ -f "/dev/shm/amdmeminfo.txt" ]; then
      HWMEMORY=$(sudo cat /dev/shm/amdmeminfo.txt)
    fi
    sudo chmod 777 /dev/shm/amdmeminfo.txt
    if [ ! -f "/dev/shm/amdmeminfo.txt" ]; then
      timeout 30 sudo /home/minerstat/minerstat-os/bin/amdmeminfo -s -q > /dev/shm/amdmeminfo.txt &
      sudo cp -rf /dev/shm/amdmeminfo.txt /home/minerstat/minerstat-os/bin
      sudo chmod 777 /home/minerstat/minerstat-os/bin/amdmeminfo.txt
      # fix issue with meminfo file
      RBC=$(cat /dev/shm/amdmeminfo.txt)
      if [[ $RBC == *"libamdocl"* ]]; then
        sed -i '/libamdocl/d' /dev/shm/amdmeminfo.txt
      fi
      HWMEMORY=$(sudo cat /dev/shm/amdmeminfo.txt)
    fi
    timeout 20 sudo curl --header "Content-type: application/x-www-form-urlencoded" --request POST --data "htoken=$TOKEN" --data "hworker=$WORKER" --data "hwMemory=$HWMEMORY" "https://api.minerstat.com/v2/set_node_config_os.php"
  fi

  # MCLOCK
  echo -e "\033[1;34m==\033[0m Adjusting clocks in the background ...\033[0m"
  #sudo chvt 1
  sudo bash /home/minerstat/minerstat-os/bin/overclock.sh

  #
  #if [ "$AMDDEVICE" -gt 0 ]; then
  #  echo -e "\033[1;34m==\033[0m Applying AMD Memory Tweak ...\033[0m"
  #  sudo screen -A -m -d -S delaymem bash /home/minerstat/minerstat-os/bin/setmem.sh
  #fi

  echo -e "\033[1;34m==\033[0m Starting miner ...\033[0m"
  cd /home/minerstat/minerstat-os
  sudo su -c "sudo screen -X -S minew quit" > /dev/null
  sudo su -c "sudo screen -X -S fakescreen quit" > /dev/null
  sudo su -c "screen -ls minew | grep -E '\s+[0-9]+\.' | awk -F ' ' '{print $1}' | while read s; do screen -XS $s quit; done" > /dev/null
  sudo su minerstat -c "screen -X -S fakescreen quit" > /dev/null
  screen -ls minerstat-console | grep -E '\s+[0-9]+\.' | awk -F ' ' '{print $1}' | while read s; do screen -XS $s quit; done
  sudo su minerstat -c "screen -ls minerstat-console | grep -E '\s+[0-9]+\.' | awk -F ' ' '{print $1}' | while read s; do screen -XS $s quit; done"
  sudo su minerstat -c "screen -A -m -d -S fakescreen sh /home/minerstat/minerstat-os/bin/fakescreen.sh"
  sudo su -c "sudo rm /tmp/stop.pid"
  sleep 2
  sudo su minerstat -c "screen -A -m -d -S minerstat-console sudo /home/minerstat/minerstat-os/launcher.sh"

  echo
  echo -e "\033[1;34m==\033[0m Boot process finished ...\033[0m"
  echo

  sudo screen -A -m -d -S finish sudo /home/minerstat/minerstat-os/bin/postboot.sh $AMDDEVICE $NVIDIA

  sudo bash /home/minerstat/minerstat-os/bin/help.sh short
  sudo bash /home/minerstat/minerstat-os/core/gputable

  echo "You may need to Press Ctrl + C to enter commands."

  exec bash &
  source /home/minerstat/minerstat-os/core/.bashrc &

  echo
  echo

fi
