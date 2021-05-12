#!/usr/bin/bash

node /home/minerstat/minerstat-os/validate.js > /dev/shm/validate_node.txt 2>&1
READBACK=$(cat /dev/shm/validate_node.txt)

if [[ $READBACK == *"unexpected"* ]] || [[ $READBACK == *"Unexpected"* ]]; then
  echo ""
  echo "!!!!!!!!!"
  echo "Invalid config.js file. Manual action required!"
  echo "Type: mworker accesskey workername"
  echo "Replace accesskey/workername with your details. After you can try mstart again."
  echo "!!!!!!!!!"
  echo ""
fi

if [[ $READBACK == *"Cannot"* ]] || [[ $READBACK == *"color"* ]]; then
  echo ""
  echo "!!!!!!!!!"
  echo "Some important files missing."
  echo "Type: netrecovery"
  echo "After netrecovery command OS attempt to restore itself to original state. After you can try mstart again."
  echo "!!!!!!!!!"
  echo ""
fi
