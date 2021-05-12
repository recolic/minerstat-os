#!/bin/bash

sudo su -c "echo 1 > /proc/sys/net/ipv4/tcp_fin_timeout"
now=$(date +"%T")
PORT=$1

printf "\033[1;34m== \033[0m$now:\033[1;32m Freeing up API Port at: $PORT \033[0m ..."


if [ "$PORT" = "42000" ]; then
  sleep 10
fi

printf "\033[1;32m done\033[0m"
sudo su -c "echo 10 > /proc/sys/net/ipv4/tcp_fin_timeout"
