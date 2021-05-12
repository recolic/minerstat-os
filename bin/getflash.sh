#!/bin/bash
exec 2>/dev/null

sudo rm /home/minerstat/doflash.sh
sleep 1

if [ ! $1 ]; then

  #################################
  # Rig details
  TOKEN="$(cat /home/minerstat/minerstat-os/config.js | grep 'global.accesskey' | sed 's/global.accesskey =//g' | sed 's/;//g')"
  WORKER="$(cat /home/minerstat/minerstat-os/config.js | grep 'global.worker' | sed 's/global.worker =//g' | sed 's/;//g')"

  echo ""
  echo "-------- FETCHING ROM --------"

  wget -o /dev/null -qO /home/minerstat/doflash.sh "https://api.minerstat.com/v2/getflash.php?token=$TOKEN&worker=$WORKER"
  sleep 1.5
  sudo chmod 777 /home/minerstat/doflash.sh
  sleep 0.5
  sudo bash /home/minerstat/doflash.sh

fi
