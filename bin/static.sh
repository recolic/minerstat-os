#!/bin/bash
echo -e ""
echo -e "\033[1;34m======== CONFIGURING STATIC IP =========\033[0m"

FILE=/etc/netplan/minerstat.yaml
if [ -f "$FILE" ]; then
  sudo su -c "rm /etc/netplan/minerstat.yaml"
fi

INTERFACE="$(sudo cat /proc/net/dev | grep -vE "lo|docker0|wlan0" | tail -n1 | awk -F '\\:' '{print $1}' | xargs)"

# READ FROM network.txt
ADDRESS=$(cat /media/storage/network.txt | grep 'IPADDRESS="' | sed 's/IPADDRESS="//g' | sed 's/"//g')
NETMASK=$(cat /media/storage/network.txt | grep 'NETMASK="' | sed 's/NETMASK="//g' | sed 's/"//g')
GATEWAY=$(cat /media/storage/network.txt | grep 'GATEWAY="' | sed 's/GATEWAY="//g' | sed 's/"//g')

echo -e "\033[1;34m==\033[0m Static Interface: \033[1;32m$INTERFACE\033[0m"
echo -e ""

NETRESTART="NO"
IFACE=$(cat /etc/network/interfaces | grep "auto $INTERFACE" | xargs)
if [ "$IFACE" != "auto $INTERFACE" ]; then
  sudo su -c "echo -n > /etc/network/interfaces; echo auto $INTERFACE >> /etc/network/interfaces; echo iface $INTERFACE inet static >> /etc/network/interfaces; echo address $ADDRESS >> /etc/network/interfaces; echo netmask $NETMASK >> /etc/network/interfaces; echo gateway $GATEWAY >> /etc/network/interfaces; echo dns-nameservers 1.1.1.1 >> /etc/network/interfaces" 2>/dev/null
  NETRESTART="YES"
fi

NSCHECK=$(cat /etc/resolv.conf | grep "nameserver $GATEWAY" | xargs)
if [ "$NSCHECK" != "nameserver $GATEWAY" ]; then
  sudo su -c "echo -n > /etc/resolv.conf; echo 'nameserver $GATEWAY' >> /etc/resolv.conf; echo 'nameserver 1.1.1.1' >> /etc/resolv.conf; echo 'nameserver 1.0.0.1' >> /etc/resolv.conf; echo 'nameserver 8.8.8.8' >> /etc/resolv.conf; echo 'nameserver 8.8.4.4' >> /etc/resolv.conf; echo 'nameserver 114.114.114.114' >> /etc/resolv.conf; echo 'nameserver 114.114.115.115' >> /etc/resolv.conf; echo nameserver 2606:4700:4700::1111 >> /etc/resolv.conf; echo nameserver 2606:4700:4700::1001 >> /etc/resolv.conf; echo 'nameserver 1.1.1.1' > /run/resolvconf/interface/systemd-resolved; echo 'nameserver 1.0.0.1' >> /run/resolvconf/interface/systemd-resolved; echo 'nameserver 1.1.1.1' > /run/systemd/resolve/stub-resolv.conf; echo 'nameserver 1.0.0.1' >> /run/systemd/resolve/stub-resolv.conf; echo options edns0 >> /run/systemd/resolve/stub-resolv.conf" 2>/dev/null
  NETRESTART="YES"
fi

if [ "$NETRESTART" = "YES" ]; then
  sudo su -c "/etc/init.d/networking restart; systemctl restart systemd-networkd" 2>/dev/null
fi

sudo ifconfig eth0 $ADDRESS netmask $NETMASK
sudo route add default gw $GATEWAY eth0

TEST="$(ping api.minerstat.com -w 1 | grep '1 packets transmitted' | xargs)"
if [[ "$TEST" == *"0% packet loss"* ]]; then
  echo -e ""
  echo -e "\033[1;34m==\033[0m Internet connection: \033[1;32mONLINE\033[0m"
else
  echo -e ""
  echo -e "\033[1;34m==\033[0m Internet connection: \033[1;31mOFFLINE\033[0m"
fi
