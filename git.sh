#! /usr/bin/bash

FIXIT="0"

cd /home/minerstat/minerstat-os/
chmod -R 777 *

exec 2> /home/minerstat/debug.txt
git remote set-url origin http://labs.minerstat.farm/repo/minerstat-os.git
git config --global user.email "dump@minerstat.com"
git config --global user.name "minerstat"
NETBOT="$(git pull -X theirs --no-edit)"

echo $NETBOT

sleep 1

if grep -q "merge" /home/minerstat/debug.txt;
then

  sleep 2

  sudo git commit -a -m "Init"
  sudo git merge --strategy-option theirs --no-edit
  sudo git add * -f
  sudo git commit -a -m "Fix done"

  cd /home/minerstat/minerstat-os/
  chmod -R 777 *

fi

## Validate merges n health

FS_ERROR=$(grep -rnw '/home/minerstat/minerstat-os' -e '<<<<<<< HEAD' | grep -vE "node_modules|git.sh" | wc -l)
if [[ "$FS_ERROR" -gt "0" ]]; then
  echo "Some files might be corrupted (out of sync), attempting recovery .."
  FIXIT="1"
fi

# Validate GIT Health
timeout 10 git status > /dev/shm/gitstatus.txt
READBACK=$(cat /dev/shm/gitstatus.txt)
if [[ "$READBACK" == *"error"* ]]; then
  echo "Auto sync highly corrupted, attempting recovery .."
  FIXIT="1"
fi

if [[ "$FIXIT" = "1" ]]; then
  if [[ -z $1 ]]; then
    sudo su -c "sudo screen -X -S minew quit"
    sudo su -c "sudo screen -X -S fakescreen quit"
    sudo su -c "screen -ls minew | grep -E '\s+[0-9]+\.' | awk -F ' ' '{print $1}' | while read s; do screen -XS $s quit; done"
    sudo su minerstat -c "screen -X -S fakescreen quit"
    screen -ls minerstat-console | grep -E '\s+[0-9]+\.' | awk -F ' ' '{print $1}' | while read s; do screen -XS $s quit; done
    sudo su minerstat -c "screen -ls minerstat-console | grep -E '\s+[0-9]+\.' | awk -F ' ' '{print $1}' | while read s; do screen -XS $s quit; done"
    sudo killall node
    sleep 0.25
    cd /home/minerstat
    sudo rm /home/minerstat/recovery.sh
    wget -o /dev/null https://labs.minerstat.farm/repo/minerstat-os/-/raw/master/core/recovery.sh
    sudo chmod 777 /home/minerstat/recovery.sh
    sudo bash /home/minerstat/recovery.sh
    sudo bash /home/minerstat/minerstat-os/bin/overclock.sh &
    sleep 15
    sudo su minerstat -c "screen -A -m -d -S fakescreen sh /home/minerstat/minerstat-os/bin/fakescreen.sh"
    sleep 2
    sudo su minerstat -c "screen -A -m -d -S minerstat-console sudo /home/minerstat/minerstat-os/launcher.sh"
  else
    echo "File system corrupted but not attempting to auto-fix because not manually requested or the machine not just booting"
  fi
fi

#sudo rm /home/minerstat/debug.txt

# APPLY NEW BASHRC
sudo cp -fR /home/minerstat/minerstat-os/core/.bashrc /home/minerstat

chmod -R 777 /home/minerstat/minerstat-os/*

# NPM UPDATE
# npm update

sudo /home/minerstat/minerstat-os/bin/jobs.sh
sudo sync &
