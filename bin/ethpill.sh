#!/bin/bash
exec 2>/dev/null

DELAY=$(sudo cat /media/storage/settings.txt | grep "OHGODADELAY=" | sed 's/[^=]*\(=.*\)/\1/' | tr --delete = | xargs)

if [ ! -z "$DELAY" ]; then
  echo "ETHPILL DELAY: $DELAY"
  sleep $DELAY
else
  echo "ETHPILL DELAY: 10"
  sleep 10
fi

while true; do
  sudo /home/minerstat/minerstat-os/bin/OhGodAnETHlargementPill-r2 "$1" "$2"
  sleep 1
done
