#! /usr/bin/bash
exec 2>/dev/null

if [ ! $1 ]; then

  while true; do
    output=$(neofetch)
    sleep 0.5;
    if ps ax | grep -v grep | grep node > /dev/null; then
      clear
      echo
      echo
      echo
      echo
      echo
      echo
      echo "$output"
      sleep 0.5
    else
      exit
    fi
  done

else

  while true; do
    output=$(neofetch)
    sleep 0.5;
    clear
    echo
    echo
    echo
    echo
    echo
    echo
    echo "$output"
    sleep 4
  done

fi
