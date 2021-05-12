#!/bin/bash
exec 2>/dev/null
echo "*-*-* Overclocking in progress *-*-*"

#NVIDIADEVICE=$(timeout 5 sudo lspci -k | grep VGA | grep -vE "Kaveri|Beavercreek|Sumo|Wrestler|Kabini|Mullins|Temash|Trinity|Richland|Stoney|Carrizo|Raven|Renoir|Picasso|Van" | grep -c "NVIDIA")
#if [ "$NVIDIADEVICE" = "0" ]; then
NVIDIADEVICE=$(timeout 40 sudo lshw -C display | grep "driver=nvidia" | wc -l)
#fi
if [ "$NVIDIADEVICE" = "0" ]; then
  NVIDIADEVICE=$(timeout 40 sudo lshw -C display | grep NVIDIA | wc -l)
fi
NVIDIA="$(nvidia-smi -L)"

if [ "$NVIDIADEVICE" != "0" ]; then
  #if echo "$NVIDIA" | grep -iq "^GPU 0:" ;then
  DONVIDIA="YES"
  # Check XSERVER
  XORG=$(timeout 5 nvidia-smi | grep -c Xorg)
  SNUM=$(sudo su minerstat -c "screen -list | grep -c display2")
  # pm
  timeout 5 sudo nvidia-smi -pm 1
  # reset gpu clocks to clear locked clocks
  timeout 5 sudo nvidia-smi -rgc > /dev/null 2>&1
  # force compute mode where available
  #timeout 5 sudo nvidia-smi --gom=COMPUTE &> /dev/null
  # Unknown Error
  FANMAX=$(cat /media/storage/fans.txt 2>/dev/null | grep "FANMAX=" | xargs | sed 's/[^0-9]*//g')
  if [ -z "$FANMAX" ]; then
    FANMAX=70
  fi
  timeout 10 sudo rm /dev/shm/nverr.txt &> /dev/null
  CHECK_ERR=$(timeout 10 sudo nvidia-settings --verbose -c :0 -a GPUFanControlState=1 -a GPUTargetFanSpeed="$FANMAX" &> /dev/shm/nverr.txt)
  CHECK_ERR=$(cat /dev/shm/nverr.txt | grep -c "Unknown Error")
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
    echo "Initalizing.. waiting for full Xorg start"
    sleep 20
  fi
  #fi
fi

INSTANT=$1

FORCE="no"

TOKEN="$(cat /media/storage/config.js | grep 'global.accesskey' | sed 's/global.accesskey =//g' | sed 's/;//g' | sed 's/ //g' | sed 's/"//g' | sed 's/\\r//g' | sed 's/[^a-zA-Z0-9]*//g')"
WORKER="$(cat /media/storage/config.js | grep 'global.worker' | sed 's/global.worker =//g' | sed 's/;//g' | sed 's/ //g' | sed 's/"//g' | sed 's/\\r//g')"

AMDDEVICE=$(timeout 5 sudo lspci -k | grep VGA | grep -vE "Kaveri|Beavercreek|Sumo|Wrestler|Kabini|Mullins|Temash|Trinity|Richland|Stoney|Carrizo|Raven|Renoir|Picasso|Van" | grep -c "AMD")
if [ -z "$AMDDEVICE" ]; then
  AMDDEVICE=$(timeout 3 sudo lshw -C display | grep AMD | wc -l)
fi
if [ -z "$AMDDEVICE" ]; then
  AMDDEVICE=$(timeout 3 sudo lshw -C display | grep driver=amdgpu | wc -l)
fi

if [ "$AMDDEVICE" -gt "0" ]; then
  DOAMD="YES"
fi

#echo "FOUND AMD: $AMDDEVICE || FOUND NVIDIA: $NVIDIADEVICE"
echo ""
echo ""
echo "--------------------------"

TOKEN="$(cat /home/minerstat/minerstat-os/config.js | grep 'global.accesskey' | sed 's/global.accesskey =//g' | sed 's/;//g')"
WORKER="$(cat /home/minerstat/minerstat-os/config.js | grep 'global.worker' | sed 's/global.worker =//g' | sed 's/;//g')"

