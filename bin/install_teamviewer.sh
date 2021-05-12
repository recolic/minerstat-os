#!/bin/bash
echo "*** Installing TeamViewer ***"
wget -o /dev/null https://download.teamviewer.com/download/linux/teamviewer_amd64.deb
sudo dpkg -i teamviewer_amd64.deb
sudo apt-get --assume-yes install -f
sudo teamviewer --daemon enable
echo "*** Teamviewer Installed ***"
sudo teamviewer --passwd minerstat
sudo teamviewer license accept
killall teamviewer
echo ""
echo "--- Waiting for your ID ----"
sudo teamviewer --daemon restart
sudo teamviewer --info print version, status, id | grep "TeamViewer ID:"
echo "   Teamviewer Password: minerstat"
sudo rm teamviewer_amd64.deb
