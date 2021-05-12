#!/bin/bash
exec 2>/dev/null

sudo rm domem.sh
sleep 1

if [ ! $1 ]; then

  #################################£
  # Detect GPU's
  AMDDEVICE=$(timeout 40 sudo lspci -k | grep VGA | grep -vE "Kaveri|Beavercreek|Sumo|Wrestler|Kabini|Mullins|Temash|Trinity|Richland|Stoney|Carrizo|Raven|Renoir|Picasso|Van" | grep -c "AMD")
  if [ -z "$AMDDEVICE" ]; then
    AMDDEVICE=$(timeout 3 sudo lshw -C display | grep AMD | wc -l)
  fi
  if [ -z "$AMDDEVICE" ]; then
    AMDDEVICE=$(timeout 3 sudo lshw -C display | grep driver=amdgpu | wc -l)
  fi

  #################################£
  # Rig details
  TOKEN="$(cat /home/minerstat/minerstat-os/config.js | grep 'global.accesskey' | sed 's/global.accesskey =//g' | sed 's/;//g')"
  WORKER="$(cat /home/minerstat/minerstat-os/config.js | grep 'global.worker' | sed 's/global.worker =//g' | sed 's/;//g')"

  echo ""
  echo "--- GRAPHICS CARDS ---"
  echo "FOUND AMD    :  $AMDDEVICE"
  echo ""


  if [ "$AMDDEVICE" -gt "0" ]; then

    START_ID="$(sudo ./amdcovc | grep "Adapter" | cut -f1 -d':' | sed '1q' | sed 's/[^0-9]//g')"
    # First AMD GPU ID. 0 OR 1 Usually
    STARTS=$START_ID

    echo "STARTS WITH ID: $STARTS"

    i=0
    SKIP=""
    while [ $i -le $AMDDEVICE ]; do
      if [ -f "/sys/class/drm/card$i/device/pp_table" ]
      then
        SKIP=$SKIP
      else
        SKIP=$SKIP"-$i"
      fi
      i=$(($i+1))
    done

    if [ "$SKIP" != "" ]
    then
      echo "Integrated Graphics ID: "$SKIP
    fi

    if grep -q experimental "/etc/lsb-release"; then
      OSVERSION="experimental"
    else
      OSVERSION="stable"
    fi

    wget -o /dev/null -qO domem.sh "https://api.minerstat.com/v2/getstraps.php?token=$TOKEN&worker=$WORKER&nums=$AMDDEVICE&starts=$STARTS&skip=$SKIP&osversion=$OSVERSION"
    sleep 1.5
    sudo chmod 777 domem.sh
    sleep 0.5
    ./domem.sh
  fi

fi
