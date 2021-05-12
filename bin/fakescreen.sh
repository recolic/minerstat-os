#!/bin/bash

sleep 15

while true
do
  screen -S minerstat-console -X stuff ""
  sudo screen -S minew -X stuff ""
  sleep 5
done