echo "TOKEN: $TOKEN"
echo "WORKER: $WORKER"

echo "--------------------------"

sudo rm doclock.sh > /dev/null
sudo rm /dev/shm/nvid_cache.txt > /dev/null
sleep 1

if [ ! -z "$DONVIDIA" ]; then
  #sudo nvidia-smi -pm 1
  sudo killall memdelay > /dev/null 2>&1
  sudo rm /dev/shm/nv_memcache.txt > /dev/null 2>&1
  sudo rm /dev/shm/nv_lockcache.txt > /dev/null 2>&1
  sudo rm /dev/shm/nv_clkcache.txt > /dev/null 2>&1

  sudo wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 5 -o /dev/null -qO doclock.sh "https://api.minerstat.com/v2/getclock.php?type=nvidia&token=$TOKEN&worker=$WORKER&nums=$NVIDIADEVICE&instant=$INSTANT"
  sleep 3
  sudo bash doclock.sh

  if [ -f "/dev/shm/nv_clkcache.txt" ]; then
    DISPLAY=:0
    export DISPLAY=:0
    STR=$(sudo cat /dev/shm/nv_clkcache.txt | tr -d '\r\n' | xargs)
    echo "DISPLAY=:0 nvidia-settings --verbose -c :0 $STR"
    sudo su minerstat -c "DISPLAY=:0 nvidia-settings --verbose -c :0 $STR"
    sleep 1
    sudo chvt 1
  fi

  QUERYNVIDIA=$(sudo /home/minerstat/minerstat-os/bin/gpuinfo nvidia)
  # NVIDIA DRIVER CRASH WATCHDOG
  TESTVIDIA=$(sudo nvidia-smi --query-gpu=count --format=csv,noheader | grep "lost")
  RAMLOG=$(cat /dev/shm/miner.log | tac | head --lines 10 | tac)
  RAMLOG="$RAMLOG $TESTVIDIA"
  sudo curl --insecure --connect-timeout 15 --max-time 25 --retry 0 --header "Content-type: application/x-www-form-urlencoded" --request POST --data "htoken=$TOKEN" --data "hworker=$WORKER" --data "hwType=nvidia" --data "hwData=$QUERYNVIDIA" --data "mineLog=$RAMLOG" "https://api.minerstat.com:2053/v2/set_node_config_os.php"

  sudo screen -A -m -d -S fan sudo bash /home/minerstat/minerstat-os/bin/setfans.sh delay

  sync

  # NO IDEA, BUT THIS SOLVE P8 STATE ISSUES (ON ALL CARD!)
  sudo screen -A -m -d -S p8issue sudo bash /home/minerstat/minerstat-os/bin/p8issue.sh
  sleep 0.5

  sudo chvt 1
fi

