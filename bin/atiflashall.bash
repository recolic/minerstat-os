#!/bin/bash
#exec 2>/dev/null

AMDDEVICE=$(timeout 40 sudo lspci -k | grep VGA | grep -vE "Kaveri|Beavercreek|Sumo|Wrestler|Kabini|Mullins|Temash|Trinity|Richland|Stoney|Carrizo|Raven|Renoir|Picasso|Van" | grep -c "AMD")
if [ -z "$AMDDEVICE" ]; then
  AMDDEVICE=$(timeout 3 sudo lshw -C display | grep AMD | wc -l)
fi
if [ -z "$AMDDEVICE" ]; then
  AMDDEVICE=$(timeout 3 sudo lshw -C display | grep driver=amdgpu | wc -l)
fi
BIOS=$1
ARG2=$2

echo "====== ATIFLASHER ======="

if [ "$AMDDEVICE" != 0 ]
then
  echo ""
else
  echo "No AMD GPU's detected"
  exit 1
fi

if [ "$BIOS" != "" ]
then
  echo ""
else
  echo "Flash VBIOS to all AMD GPUs on the system"
  echo "You need to upload your .rom file to /home/minerstat/minerstat-os/bin (SFTP)"
  echo "Usage: atiflashall bios.rom";
  echo "To force the flash use: atiflashall bios.rom -f"
  exit 1
fi

cd /home/minerstat/minerstat-os/bin

sudo ./atiflash -i
echo ""

for (( i=0; i < $AMDDEVICE; i++ )); do
  echo "--- Flashing GPU$i ---"
  if [ "$ARG2" != "-f" ]
  then
    sudo ./atiflash -p $i $BIOS
  else
    sudo ./atiflash -p -f $i $BIOS
  fi
done

sudo ./atiflash -i

echo ""
echo "------ FLASH DONE -------"
echo "Reboot to apply changes"
echo "======  Done   ========="
