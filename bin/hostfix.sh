#!/bin/bash
exec 2>/dev/null

# check cloudflare ips main
SERVERA="104.26.9.16"
SERVERB="104.26.8.16"
SERVERF="172.67.68.245"
SERVERC="$SERVERB"
DNSA=$(ping -c 1 $SERVERA &> /dev/null && echo success || echo fail)
if [ "$DNSA" = "success" ]; then
  SERVERC="$SERVERA"
else
  DNSF=$(ping -c 1 $SERVERF &> /dev/null && echo success || echo fail)
  if [ "$DNSF" = "success" ]; then
    SERVERC="$SERVERF"
  else
    SERVERC="$SERVERA"
  fi
fi

# check cloudflare ips static
SSERVERA="104.26.1.235"
SSERVERB="104.26.0.235"
SSERVERF="172.67.70.62"
SSERVERC="$SSERVERB"
SDNSA=$(ping -c 1 $SSERVERA &> /dev/null && echo success || echo fail)
if [ "$SDNSA" = "success" ]; then
  SSERVERC="$SSERVERA"
else
  SDNSF=$(ping -c 1 $SSERVERF &> /dev/null && echo success || echo fail)
  if [ "$SDNSF" = "success" ]; then
    SSERVERC="$SSERVERF"
  else
    SSERVERC="$SSERVERA"
  fi
fi

# Change hostname
# /etc/hosts
HCHECK=$(cat /etc/hosts | grep "$SERVERC minerstat.com" | xargs)
WCHECK=$(cat /etc/hosts | grep "127.0.1.1 $WNAME" | xargs)

CURRENT_DATE=$(date +'%Y-%m-%d %H:00')
WNAME=$(cat /media/storage/config.js | grep 'global.worker' | sed 's/global.worker =/"/g' | sed 's/"//g' | sed 's/;//g' | xargs)
if [ "$HCHECK" != "$SERVERC minerstat.com" ] || [ "$WCHECK" != "127.0.1.1 $WNAME" ] || [ "$CCHECK" != "$CURRENT_DATE" ]; then
  sudo echo "
127.0.0.1 localhost localhost.localdomain localhost4 localhost4.localdomain4
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
127.0.1.1 $WNAME
$SERVERC minerstat.com
$SERVERC www.minerstat.com
$SERVERC api.minerstat.com
$SSERVERC static-ssl.minerstat.farm
68.183.74.40 eu.pool.ms
167.71.240.6 us.pool.ms
68.183.74.40 eu.sandbox.pool.ms
167.71.240.6 us.sandbox.pool.ms
162.159.200.1 ntp.ubuntu.com
134.209.234.128 lanflare.com
$SSERVERC labs.minerstat.farm
  " > /etc/hosts
  # Set hostname after new hosts file
  sudo su -c "echo '$WNAME' > /etc/hostname"
  sudo hostname -F /etc/hostname
  # Manage CACHE
  sudo rm /home/minerstat/mining-pool-whitelist.txt 2>/dev/null
  timeout 10 wget -o /dev/null https://minerstat.com/mining-pool-whitelist.txt -O /home/minerstat/mining-pool-whitelist.txt
  if [ $? -ne 0 ]; then
    echo "Cache wget failed. Trying next time"
  else
    TEST=$(sudo wc -c /home/minerstat/mining-pool-whitelist.txt | awk '{print $1}')
    TEST2=$(cat /home/minerstat/mining-pool-whitelist.txt | grep -c "ethermine")
    TEST3=$(cat /home/minerstat/mining-pool-whitelist.txt | grep -c "2miners")
    TEST4=$(cat /home/minerstat/mining-pool-whitelist.txt | grep -c "nanopool")
    if [[ "$TEST" -gt 1000 ]] && [[ "$TEST2" -gt 0 ]] && [[ "$TEST3" -gt 0 ]] && [[ "$TEST4" -gt 0 ]]; then
      echo "Cache valid"
      sudo cat /home/minerstat/mining-pool-whitelist.txt >> /etc/hosts
      sudo echo "$CURRENT_DATE" > /home/minerstat/cache_date
      sync &
    fi
  fi
fi

GET_GATEWAY=$(timeout 5 route -n -e -4 | awk {'print $2'} | grep -vE "0.0.0.0|IP|Gateway" | head -n1 | xargs)
RES_TEST=$(timeout 15 ping -c1 l.root-servers.net > /dev/null && echo "ok" || echo "failed")
NSCHECK=$(cat /etc/resolv.conf | grep "nameserver 1.1.1.1" | xargs)
if [ "$NSCHECK" != "nameserver 1.1.1.1" ] || [ ! -z "$GET_GATEWAY" ] || [ "$RES_TEST" = "failed" ]; then
  #GCHECK=$(cat /etc/resolv.conf | grep "nameserver $GET_GATEWAY" | xargs)
  if [ ! -z "$GET_GATEWAY" ]; then
    # Detect IP blocker DNS
    BLOCK_TEST=$(nslookup eu1.ethermine.org $GET_GATEWAY | grep Address: | grep "0.0.0.0" | head -n1 | awk '{print $2}' | xargs | xargs)
    if [ "$BLOCK_TEST" = "0.0.0.0" ] || [ "$BLOCK_TEST" = "::" ]; then
      sudo su -c "echo -n > /etc/resolv.conf; echo 'nameserver 1.1.1.1' >> /etc/resolv.conf; echo 'nameserver 1.0.0.1' >> /etc/resolv.conf; echo 'nameserver 8.8.8.8' >> /etc/resolv.conf; echo 'nameserver 8.8.4.4' >> /etc/resolv.conf; echo 'nameserver 114.114.114.114' >> /etc/resolv.conf; echo 'nameserver 114.114.115.115' >> /etc/resolv.conf; echo nameserver 2606:4700:4700::1111 >> /etc/resolv.conf; echo nameserver 2606:4700:4700::1001 >> /etc/resolv.conf;" 2>/dev/null
    else
      sudo su -c "echo -n > /etc/resolv.conf; echo 'nameserver $GET_GATEWAY' >> /etc/resolv.conf; echo 'nameserver 1.1.1.1' >> /etc/resolv.conf; echo 'nameserver 1.0.0.1' >> /etc/resolv.conf; echo 'nameserver 8.8.8.8' >> /etc/resolv.conf; echo 'nameserver 8.8.4.4' >> /etc/resolv.conf; echo 'nameserver 114.114.114.114' >> /etc/resolv.conf; echo 'nameserver 114.114.115.115' >> /etc/resolv.conf; echo nameserver 2606:4700:4700::1111 >> /etc/resolv.conf; echo nameserver 2606:4700:4700::1001 >> /etc/resolv.conf;" 2>/dev/null
    fi
  else
    sudo su -c "echo -n > /etc/resolv.conf; echo 'nameserver 1.1.1.1' >> /etc/resolv.conf; echo 'nameserver 1.0.0.1' >> /etc/resolv.conf; echo 'nameserver 8.8.8.8' >> /etc/resolv.conf; echo 'nameserver 8.8.4.4' >> /etc/resolv.conf; echo 'nameserver 114.114.114.114' >> /etc/resolv.conf; echo 'nameserver 114.114.115.115' >> /etc/resolv.conf; echo nameserver 2606:4700:4700::1111 >> /etc/resolv.conf; echo nameserver 2606:4700:4700::1001 >> /etc/resolv.conf" 2>/dev/null
  fi
fi
