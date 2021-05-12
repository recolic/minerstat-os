#!/bin/bash

echo ""
echo "=== UPDATING AMD DRIVERS TO v17.50 ==="
echo ""
echo "--- Ctrl + C to abort it. ---"

sleep 3

# STOP MINING AND STUFF
sudo killall screen
killall screen
killall node
sleep 5
sudo chvt 1

# UPDATE
sudo apt-get --yes --force-yes purge snapd ubuntu-core-launcher squashfs-tools
sudo apt-get --yes --force-yes update

cd /tmp
wget -o /dev/null --referer http://support.amd.com/ https://www2.ati.com/drivers/linux/ubuntu/amdgpu-pro-17.50-511655.tar.xz
tar xvf amdgpu-pro-17.50-511655.tar.xz
cd amdgpu-pro-17.50-511655/
sudo ./amdgpu-pro-install -y --compute

sleep 3

echo ""

echo "You need to reboot to apply changes."
echo""

echo "=== REBOOTING ==="
echo "--- Ctrl + C to abort it. ---"

sleep 5

sudo shutdown -r now
