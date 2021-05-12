#!/bin/bash
#sudo su
echo "*-*-*-- MINERSTAT OS RECOVERY --*-*-*"
echo "*-*-*-- WAITING FOR CONNECTION --*-*-*"
echo "Connecting to recovery server..."
while ! ping labs.minerstat.farm -w 1 | grep "0%"; do
  sleep 1
done
echo "Connecting to API ..."
while ! ping api.minerstat.com -w 1 | grep "0%"; do
  sleep 1
done
sudo killall node
sudo screen -S minerstat-console -X quit
sudo screen -S listener -X quit
sudo rm -rf /home/minerstat/minerstat-os
cd /home/minerstat
ls
git config --global http.postBuffer 524288000
git clone http://labs.minerstat.farm/repo/minerstat-os.git/
chmod 777 minerstat-os
cd /home/minerstat/minerstat-os
sudo chmod -R 777 *

#echo "Fetching IP.."
#IP=$(timeout 10 curl -s ipinfo.io/$(dig @ns1-1.akamaitech.net ANY whoami.akamai.net +short | xargs) | grep '"country":' | sed 's/"country": //g' | sed 's/,//g' | xargs)
#echo "IP Attempt to find closest server: $IP"

#if [[ "$IP" = "CN" ]] || [[ "$IP" = "HK" ]] || [[ "$IP" = "MO" ]]; then
#  echo "Proxy NPM server selected"
#  sudo npm config set registry http://r.cnpmjs.org
#else
#  echo "Global NPM server selected"
#  sudo npm config set registry http://registry.npmjs.org
#fi

sudo npm config set registry http://68.183.74.40:4873

sudo npm cache clean --force
sudo npm update
sudo npm install
sudo chmod -R 777 *
echo "Copy config from MSOS (NTFS) Partition"
cp /media/storage/config.js /home/minerstat/minerstat-os
echo ""
cat config.js
echo ""
echo ""
echo "Recovery is done!"
sudo echo "boot" > /home/minerstat/minerstat-os/bin/random.txt
screen -S listener -X quit # kill running process
screen -A -m -d -S listener sudo sh /home/minerstat/minerstat-os/core/init.sh
echo "MUPDATE"
sudo bash /home/minerstat/minerstat-os/git.sh
echo "You can start mining again with: mstart"
echo ""
echo "*-*-*-- MINERSTAT.COM--*-*-*"
