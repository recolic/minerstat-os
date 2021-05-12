#!/bin/bash
#exec 2>/dev/null

echo "Going to Idle mode"
sudo /home/minerstat/minerstat-os/core/stop >/dev/null 2>&1 &

# Folders
sudo mkdir /home/minerstat/bios > /dev/null 2>&1
sudo mkdir /home/minerstat/bios/backups > /dev/null 2>&1
sudo mkdir /home/minerstat/bios/flashed > /dev/null 2>&1

#################################
# Rig details
TOKEN=$(cat /home/minerstat/minerstat-os/config.js | grep 'global.accesskey' | sed 's/global.accesskey =//g' | sed 's/;//g' | sed 's/"//g' | xargs)
WORKER=$(cat /home/minerstat/minerstat-os/config.js | grep 'global.worker' | sed 's/global.worker =//g' | sed 's/;//g' | sed 's/"//g' | xargs)

echo ""
echo "-------- FETCHING INFO --------"

bus=$(sudo curl --insecure --connect-timeout 15 --max-time 25 --retry 0 --header "Content-type: application/x-www-form-urlencoded" --request POST --data "token=$TOKEN" --data "worker=$WORKER" "https://api.minerstat.com/v2/getbios.php")

GPUBUSINT=$(echo $bus | cut -f 1 -d '.')
GPUBUS=$(python -c 'print(int("'$GPUBUSINT'", 16))')

FLASHER="amdvbflash"
CHECK_SUPPORT=$(sudo /home/minerstat/minerstat-os/bin/$FLASHER -i | awk {'print $3'} | grep -c -i "$GPUBUSINT")
if [[ "$CHECK_SUPPORT" -lt 1 ]]; then
  FLASHER="atiflash"
  CHECK_SUPPORT=$(sudo /home/minerstat/minerstat-os/bin/$FLASHER -i | awk {'print $2'} | grep -c -i "$GPUBUSINT")
fi

echo "using $FLASHER"

if [[ $bus == *"."* ]]; then
  if [[ "$CHECK_SUPPORT" -gt 0 ]]; then
    # Validate
    BUS_ID=""
    echo "Validating with $FLASHER"
    if [[ "$FLASHER" = "atiflash" ]]; then
      BUS_ID=$(sudo /home/minerstat/minerstat-os/bin/$FLASHER -i | awk '{print $1, $2}' | grep -i "$GPUBUSINT" | awk {'print $1'})
    else
      BUS_ID=$(sudo /home/minerstat/minerstat-os/bin/$FLASHER -i | awk '{print $1, $3}' | grep -i "$GPUBUSINT" | awk {'print $1'})
    fi
    # Process
    DATE=$(date '+%Y%m%d%H%M%S')
    BIOS="$DATE-$BUS_ID-bios.rom"
    PATHS="/home/minerstat/bios/backups/$BIOS"
    echo "Backing up $BUS_ID to $PATHS at $DATE"
    sudo /home/minerstat/minerstat-os/bin/$FLASHER -s $BUS_ID $PATHS
    sudo rm /dev/shm/tmpbios.rom >/dev/null 2>&1
    RB=$(sudo /usr/bin/base64 < $PATHS | tr -d "\n" > /dev/shm/tmpbios.rom)
    sudo chmod 777 /dev/shm/tmpbios.rom
    echo "$TOKEN $WORKER $bus"
    curl --insecure --connect-timeout 15 --max-time 25 --retry 0 -F 'data=@/dev/shm/tmpbios.rom' "https://api.minerstat.com/v2/getbios.php?token=$TOKEN&worker=$WORKER&bus=$bus"
  else
    sudo echo -n "error" > /dev/shm/tmpbios.rom
    curl --insecure --connect-timeout 15 --max-time 25 --retry 0 -F 'data=@/dev/shm/tmpbios.rom' "https://api.minerstat.com/v2/getbios.php?token=$TOKEN&worker=$WORKER&bus=$bus"
  fi
else
  echo "Nothing in Queue"
fi
