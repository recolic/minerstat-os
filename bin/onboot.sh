#!/bin/bash

FILE=/dev/shm/boot.pid
if [ ! -f "$FILE" ]; then
  #sudo rm /tmp/stop.pid > /dev/null 2>&1
  sudo su -c "sudo rm /tmp/stop.pid"
  sudo su -c "echo '1' > /dev/shm/boot.pid"
  file=/home/minerstat/minerstat-os/bin/random.txt
  if [ -e "$file" ]; then
    sleep 1;
    if ! screen -list | grep -q "dummy"; then
      echo "Moving MSOS config.js to / (LINUX)"
      sudo cp -rf "/media/storage/config.js" "/home/minerstat/minerstat-os/"
      screen -A -m -d -S boot_process /home/minerstat/minerstat-os/bin/work.sh
      /home/minerstat/minerstat-os/bin/shellinaboxd --port 4200 -s '/:SSH:0.0.0.0' -b --css "/home/minerstat/minerstat-os/core/white-on-black.css" --disable-ssl
    fi
  else
    echo "Moving MSOS config.js to / (LINUX)"
    sudo cp -rf "/media/storage/config.js" "/home/minerstat/minerstat-os/"
    screen -A -m -d -S boot_process /home/minerstat/minerstat-os/bin/work.sh
  fi
fi
