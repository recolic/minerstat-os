#!/bin/bash

echo ""
echo "=== UPDATING NVIDIA DRIVERS TO v396.51 ==="
echo ""
echo "--- Ctrl + C to abort it. ---"

sleep 3

# STOP MINING AND STUFF
sudo killall screen
killall screen
killall node
sleep 5
sudo chvt 1

sudo apt-get --yes --force-yes purge snapd ubuntu-core-launcher squashfs-tools
sudo apt-get --yes --force-yes update
sudo apt-get --yes --force-yes install cuda-runtime-9-2

sleep 3

echo ""

echo "You need to reboot to apply changes."
echo""

echo "=== REBOOTING ==="
echo "--- Ctrl + C to abort it. ---"

sleep 5

sudo shutdown -r now
