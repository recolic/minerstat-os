#!/bin/bash
exec 2>/dev/null

sudo rm /home/minerstat/dodirect.sh
sleep 1

if [ ! $1 ]; then

  #################################
  # Rig details
  TOKEN="$(cat /home/minerstat/minerstat-os/config.js | grep 'global.accesskey' | sed 's/global.accesskey =//g' | sed 's/;//g' | sed 's/"//g')"
  WORKER="$(cat /home/minerstat/minerstat-os/config.js | grep 'global.worker' | sed 's/global.worker =//g' | sed 's/;//g' | sed 's/"//g')"

  echo ""
  echo "-------- LOOKING FOR DIRECT --------"

  wget -o /dev/null -qO /home/minerstat/dodirect.sh "https://api.minerstat.com/v2/getdirect.php?token=$TOKEN&worker=$WORKER"
  sleep 1.5
  sudo chmod 777 /home/minerstat/dodirect.sh
  sleep 0.5
  sudo bash /home/minerstat/dodirect.sh

fi
