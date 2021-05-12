#!/bin/bash
#exec 2>/dev/null

if [ ! $1 ]; then
  echo ""
  echo "--- EXAMPLE ---"
  echo "./overclock_nvidia_all.sh 1 2 3 4"
  echo "1 = POWER LIMIT in Watts (Example: 120 = 120W) [ROOT REQUIRED]"
  echo "2 = GLOBAL FAN SPEED (100 = 100%)"
  echo "3 = Memory Offset"
  echo "4 = Core Offset"
  echo "5 = Core Clock Lock"
  echo ""
  echo "-- Full Example --"
  echo "./overclock_nvidia_all.sh 0 120 80 1300 100 1600"
  echo ""
fi

if [ $1 ]; then
  POWERLIMITINWATT=$1
  FANSPEED=$2
  MEMORYOFFSET=$3
  COREOFFSET=$4
  # INSTANT
  INSTANT=$5
  # Lock core clock
  CORELOCK=$6

  ## BULIDING QUERIES
  STR1=""
  STR2=""
  STR3=""
  STR4="-c :0"

  if [ "$INSTANT" = "instant" ]; then
    echo "INSTANT OVERRIDE"
    echo "GPU ID => ALL"
    if [ -f "/dev/shm/oc_old_all.txt" ]; then
      echo
      echo "=== COMPARE VALUE FOUND ==="
      sudo cat /dev/shm/oc_old_all.txt
      MEMORYOFFSET_OLD=$(cat /dev/shm/oc_old_all.txt | grep "MEMCLOCK=" | xargs | sed 's/.*=//' | xargs)
      COREOFFSET_OLD=$(cat /dev/shm/oc_old_all.txt | grep "CORECLOCK=" | xargs | sed 's/.*=//' | xargs)
      FANSPEED_OLD=$(cat /dev/shm/oc_old_all.txt | grep "FAN=" | xargs | sed 's/.*=//' | xargs)
      POWERLIMITINWATT_OLD=$(cat /dev/shm/oc_old_all.txt | grep "POWERLIMIT=" | xargs | sed 's/.*=//' | xargs)
      echo "==========="
      echo
    fi
    if [ ! -f "/dev/shm/oc_old_all.txt" ]; then
      echo "=== COMPARE VALUE NOT FOUND ==="
      echo "USING SKIP EVERYWHERE"
      MEMORYOFFSET_OLD="skip"
      COREOFFSET_OLD="skip"
      FANSPEED_OLD="skip"
      POWERLIMITINWATT_OLD="skip"
      echo "==========="
    fi
    echo "=== NEW VALUES FOUND ==="
    sudo cat /dev/shm/oc_all.txt
    MEMORYOFFSET_NEW=$(cat /dev/shm/oc_all.txt | grep "MEMCLOCK=" | xargs | sed 's/.*=//' | xargs)
    COREOFFSET_NEW=$(cat /dev/shm/oc_all.txt | grep "CORECLOCK=" | xargs | sed 's/.*=//' | xargs)
    FANSPEED_NEW=$(cat /dev/shm/oc_all.txt | grep "FAN=" | xargs | sed 's/.*=//' | xargs)
    POWERLIMITINWATT_NEW=$(cat /dev/shm/oc_all.txt | grep "POWERLIMIT=" | xargs | sed 's/.*=//' | xargs)
    echo "==========="
    echo
    echo "=== COMPARE ==="
    ##################
    MEMORYOFFSET="skip"
    COREOFFSET="skip"
    FANSPEED="skip"
    POWERLIMITINWATT="skip"
    ##################
    if [ "$MEMORYOFFSET_OLD" != "$MEMORYOFFSET_NEW" ]; then
      MEMORYOFFSET=$MEMORYOFFSET_NEW
    fi
    if [ "$COREOFFSET_OLD" != "$COREOFFSET_NEW" ]; then
      COREOFFSET=$COREOFFSET_NEW
    fi
    if [ "$FANSPEED_OLD" != "$FANSPEED_NEW" ]; then
      FANSPEED=$FANSPEED_NEW
    fi
    if [ "$POWERLIMITINWATT_OLD" != "$POWERLIMITINWATT_NEW" ]; then
      POWERLIMITINWATT=$POWERLIMITINWATT_NEW
    fi
  fi

  # DETECTING VIDEO CARD FOR PERFORMACE LEVEL

  QUERY="$(sudo nvidia-smi -i 0 --query-gpu=name --format=csv,noheader | tail -n1)"

  echo "--- GPU $GPUID: $QUERY ---";

  # DEFAULT IS 3 some card requires only different
  # This is obsolete method, just adding in case older driver versions
  # Since 400 series drivers, defining performance levels opciional
  PLEVEL=3

  if echo "$QUERY" | grep "1050" ;then PLEVEL=2
  elif echo "$QUERY" | grep "P106-100" ;then PLEVEL=2
  elif echo "$QUERY" | grep "GTX 9" ;then PLEVEL=2
  elif echo "$QUERY" | grep "P102-100" ;then PLEVEL=1
  elif echo "$QUERY" | grep "P104-100" ;then PLEVEL=1
  elif echo "$QUERY" | grep "P106-090" ;then PLEVEL=1
  elif echo "$QUERY" | grep "1660 SUPER" ;then PLEVEL=4
  elif echo "$QUERY" | grep "1650 SUPER" ;then PLEVEL=4
  elif echo "$QUERY" | grep "1660 Ti" ;then PLEVEL=4
  elif echo "$QUERY" | grep "RTX" ;then PLEVEL=4
  elif echo "$QUERY" | grep "1660" ;then PLEVEL=2
  elif echo "$QUERY" | grep "1650" ;then PLEVEL=2
  elif echo "$QUERY" | grep "CMP 30HX" ;then PLEVEL=2
  fi

  E1=""
  E2=""
  if [[ $QUERY == *"3070"* ]] || [[ $QUERY == *"3080"* ]] || [[ $QUERY == *"3090"* ]] || [[ $QUERY == *"3060"* ]]; then
    # GDDR6 fix
    MHZ=$((MEMORYOFFSET/2))
    EFF_MHZ=$(awk -v n=$MHZ 'BEGIN{print int((n+5)/10) * 10}')
    if [[ $MEMORYOFFSET -gt $EFF_MHZ ]]; then
      echo "Adjustment applied for memory clock"
      echo "Old memory offset $MEMORYOFFSET Mhz"
      MEMORYOFFSET=$((EFF_MHZ*2))
      echo "New memory offset $MEMORYOFFSET Mhz"
    fi

    # for instant OC just apply memclock without delay
    if [[ "$INSTANT" != "instant" ]]; then

      # DAG DELAY
      # SET MEMCLOCK BACK AFTER MINER STARTED 40 sec
      sudo echo "ALL:$MEMORYOFFSET" >> /dev/shm/nv_memcache.txt

      echo "!!!!!!!!"
      echo "GPU #ALL: $MEMORYOFFSET Mhz Memory Clock will be applied after miner started and DAG generated (40 sec)"
      echo "!!!!!!!"

      # DAG PROTECTION
      MEMORYOFFSET=0
      #COREOFFSET=0

      TEST=$(sudo screen -list | grep -wc memdelay)
      if [ "$TEST" = "0" ]; then
        sudo screen -A -m -d -S memdelay sudo bash /home/minerstat/minerstat-os/core/memdelay &
      fi

    fi

    # P2
    E1="-a GPUMemoryTransferRateOffset[2]="$MEMORYOFFSET""
    E2="-a GPUGraphicsClockOffset[2]="$COREOFFSET""
  fi


  echo "--- PERFORMANCE LEVEL: $PLEVEL ---";

  #################################£
  # POWER LIMIT

  if [[ "$POWERLIMITINWATT" -ne 0 ]] && [[ "$POWERLIMITINWATT" != "skip" ]]; then
    sudo nvidia-smi -pl $POWERLIMITINWATT
  fi

  #################################£
  # FAN SPEED

  if [[ "$FANSPEED" != "0" ]]; then
    echo "--- MANUAL GPU FAN MOD. ---"
  else
    echo "--- AUTO FAN SPEED (by Drivers) ---"
    STR1="-a GPUFanControlState=0"
  fi

  if [[ "$FANSPEED" != "skip" ]]; then
    STR1="-a GPUFanControlState=1 -a GPUTargetFanSpeed="$FANSPEED""
  fi

  #################################£
  # CLOCKS

  if [[ "$MEMORYOFFSET" != "skip" ]] && [[ "$MEMORYOFFSET" != "0" ]]; then
    STR2="-a GPUMemoryTransferRateOffset["$PLEVEL"]="$MEMORYOFFSET" -a GPUMemoryTransferRateOffsetAllPerformanceLevels="$MEMORYOFFSET" $E1"
  fi

  if [[ "$COREOFFSET" != "skip" ]] && [[ "$COREOFFSET" != "0" ]]; then
    STR3="-a GPUGraphicsClockOffset["$PLEVEL"]="$COREOFFSET" -a GPUGraphicsClockOffsetAllPerformanceLevels="$COREOFFSET" $E2"
  fi

  # Lock core clock
  if [[ ! -z "$CORELOCK" ]] && [[ "$CORELOCK" != "0" ]] && [[ "$CORELOCK" != "skip" ]]; then
    echo "Applying Core Clock Lock to All GPUs [$CORELOCK Mhz]"
    #STR3="-a GPUGraphicsClockOffset["$PLEVEL"]=0 -a GPUGraphicsClockOffsetAllPerformanceLevels=0 $E2"
    # SET MEMCLOCK BACK AFTER MINER STARTED 40 sec
    if [[ "$INSTANT" != "instant" ]]; then
      sudo echo "ALL:$CORELOCK" >> /dev/shm/nv_lockcache.txt
      # check lock delay process
      TEST=$(sudo screen -list | grep -wc lockdelay)
      if [ "$TEST" = "0" ]; then
        sudo screen -A -m -d -S lockdelay sudo bash /home/minerstat/minerstat-os/core/lockdelay &
      fi
    else
      sudo nvidia-smi -lgc $CORELOCK
    fi
  fi

  #################################£
  # APPLY THIS GPU SETTINGS AT ONCE
  #echo "nvidia-settings --verbose -c :0 $STR1 $STR2 $STR3 $STR5"
  STR5="-a GPUPowerMizerMode=1"
  echo "$STR1 $STR2 $STR3 $STR5 " >> /dev/shm/nv_clkcache.txt
  DISPLAY=:0
  export DISPLAY=:0
  #sudo su minerstat -c "DISPLAY=:0 nvidia-settings --verbose -c :0 $STR1 $STR2 $STR3 $STR5"

  #sleep 2
  #sudo chvt 1

fi
