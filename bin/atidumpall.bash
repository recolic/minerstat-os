#!/bin/bash
#exec 2>/dev/null

AMDDEVICE=$(timeout 40 sudo lspci -k | grep VGA | grep -vE "Kaveri|Beavercreek|Sumo|Wrestler|Kabini|Mullins|Temash|Trinity|Richland|Stoney|Carrizo|Raven|Renoir|Picasso|Van" | grep -c "AMD")
if [ -z "$AMDDEVICE" ]; then
  AMDDEVICE=$(timeout 3 sudo lshw -C display | grep AMD | wc -l)
fi
if [ -z "$AMDDEVICE" ]; then
  AMDDEVICE=$(timeout 3 sudo lshw -C display | grep driver=amdgpu | wc -l)
fi

sudo rm -rf /home/minerstat/minerstat-os/bin/bios
sudo mkdir /home/minerstat/minerstat-os/bin/bios
sudo chmod -R 777 /home/minerstat/minerstat-os/bin/bios

cd /home/minerstat/minerstat-os/bin

if [ "$AMDDEVICE" != 0 ]
then
  echo ""
else
  echo "No AMD GPU's detected"
  exit 1
fi

echo "=== VBIOS DUMP ==="
echo ""
echo "Saving your gpu rom's to /home/minerstat/minerstat-os/bin/bios"
echo ""

for (( i=0; i < $AMDDEVICE; i++ )); do
  echo "=== Exporting GPU$i VBIOS ==="
  sudo ./atiflash -s $i "bios/"$i"_bios.rom"
done

sudo chmod -R 777 /home/minerstat/minerstat-os/bin/bios

ls bios

echo ""
echo "==== BIOS DUMP DONE ==="
