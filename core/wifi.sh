#!/bin/bash

echo ""
echo -e "\033[1;34m========== CONFIGURING WIFI ============\033[0m"

INTERFACE="$(ls /sys/class/net)"
DEVICE=""
SSID=$(cat /media/storage/network.txt | grep 'WIFISSID="' | sed 's/WIFISSID="//g' | sed 's/"//g')
PASSWD=$(cat /media/storage/network.txt | grep 'WIFIPASS="' | sed 's/WIFIPASS="//g' | sed 's/"//g')

FILE=/etc/netplan/minerstat.yaml
if [ -f "$FILE" ]; then
  sudo su -c "rm /etc/netplan/minerstat.yaml"
fi

for dev in $INTERFACE; do
  if [ -d "/sys/class/net/$dev/wireless" ]; then DEVICE=$dev; fi;
done

sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager

if echo "$DEVICE" | grep "w" ;then

  echo -e "\033[1;34m==\033[0m Wifi Device: \033[1;32m$DEVICE\033[0m"
  echo -e "\033[1;34m==\033[0m Wifi SSID: \033[1;32m$SSID\033[0m"

  nmcli d wifi rescan
  nmcli d wifi list

  sleep 1

  nmcli device wifi connect "$SSID" password "$PASSWD" > /tmp/wifi.log

  CONNECT=$(cat /tmp/wifi.log)
  echo
  echo $CONNECT
  echo

  echo -e "\033[1;34m==\033[0mIf error happens during connection. Press CTRL + A + D\033[0m"
  echo -e "\033[1;34m==\033[0mAfter you will be able to enter commands to the terminal\033[0m"
  echo
  echo -e "\033[1;34m==\033[0mTo connect manually enter: mwifi SSID PASSWORD\033[0m"
  echo

  if echo "$CONNECT" | grep "failed" ;then
    echo -e ""
    echo -e "\033[1;34m==\033[0m \033[1;31mAdapter activation failed\033[0m"
    echo -e "\033[1;34m==\033[0mYou should replug Wifi adapter to your system\033[0m"
    sleep 10
    cd /home/minerstat/minerstat-os/core
    sudo sh wifi.sh
    echo -e ""
    exit
  else
    echo $CONNECT
  fi

  NSCHECK=$(cat /etc/resolv.conf | grep 'nameserver 1.1.1.1' | xargs)
  if [ "$NSCHECK" != "nameserver 1.1.1.1" ]; then
    sudo su -c 'echo -e "" > /etc/resolv.conf; echo -e "nameserver 1.1.1.1" >> /etc/resolv.conf; echo -e "nameserver 1.0.0.1" >> /etc/resolv.conf; echo -e "nameserver 8.8.8.8" >> /etc/resolv.conf; echo -e "nameserver 8.8.4.4" >> /etc/resolv.conf; echo -e "nameserver 114.114.114.114" >> /etc/resolv.conf; echo -e "nameserver 114.114.115.115" >> /etc/resolv.conf; echo nameserver 2606:4700:4700::1111 >> /etc/resolv.conf; echo nameserver 2606:4700:4700::1001 >> /etc/resolv.conf; echo -e "nameserver 1.1.1.1" > /run/resolvconf/interface/systemd-resolved; echo -e "nameserver 1.0.0.1" >> /run/resolvconf/interface/systemd-resolved; echo -e "nameserver 1.1.1.1" > /run/systemd/resolve/stub-resolv.conf; echo -e "nameserver 1.0.0.1" >> /run/systemd/resolve/stub-resolv.conf; echo options edns0 >> /run/systemd/resolve/stub-resolv.conf' 2>/dev/null
  fi

  # try to up
  IFACESTATUS=$(sudo timeout 5 /sbin/ifconfig $DEVICE | grep "UP," | xargs)
  if [[ "$IFACESTATUS" != *"UP,"* ]]; then
    #sudo ifconfig $INTERFACE down
    nohup sudo ifconfig $DEVICE up &
    sleep 4
  fi

  TEST="$(ping api.minerstat.com -w 1 | grep '1 packets transmitted' | xargs)"
  if [[ "$TEST" == *"0% packet loss"* ]]; then
    echo ""
    echo -e "\033[1;34m==\033[0m Internet connection: \033[1;32mONLINE\033[0m"
  else
    echo ""
    echo -e "\033[1;34m==\033[0m Internet connection: \033[1;31mOFFLINE\033[0m"
    echo ""
    nmcli device wifi connect "$SSID" password "$PASSWD"
  fi

else
  echo ""
  echo -e "\033[1;34m==\033[0m \033[1;31mNo supported wifi adapter found\033[0m"
fi
