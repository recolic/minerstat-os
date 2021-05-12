#!/bin/bash
exec 2>/dev/null

echo "---- FIND MY GPU ----"
echo ""

#################################£
# Check minerstat is running or not
RESULT=$(sudo su minerstat -c "screen -list | grep 'console' | wc -l")
echo "[] Instance Check: $RESULT"
#RESULT=`pgrep node`

if [ ! $1 ]; then
  echo "Type your GPU ID what you want to find."
  echo "NVIDIA Example: mfind 0"
  echo "If you are looking Nvidia by BUS id. Check on Worker Page on my.minerstat.com and search by standard ID. for GPU0 use mfind 0"
  echo "AMD Example with ID Search: mfind 3"
  echo "AMD Example with BUS Search: mfind 03.00.0"
else
  #if [ "${RESULT:-null}" = null ]; then
  if [ "$RESULT" = "0" ]; then
    #################################£
    # Detect GPU's
    AMDDEVICE=$(timeout 40 sudo lspci -k | grep VGA | grep -vE "Kaveri|Beavercreek|Sumo|Wrestler|Kabini|Mullins|Temash|Trinity|Richland|Stoney|Carrizo|Raven|Renoir|Picasso|Van" | grep -c "AMD")
    if [ -z "$AMDDEVICE" ]; then
      AMDDEVICE=$(timeout 3 sudo lshw -C display | grep AMD | wc -l)
    fi
    if [ -z "$AMDDEVICE" ]; then
      AMDDEVICE=$(timeout 3 sudo lshw -C display | grep driver=amdgpu | wc -l)
    fi
    #NVIDIADEVICE=$(timeout 5 sudo lspci -k | grep VGA | grep -vE "Kaveri|Beavercreek|Sumo|Wrestler|Kabini|Mullins|Temash|Trinity|Richland|Stoney|Carrizo|Raven|Renoir|Picasso|Van" | grep -c "NVIDIA")
    #if [ "$NVIDIADEVICE" = "0" ]; then
    NVIDIADEVICE=$(timeout 40 sudo lshw -C display | grep "driver=nvidia" | wc -l)
    #fi
    if [ "$NVIDIADEVICE" = "0" ]; then
      NVIDIADEVICE=$(timeout 3 sudo lshw -C display | grep NVIDIA | wc -l)
    fi
    NVIDIA="$(nvidia-smi -L)"
    GID=$1
    echo ""
    sudo killall curve

    if [ ! -z "$NVIDIA" ]; then
      if echo "$NVIDIA" | grep -iq "^GPU 0:" ;then
        echo "NVIDIA: SET ALL FANS TO 0%"
        STR1="-c :0 -a GPUFanControlState=1 -a GPUTargetFanSpeed=0"
        FINISH="$(sudo nvidia-settings $STR1)"
        echo $FINISH
        echo ""
        echo "-- NVIDIA --"
        echo "DONE, WAIT 10 SEC."
        sleep 10
        echo ""
        echo "-- NVIDIA --"
        echo "GPU $GID >> 100%"
        #STR2="-c :0 -a [gpu:$GID]/GPUFanControlState=1 -a [gpu:$GID]/GPUTargetFanSpeed=100"
        sudo /home/minerstat/minerstat-os/core/nv_fanid $GID
        ID1=$(cat /dev/shm/id1.txt | xargs)
        ID2=$(cat /dev/shm/id2.txt | xargs)

        FANSPEED=100

        if [ -z "$ID1" ] && [ -z "$ID2" ]; then
          echo "Using global fan ID method."
          STR2="-c :0 -a [gpu:"$GID"]/GPUFanControlState=1 -a [fan:"$GID"]/GPUTargetFanSpeed="$FANSPEED""
        else
          echo "Using separate fan ID method."
          STR2="-c :0 -a [gpu:"$GID"]/GPUFanControlState=1 -a [fan:"$ID1"]/GPUTargetFanSpeed="$FANSPEED""
          if [ ! -z "$ID2" ]; then
            STR2="$STR2 -a [gpu:"$GID"]/GPUFanControlState=1 -a [fan:"$ID2"]/GPUTargetFanSpeed="$FANSPEED""
          fi
        fi
        echo "sudo nvidia-settings $STR2"
        APPLY="$(sudo nvidia-settings $STR2)"
        echo $APPLY
        echo ""
        echo "-- NVIDIA --"
        echo "DONE, WAIT 30 SEC."
        echo "Check which GPU spinning fans at the moment. That should be GPU $GID"
        sleep 30
        echo ""
        echo "--- Loading original settings --"
        cd /home/minerstat/minerstat-os/bin
        sudo bash setfans.sh
      fi
    fi

    if [ "$AMDDEVICE" -gt "0" ]; then
      echo ""
      echo "-- STATUS --"
      echo "AMD: SET ALL FANS TO 0%"
      sudo /home/minerstat/minerstat-os/bin/gpuinfo amd
      echo ""
      if [ ${#GID} -ge 3 ]; then
        echo "-- VALIDATE ON BUS --"
        GPUBUSINT=$(echo $GID | cut -f 1 -d '.')
        GPUBUS=$(python -c 'print(int("'$GPUBUSINT'", 16))')
        echo "Bus ID: $GID"
        GID=$(ls /sys/bus/pci/devices/*$GPUBUSINT":00.0"/drm | grep "card" | sed 's/[^0-9]*//g')
        echo "Rechecked ID: $GID"
      fi
      sudo /home/minerstat/minerstat-os/bin/rocm-smi --setfan 0
      echo ""
      echo "-- AMD --"
      echo "DONE, WAIT 10 SEC."
      sleep 10
      echo ""
      echo "-- AMD --"
      echo "GPU $GID >> 200 RPM"
      sudo /home/minerstat/minerstat-os/bin/rocm-smi --setfan 200 -d $GID
      echo ""
      echo "-- AMD --"
      echo "DONE, WAIT 30 SEC."
      echo "Check which GPU spinning fans at the moment. That should be GPU $GID"
      sleep 30
      echo ""
      echo "--- Loading original settings --"
      cd /home/minerstat/minerstat-os/bin
      sudo sh setfans.sh
    fi

  else

    echo "-----"
    echo "You need to stop running miner before you can use this script."
    echo "Type: mstop"
    echo "Then you are able to run again"
    echo ""
    echo "Type your GPU ID what you want to find."
    echo "NVIDIA Example: mfind 0"
    echo "If you are looking Nvidia by BUS id. Check on Worker Page on my.minerstat.com and search by standard ID. for GPU0 use mfind 0"
    echo "AMD Example with ID Search: mfind 3"
    echo "AMD Example with BUS Search: mfind 03.00.0"
    echo "-----"
  fi

fi
