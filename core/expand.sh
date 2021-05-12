#!/bin/bash

DRIVE_NUMBER=$(df -h | grep "20M" | grep "/dev/" | cut -f1 -d"2" | sed 's/dev//g' | sed 's/\///g' | sed 's/[0-9]*//g' | head -n1 | xargs)
DRIVE_PARTITION=$DRIVE_NUMBER"1"
DRIVE_PARTITION2=$DRIVE_NUMBER"4"
DRIVE_EFI=$DRIVE_NUMBER"3"
if [ "$DRIVE_NUMBER" = "nvmenp" ]; then
  echo "Changeing header, NVM drive detected.."
  DRIVE_NUMBER="$(df -h | grep "20M" | grep "/dev/" | cut -f1 -d"2" | sed 's/dev//g' | sed 's/\///g' | xargs | sed 's/.$//' | sed 's/\s.*$//' | xargs | sed 's/\p//g')"
  DRIVE_PARTITION=$DRIVE_NUMBER"p1"
  DRIVE_EFI=$DRIVE_NUMBER"p3"
fi
#echo $DRIVE_NUMBER
#PARTITION_MAX_SIZE_IN_GB=$(lsblk | grep $DRIVE_PARTITION | grep part | head -n 1 | awk '{print $4}' | sed 's/[^.0-9]*//g')
#sudo cat /proc/partitions | grep $DRIVE_NUMBER | head -n1 | awk '{print $3}'
PARTITION_MAX_SIZE_IN_BYTE=$(sudo cat /proc/partitions | grep $DRIVE_NUMBER | head -n1 | awk '{print $3}')
PARTITION_MAX_SIZE_IN_MB=$(python -c "print $PARTITION_MAX_SIZE_IN_BYTE / 1024")
CURRENT_PARTITION_SIZE_IN_BYTE=$(sudo cat /proc/partitions | grep $DRIVE_PARTITION | head -n1 | awk '{print $3}')
CURRENT_PARTITION_SIZE_IN_MB=$(python -c "print $CURRENT_PARTITION_SIZE_IN_BYTE / 1024")
#CURRENT_PARTITION_SIZE_IN_GB=$(df -h | grep $DRIVE_PARTITION | awk '{print $2}' | sed 's/[^.0-9]*//g')
#CURRENT_PARTITION_SIZE_IN_MB=$(python -c "print $CURRENT_PARTITION_SIZE_IN_GB * 1024")
SIZE_DIFFERENCE=$(python -c "print $PARTITION_MAX_SIZE_IN_MB - $CURRENT_PARTITION_SIZE_IN_MB" | cut -f1 -d".") # 0.1 x 1000 = 100Mb

echo "-*- Expanding /dev/$DRIVE_PARTITION Partition -*-"

#echo $PARTITION_MAX_SIZE_IN_BYTE
echo "Drive max size: $PARTITION_MAX_SIZE_IN_MB Mb"
#echo $CURRENT_PARTITION_SIZE_IN_GB
echo "Current max size: $CURRENT_PARTITION_SIZE_IN_MB"
echo "Difference in size: $SIZE_DIFFERENCE"

# Keep 300Mb difference between drive and partition size for check
if [ "$SIZE_DIFFERENCE" -lt "300" ]; then
  RESIZED="RESIZED"
else
  RESIZED="NEED"
fi

if [ "$RESIZED" = "RESIZED" ]; then
  echo "=== ALREADY RESIZED ==="
  # Safety Check
  CURRENT_FREE_SPACE_IN_MB="$(df -hm | grep $DRIVE_PARTITION | awk '{print $4}')"
  if [ "$CURRENT_FREE_SPACE_IN_MB" -lt "285" ]; then
    # 285 Mb less free space try resize anyway
    sudo resize2fs /dev/$DRIVE_PARTITION
  fi
else
  echo "=== RESIZING ==="
  (
    echo d # Delete partition
    echo 1 # Delete first
    echo n # New partition
    echo p # Primary
    echo 1 # 1 Partition
    echo   # First sector (Accept default: 1)
    echo   # Last sector (Accept default: varies)
    echo w # Write changes
  ) | sudo fdisk /dev/$DRIVE_NUMBER | grep "Created a new partition"
  (
    echo d # Delete partition
    echo   # Delete first
    echo n # New partition
    echo   # 1 Partition
    echo   # First sector (Accept default: 1)
    echo   # Last sector (Accept default: varies)
    echo w # Write changes
  ) | sudo fdisk /dev/$DRIVE_NUMBER | grep "Created a new partition"
  sudo growpart "/dev/$DRIVE_NUMBER" 1
  sudo growpart "/dev/$DRIVE_NUMBER" 4
  echo ""
  sudo resize2fs /dev/$DRIVE_PARTITION
  sudo resize2fs /dev/$DRIVE_PARTITION2
  echo ""
  CURRENT_FREE_SPACE_IN_MB="$(df -hm | grep $DRIVE_PARTITION | awk '{print $4}')"
  echo "Free Space on the Disk: $CURRENT_FREE_SPACE_IN_MB MB"
fi