if [ ! -z "$DOAMD" ]; then

  # PCI ID DB Update
  # Cache this and update every few months
  # timeout 15 sudo update-pciids &

  echo "#!/bin/bash" > /home/minerstat/clock_cache

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
  sudo curl --header "Content-type: application/x-www-form-urlencoded" --request POST --data "htoken=$TOKEN" --data "hworker=$WORKER" --data "hwMemory=$HWMEMORY" "https://api.minerstat.com/v2/set_node_config_os.php"

  START_ID="$(sudo ./amdcovc | grep "Adapter" | cut -f1 -d':' | sed '1q' | sed 's/[^0-9]//g')"
  # First AMD GPU ID. 0 OR 1 Usually
  STARTS=$START_ID

  #FILE="/sys/class/drm/card0/device/pp_dpm_sclk"
  #if [ -f "$FILE" ]
  #then
  #	STARTS=0
  #else
  #	STARTS=1
  #fi


  echo "STARTS WITH ID: $STARTS"

  i=0
  SKIP=""
  while [ $i -le $AMDDEVICE ]; do
    if [ "$i" -lt "10" ]; then
      if [ -f "/sys/class/drm/card$i/device/pp_table" ]
      then
        SKIP=$SKIP
      else
        SKIP=$SKIP"-$i"
      fi
    fi
    i=$(($i+1))
  done

  if [ "$SKIP" != "" ]
  then
    echo "Integrated Graphics ID: "$SKIP
  fi

  sudo rm /media/storage/fans.txt > /dev/null
  sudo killall curve > /dev/null

  #isThisVega=$(sudo /home/minerstat/minerstat-os/bin/amdcovc | grep "PCI $GID" | grep "Vega" | sed 's/^.*Vega/Vega/' | sed 's/[^a-zA-Z]*//g')
  #isThisVegaII=$(sudo /home/minerstat/minerstat-os/bin/amdcovc | grep "PCI $GID" | grep "Vega" | sed 's/^.*Vega/Vega/' | sed 's/[^a-zA-Z]*//g')

  #sudo su minerstat -c "screen -X -S minerstat-console quit";
  #sudo su -c "sudo screen -X -S minew quit";
  #sudo su -c "echo "" > /dev/shm/miner.log";

  #if [ "$isThisVega" = "Vega" ] || [ "$isThisVegaII" = "VegaFrontierEdition" ]; then
  #sudo /home/minerstat/minerstat-os/core/autotune
  #fi

  sudo wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 5 -o /dev/null -qO doclock.sh "https://api.minerstat.com/v2/getclock.php?type=amd&token=$TOKEN&worker=$WORKER&nums=$AMDDEVICE&instant=$INSTANT&starts=$STARTS"

  sleep 1.5
  sudo bash doclock.sh

  ###################
  AMDINFO=$(sudo /home/minerstat/minerstat-os/bin/gpuinfo amd2)
  QUERYPOWER=$(cd /home/minerstat/minerstat-os/bin/; sudo ./rocm-smi -P | grep 'Average Graphics Package Power:' | sed 's/.*://' | sed 's/W/''/g' | xargs)
  HWMEMORY=$(cd /home/minerstat/minerstat-os/bin/; cat amdmeminfo.txt)
  sudo chmod 777 /dev/shm/amdmeminfo.txt
  if [ ! -f "/dev/shm/amdmeminfo.txt" ]; then
    sudo /home/minerstat/minerstat-os/bin/amdmeminfo -s -q > /dev/shm/amdmeminfo.txt &
    sudo cp -rf /dev/shm/amdmeminfo.txt /home/minerstat/minerstat-os/bin
    sudo chmod 777 /home/minerstat/minerstat-os/bin/amdmeminfo.txt
    HWMEMORY=$(sudo cat /dev/shm/amdmeminfo.txt)
  fi
  if [ -z "$HWMEMORY" ] || [ -f "/dev/shm/amdmeminfo.txt" ]; then
    HWMEMORY=$(sudo cat /dev/shm/amdmeminfo.txt)
  fi
  if [ -z "$AMDINFO" ]; then
    AMDINFO=$(sudo /home/minerstat/minerstat-os/bin/amdcovc)
  fi
  HWSTRAPS=$(cd /home/minerstat/minerstat-os/bin/; sudo ./"$STRAPFILENAME" --current-minerstat)
  echo -e "\033[1;34m==\033[0m Applying AMD Memory Tweak ...\033[0m"

  sudo curl --insecure --connect-timeout 15 --max-time 25 --retry 1 --header "Content-type: application/x-www-form-urlencoded" --request POST --data "htoken=$TOKEN" --data "hworker=$WORKER" --data "hwType=amd" --data "hwData=$AMDINFO" --data "hwPower=$QUERYPOWER" --data "hwMemory=$HWMEMORY" --data "hwStrap=$HWSTRAPS" --data "mineLog=$RAMLOG" "https://api.minerstat.com:2053/v2/set_node_config_os2.php"
  sudo screen -A -m -d -S delaymem bash /home/minerstat/minerstat-os/bin/setmem.sh
  sudo screen -A -m -d -S fan sudo bash /home/minerstat/minerstat-os/bin/setfans.sh delay

  sync
  sudo chvt 1
fi
