#!/bin/bash

# Reset
Color_Off='\033[0m'       # Text Reset

# Regular Colors
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow

# Global varibles
DIR="$(dirname "${BASH_SOURCE[0]}")"  # Get the directory name
DIR="$(realpath "${DIR}")"    # Resolve its full path if need be
FR="/tmp/fakeroot"
IS_ONLINE="YES"
FORCE="NO"
SYSTEM=""
ACCESS_KEY=""
WORKERNAME=""

# CDN Settings
SELECTED_VERSION=""
FILE=""
HOST="https://archive.minerstat.com"
HOST_FAILOVER="https://archive-cdn.minerstat.com"

# Samba Share
SMB_HOST=""
SMB_USER=""
SMB_PASS=""
SMB_FILE=""

# SYSINFO
XIN=$(ps aux | grep -c xinit)
CPU_COUNT=$(grep ^cpu\\scores /proc/cpuinfo | uniq | awk '{print $4}')
BOOT_DISK=$(mount | grep ' / ' | awk '{print $1}' | sed 's/[0-9]//g')
BOOT_PART=$(mount | grep ' / ' | awk '{print $1}')
FREE_TMP=$(df -hm | grep "$BOOT_PART" | grep -vE "/media/storage|/boot" | awk '{print $4}')
FREE_MEM=$(free -m | grep "Mem:" | awk '{print $2}')
LOAD_AVG=$(sudo cat /proc/loadavg | awk '{print $1}' | cut -f1 -d".")

function printfo() {
  mark="i"
  if [[ "$1" = "info" ]]; then
    mark="INFO"
  elif [[ "$1" = "fail" ]]; then
    mark="$Red"'FAIL'"$Color_Off"
  elif [[ "$1" = "ok" ]]; then
    mark="$Green OK $Color_Off"
  elif [[ "$1" = "warn" ]]; then
    mark="$Yellow"'WARN'"$Color_Off"
  fi
  echo -n ""
  echo -e "  [$mark] $2 \r"
  echo -n ""
}

function netcheck {
  PING=$(timeout 10 ping -c 1 -W 1 archive.minerstat.com)
  if [[ $PING != *"0% packet loss"* ]]; then
    IS_ONLINE="NO"
  fi
  if [[ "$IS_ONLINE" = "NO" ]]; then
    PING=$(timeout 10 ping -c 1 -W 1 archive-cdn.minerstat.com)
    if [[ $PING != *"0% packet loss"* ]]; then
      IS_ONLINE="YES"
      HOST=$HOST_FAILOVER
      printfo warn "Failover CDN selected"
    fi
  fi
}

function play () {
  n=0
  times=$1
  shift
  while [[ $n -lt $times ]]; do
    #beep -f 300 -l 500
    sudo printf '\a'
    n=$((n+1))
  done
}

# System detection
# Check user root ID0
if [[ "$EUID" -ne 0 ]]; then
  printfo fail "Please run as root"
  printfo info "Easiest way is to enter: sudo su"
  printfo info "Enter root password if asked"
  exit
fi
# Check run
if [[ $0 = "sh" ]] || [[ $0 = "bash" ]]; then
  printfo fail "Only bash or shell supported"
  printfo info "Run this script from bash terminal as root"
  exit
fi

# Detect we are in chroot already or just starting up
if [[ "$(stat -c %d:%i /)" = "$(stat -c %d:%i /proc/1/root/.)" ]]; then
  #
  # Functions to call during non-chroot
  #

  echo
  echo "========== minerstat migration tool =========="
  echo "Tool is designed to assist miners with migration from different Operating Systems to minerstat OS."
  echo "For optimal performance 8GB RAM is recommended. If migration fails, you will have to reflash the drive. "
  echo

  # Check network with global function
  netcheck

  if [[ "$IS_ONLINE" = "YES" ]]; then
    # Check version listing
    if [[ ! -f "/tmp/list.txt" ]]; then
      wget $HOST/list.txt --quiet -P /tmp
    fi
    if [[ ! -f "/tmp/list_recommended.txt" ]]; then
      wget $HOST/list_recommended.txt --quiet -P /tmp
    fi
  else
    printfo fail "No IPv4 connection - Exiting ..."
    exit
  fi

  # Download image from web (rewrite later)
  function image_web {
    printfo info "Downloading to path: $FR/opt/image.zip"
    if [[ ! -f "$FR/opt/image.zip" ]]; then
      WGET_SHOW=$(wget -help | grep -c "show")
      if [[ "$WGET_SHOW" -gt 0 ]]; then
        wget -q --show-progress -O $FR/opt/image.zip "$HOST?file=$FILE"
      else
        wget -O $FR/opt/image.zip "$HOST?file=$FILE"
      fi
    else
      printfo info "RAW Image already exists, skipping download"
    fi
  }

  function examples {
    CR=$(cat /tmp/list_recommended.txt | xargs | xargs)
    CLIST=$(cat /tmp/list.txt)
    FIRST=""
    for zipname in $CLIST; do
      if [[ $zipname == *"$SELECTED_VERSION"* ]]; then
        if [[ -z "$FIRST" ]]; then
          FIRST=$zipname
        fi
      fi
    done
    echo "--stable"
    echo "--version $FIRST"
    echo "--version $CR"
    echo "--version $zipname"
    echo "--smb-share //192.168.0.110/myshare --smb-file myfolder/msos-v1-7-4-K54-N465-A2110.zip"
    echo "--smb-user myuser --smb-pass mypass --smb-share //192.168.0.110/myshare --smb-file myfolder/msos-v1-7-4-K54-N465-A2110.zip"
  }

  function list {
    CR=$(cat /tmp/list_recommended.txt | xargs | xargs)
    echo "Current recommended version:"
    printfo info "$CR"
    echo
    echo "Other available versions:"
    CLIST=$(cat /tmp/list.txt)
    FIRST=""
    for zipname in $CLIST; do
      if [[ $zipname == *"$SELECTED_VERSION"* ]]; then
        if [[ -z "$FIRST" ]]; then
          FIRST=$zipname
        fi
        printfo info "$zipname"
      fi
    done
    echo
    echo "Examples:"
    #printfo info "These examples are using download from the web method"
    #printfo info "For other methods enter: --help"
    echo
    examples
    echo
    exit
  }

  function help {
    printfo info "Loading help menu ..."
    echo
    echo "==========   EXAMPLES =============="
    examples
    echo "==========    BASIC    ============="
    echo "--help                                 |     Showing this menu"
    echo "--list                                 |     Listing all available msOS packages"
    echo "--force                                |     Skipping low memory or disk space checks"
    echo
    echo "==========    WEB      ============="
    echo "--stable                               |     Download and flash latest available version from the web"
    echo "--version %zipname%                    |     Download specific version from the web (Versions listed with --list)"
    echo
    echo "==========    SAMBA    ============="
    echo "--smb-share                            |     Format: //192.168.0.190/myshare"
    echo "--smb-file                             |     Format: foldername/msos-v1-6-K54-N455-A2030.zip"
    echo "--smb-user                             |     Only use this option for username/password protected shares. Example: nobody"
    echo "--smb-pass                             |     Only use this option for username/password protected shares. Example: mypass"
    echo
  }

  # If no args help
  if [[ -z "$1" ]]; then
    help
    exit 1
  fi

  # ARG Parser
  FILE=""
  while (( "$#" )); do
    case "$1" in
      -v|--version)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
          SELECTED_VERSION=$2
          shift 2
        else
          echo
          echo "================="
          echo "Error: Select a version to install" >&2
          echo "================="
          echo
          exit 1
        fi
        ;;
      -s|--stable)
        SELECTED_VERSION="recommended"
        shift
        ;;
      -h|--help)
        help
        shift
        ;;
      -f|--force)
        printfo info "Force flashing enabled - No questions asked"
        FORCE="YES"
        shift
        ;;
      -l|--list)
        list
        shift
        ;;
      --smb-user)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
          SMB_USER=$2
          printfo info "SMB Username: $SMB_USER"
        else
          printfo fail "SMB Username empty"
          exit
        fi
        shift
        ;;
      --smb-pass)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
          SMB_PASS=$2
          printfo info "SMB Pass: $SMB_PASS"
        else
          printfo fail "SMB Pass empty"
          exit
        fi
        shift
        ;;
      --smb-share)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
          SMB_SHARE=$2
          printfo info "SMB Share: $SMB_SHARE"
        else
          printfo fail "SMB Share empty"
          exit
        fi
        shift
        ;;
      --smb-file)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
          SMB_FILE=$2
          printfo info "SMB File Path: $SMB_FILE"
        else
          printfo fail "SMB File Path empty"
          exit
        fi
        shift
        ;;
      -*|--*=) # unsupported flags
        echo "================="
        echo "Error: Unsupported flag $1" >&2
        echo "================="
        exit 1
        ;;
      *) # preserve positional arguments
        PARAMS="$PARAMS $1"
        shift
        ;;
    esac
  done
  # set positional arguments in their proper place
  eval set -- "$PARAMS"

  # Check for GUI
  if [[ "$XIN" -gt "1" ]]; then
    printfo info "Make sure to run this script from text bash console as root"
    printfo info "Running from GUI terminal can break the system"
    if [[ "$FORCE" = "NO" ]]; then
      printfo info "Press Ctrl + C to cancel or press [Enter] to continue"
      read
    fi
  fi
  # Load AVG Warning
  if [[ "$SYSLOAD" -gt $CPU_COUNT ]]; then
    printfo warn "High system Load Average (LA)"
    printfo info "Unexpected issues can occur"
  fi
  # Free space check
  if [[ "$FREE_TMP" -lt 8000 ]]; then
    printfo fail "Error: At least 8GB free space is required"
    if [[ "$FORCE" = "NO" ]]; then
      exit
    fi
  fi
  # Free memory check
  if [[ "$FREE_MEM" -lt 3800 ]]; then
    printfo fail "Error: At least 3800Mb RAM is required"
    if [[ "$FORCE" = "NO" ]]; then
      exit
    fi
  fi

  # Parse version to Archive name
  if [[ ! -z "$SELECTED_VERSION" ]]; then
    printfo info "Searching for OS version: $SELECTED_VERSION"
    if [[ "$SELECTED_VERSION" = "recommended" ]]; then
      FILE=$(cat /tmp/list_recommended.txt | xargs | xargs)
    else
      CLIST=$(cat /tmp/list.txt)
      for zipname in $CLIST; do
        if [[ $zipname == *"$SELECTED_VERSION"* ]]; then
          printfo ok "Match found for $SELECTED_VERSION"
          printfo info "Using package $zipname"
          FILE=$zipname
        fi
      done
    fi
  fi

  # If Samba test connection and download file then ignore web field later on
  if [[ ! -z "$SMB_SHARE" ]]; then
    if [[ -z "$SMB_FILE" ]]; then
      printfo fail "SMB selected but file path is not defined. View examples with: --list"
      echo
      exit
    fi
    # Remove previous samba mounts
    sudo umount -f /mnt/samba > /dev/null 2>&1
    sudo rm -rf /mnt/samba > /dev/null 2>&1
    mkdir /mnt/samba > /dev/null 2>&1
    # Mount Samba share to local folder
    # Format: //192.168.1.122/myshare
    if [[ -z "$SMB_USER" ]]; then
      mount -t cifs -o username=nobody $SMB_SHARE /mnt/samba
    else
      if [[ -z "$SMB_PASS" ]]; then
        SMB_USER="$SMB_USER,password=$SMB_PASS"
      fi
      mount -t cifs -o username=$SMB_USER $SMB_SHARE /mnt/samba
    fi
    ECODE=$?
    printfo info "Validating SMB connection ..."
    sleep 2
    VALIDATE=$(mount | grep "/mnt/samba" | grep -c "$SMB_SHARE")
    if [[ "$VALIDATE" -gt 0 ]]; then
      printfo ok "Connected to Samba Share on $SMB_SHARE [Mount: /mnt/samba]"
      if [[ -f "/mnt/samba/$SMB_FILE" ]]; then
        printfo ok "File found on local share, adding to download queue"
        FILE="samba"
      else
        printfo fail "msOS package not found at [Path: /mnt/samba/$SMB_FILE]"
        echo
        exit
      fi
    else
      printfo fail "SMB connection failed"
      echo
      exit
    fi
  fi

  # If all good start processing
  if [[ ! -z "$FILE" ]]; then
    # Not chrooted so enter to chroot and start flashing
    # Preparing kernel
    timeout 10 echo 1 > /proc/sys/kernel/sysrq > /dev/null 2>&1
    timeout 10 echo 0 > /proc/sysrq-trigger > /dev/null 2>&1
    timeout 10 echo 0 > /proc/sys/kernel/hung_task_timeout_secs > /dev/null 2>&1
    timeout 10 echo 0 > /proc/sys/kernel/printk > /dev/null 2>&1

    sysctl vm.dirty_ratio=90 > /dev/null 2>&1
    sysctl vm.dirty_background_ratio=70 > /dev/null 2>&1
    sysctl vm.dirty_expire_centisecs=0 > /dev/null 2>&1
    sysctl vm.dirty_bytes=999999999 > /dev/null 2>&1
    sysctl vm.dirty_background_bytes=99999999 > /dev/null 2>&1
    sysctl vm.dirty_writeback_centisecs=0 > /dev/null 2>&1

    sudo modprobe pcspkr > /dev/null 2>&1

    # If minerstat disable watchdogs and miner
    LSB=$(cat /etc/lsb-release)
    # Ubuntu
    if [[ "$LSB" == *"Ubuntu"* ]]; then
      SYSTEM="ubuntu"
      printfo info "Detected system [Ubuntu]"
    fi
    # msOS
    if [[ "$LSB" == *"minerstat"* ]]; then
      SYSTEM="msos"
      printfo info "Detected system [msOS]"
      sudo /home/minerstat/minerstat-os/core/stop >/dev/null 2>&1
      printfo ok "msOS essentials - mining stopped"
      sudo /home/minerstat/minerstat-os/core/maintenance >/dev/null 2>&1
      printfo ok "msOS essentials - maintenance mode"
      sudo killall X >/dev/null 2>&1
      sudo killall Xorg >/dev/null 2>&1
      sudo killall Xorg >/dev/null 2>&1
      printfo ok "msOS essentials - Xorg killed"
      screen -A -m -d -S usbdog sudo bash /home/minerstat/minerstat-os/watchdog
      printfo ok "msOS essentials - Watchdog ping started"
      ACCESS_KEY="$(cat /media/storage/config.js | grep 'global.accesskey' | sed 's/global.accesskey =//g' | sed 's/;//g' | sed 's/ //g' | sed 's/"//g' | sed 's/\\r//g' | sed 's/[^a-zA-Z0-9]*//g')"
      WORKERNAME="$(cat /media/storage/config.js | grep 'global.worker' | sed 's/global.worker =//g' | sed 's/;//g' | sed 's/ //g' | sed 's/"//g' | sed 's/\\r//g')"
      printfo info "msOS essentials - Key:    $ACCESS_KEY"
      printfo info "msOS essentials - Worker: $WORKERNAME"
    fi
    # smOS
    if [[ -f /mnt/user/config.txt ]] || [[ -f /root/config.txt ]]; then
      SYSTEM="smos"
      printfo info "Detected system [smOS]"
      mv -f /root/utils /root/utils2
      printfo ok "smOS essentials - Folders renamed"
      echo "" > /var/tmp/reflashing.run
      printfo ok "smOS essentials - Reflashing flag set"
      echo "Migrating to msOS ..." >> /var/tmp/screen.miner.log
    fi
    # hive
    if [[ -f /etc/apt/sources.list.d/hiverepo.list ]]; then
      SYSTEM="hive"
      printfo info "Detected system [HiveOS]"
      export PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/sbin:/usr/local/bin:$PATH"
      miner stop >/dev/null 2>&1
      autoswitch stop >/dev/null 2>&1
      autofan stop >/dev/null 2>&1
      systemctl stop hive-watchdog >/dev/null 2>&1
      systemctl stop hivex >/dev/null 2>&1
      sleep 2
      killall xinit >/dev/null 2>&1
      printfo ok "Hive essentials - Services stopped"
    fi

    # Turning off swap space, in case enabled
    swapoff -a

    # Flush cache to free up memory before migration
    sync; echo 3 > /proc/sys/vm/drop_caches

    # Unmount and remove existing mounts
    if [[ -d "$FR" ]]; then
      sudo umount -f $FR/dev > /dev/null 2>&1
      sudo umount -f  $FR/sys > /dev/null 2>&1
      sudo umount -f  $FR/proc > /dev/null 2>&1
      sudo umount -f $FR > /dev/null 2>&1
      sudo rm -rf $FR > /dev/null 2>&1
    fi

    # Remount main drive as rw
    sudo mount -f -o remount,rw / > /dev/null 2>&1

    # Create Virtual filesystem
    sudo mkdir $FR > /dev/null 2>&1
    sudo mount -t tmpfs -o rw,size=3800M tmpfs $FR > /dev/null 2>&1

    # Create VFS folders
    mkdir $FR/proc $FR/sys $FR/dev $FR/usr $FR/run $FR/var $FR/bin $FR/sbin $FR/lib $FR/tmp $FR/usr $FR/opt > /dev/null 2>&1
    mkdir $FR/usr/lib $FR/usr/lib/x86_64-linux-gnu $FR/usr/share $FR/usr/sbin $FR/lib/lsb $FR/lib/x86_64-linux-gnu > /dev/null 2>&1

    # Copy VFS essentials
    cp -aR /dev $FR > /dev/null 2>&1
    cp -aR /bin $FR > /dev/null 2>&1
    cp -aR /sbin $FR > /dev/null 2>&1
    cp -aR /etc $FR > /dev/null 2>&1
    cp -aR /usr/sbin $FR/usr > /dev/null 2>&1
    cp -aR /usr/bin $FR/usr > /dev/null 2>&1
    cp -aR /lib64 $FR > /dev/null 2>&1
    cp -aR /lib/x86_64-linux-gnu $FR/lib > /dev/null 2>&1
    cp -aR /usr/lib/sudo $FR/usr/lib > /dev/null 2>&1
    cp -aR /usr/lib/ssl $FR/usr/lib > /dev/null 2>&1
    cp -aR /usr/lib/tar $FR/usr/lib > /dev/null 2>&1
    cp -a /usr/lib/x86_64-linux-gnu/libsigsegv* $FR/usr/lib/x86_64-linux-gnu > /dev/null 2>&1
    cp -a /usr/lib/x86_64-linux-gnu/liblz4* $FR/usr/lib/x86_64-linux-gnu > /dev/null 2>&1
    cp -a /usr/lib/x86_64-linux-gnu/libstdc++* $FR/usr/lib/x86_64-linux-gnu > /dev/null 2>&1

    # copy migrate script
    cp $DIR/migrate.sh $FR/opt
    chmod 777 $FR/opt/migrate.sh

    # rebind for chroot
    mount --rbind /proc  $FR/proc
    mount --rbind /sys   $FR/sys
    mount --rbind /dev   $FR/dev

    # building config
    echo "SYSTEM=$SYSTEM" >  $FR/opt/config.txt
    echo "BOOT_DISK=$BOOT_DISK" >> $FR/opt/config.txt
    echo "ACCESS_KEY=$ACCESS_KEY" >> $FR/opt/config.txt
    echo "WORKERNAME=$WORKERNAME" >> $FR/opt/config.txt

    # Select method or use method to get the .img/.zip/.xz file
    if [[ "$FILE" != "samba" ]]; then
      if [[ "$IS_ONLINE" = "YES" ]]; then
        image_web
      else
        printfo fail "No IPv4 connection. Closing down"
        exit
      fi
    else
      printfo info "Attempting to download OS from local share"
      printfo info "/mnt/samba/$SMB_FILE > > > $FR/opt/image.zip"
      cp /mnt/samba/$SMB_FILE $FR/opt/image.zip
      printfo ok "/mnt/samba/$SMB_FILE > > > $FR/opt/image.zip"
      FILE="samba"
    fi

    # Write to disk the current changes
    sync

    # Enter chroot
    cd $FR
    exec chroot . /bin/bash /opt/migrate.sh
  else
    printfo fail "Select msOS version and method to install"
    help
    exit
  fi
else
  #
  # Inside Virtual filesystem flashing
  #
  printfo info "Entered to VFS (chroot)"
  printfo info "Attempting to read config file"

  SYSTEM=$(cat /opt/config.txt 2>/dev/null | grep "SYSTEM=" | head -n1 | xargs | sed 's/^[^=]*=//' | xargs)
  BOOT_DISK=$(cat /opt/config.txt 2>/dev/null | grep "BOOT_DISK=" | head -n1 | xargs | sed 's/^[^=]*=//' | xargs)
  ACCESS_KEY=$(cat /opt/config.txt 2>/dev/null | grep "ACCESS_KEY=" | head -n1 | xargs | sed 's/^[^=]*=//' | xargs)
  WORKERNAME=$(cat /opt/config.txt 2>/dev/null | grep "WORKERNAME=" | head -n1 | xargs | sed 's/^[^=]*=//' | xargs)

  if [ -z "$SYSTEM" ]; then
    SYSTEM="unknown"
    printfo warn "System not detected. If flash is failing then reflashing will be required."
  fi

  if [ -z "$BOOT_DISK" ]; then
    printfo fail "Boot disk not detected, unable to flash the target."
    exit
  fi

  if [ ! -z "$ACCESS_KEY" ]; then
    printfo ok "Found Key:    $ACCESS_KEY"
  fi

  if [ ! -z "$WORKERNAME" ]; then
    printfo ok "Found Worker: $WORKERNAME"
  fi

  function flash {
    # unzip and dd, maybe add log tracking too 2> /opt/error_log
    printfo info "Starting flashing process ..."
    printfo info "Please wait, the process can take up to 30 minutes."

    ECODE="0"

    CHECK=$(dd --help | grep -C 10 "status" | grep -c "progress")
    if [[ "$CHECK" -gt 0 ]]; then
      printfo info "Flashing started [with status=progress] ..."
      unzip -p /opt/image.zip | dd status=progress of=$BOOT_DISK bs=1M
      ECODE=$?
    else
      printfo info "Flashing started [without status=progress] ..."
      unzip -p /opt/image.zip | dd of=$BOOT_DISK bs=1M > /opt/flash_log
      ECODE=$?
    fi

    FLASH_LOG=$(cat /opt/flash_log 2>/dev/null)
    if [[ ! -z "$FLASH_LOG" ]]; then
      printfo info "Flash finished. Logs below"
      echo $FLASH_LOG
    fi
    if [[ "$ECODE" != "0" ]]; then
      printfo warn "Debug: Exit code [$ECODE]"
    fi

  }

  if [[ -f "/opt/image.zip" ]]; then
    flash
    play 5
  else
    printfo fail "msOS image not found"
    printfo info "Something went wrong during download, reboot the system and try again"
    exit
  fi

  # Validate flash manage configs and partitions
  # Fix protective MBR and make valid GPT tables
  printfo info "Reloading partition table"
  partprobe $BOOT_DISK > /dev/null 2>&1
  printfo info "Moving second header to end of disk"
  (
    echo w
    echo Y
  ) | sudo gdisk $BOOT_DISK > /dev/null 2>&1
  #Alter partition table
  printfo info "Recomputing CHS values in protective/hybrid MBR"
  (
    echo w
  ) | sudo fdisk $BOOT_DISK > /dev/null 2>&1
  # Load new partition map
  partprobe $BOOT_DISK > /dev/null 2>&1
  printfo ok "Reloaded partition table"
  #growpart $BOOT_DISK
  #resize2fs $BOOT_DISK
  # echo out new partition map
  printfo info "New disk map below"
  echo
  fdisk -l $BOOT_DISK 2>/dev/null | grep "$BOOT_DISK"
  echo

  # Config editing
  if [[ ! -z "$ACCESS_KEY" ]] && [[ ! -z "$WORKERNAME" ]]; then
    printfo info "Attempting to write previous minerstat configuration"
    # create folder for new mount point
    mkdir /opt/mnt
    # check current partition for config file and mount it
    CONFIG_PART=$(fdisk -l $BOOT_DISK 2>/dev/null | grep "$BOOT_DISK" | grep "basic data" | head -n1 | awk '{print $1}' | xargs)
    printfo info "Detected config partition on new flash [$CONFIG_PART]"
    mount /dev/sda2 /opt/mnt
    sleep 1
    if [[ -f "/opt/mnt/config.js" ]]; then
      printfo ok "Config file exists on newly mounted partition."
      cat /opt/mnt/config.js 2>/dev/null
      echo
      mount -o remount,rw $CONFIG_PART /opt/mnt
      sleep 1
      sudo echo global.accesskey = '"'$ACCESS_KEY'";' > /opt/mnt/config.js
      mount -o remount,rw $CONFIG_PART /opt/mnt
      sudo echo global.worker = '"'$WORKERNAME'";' >> /opt/mnt/config.js
      sleep 1
      printfo info "Validating newly created config file."
      VALIDATEC=$(cat /opt/mnt/config.js 2>/dev/null | grep -c "$ACCESS_KEY")
      if [[ "$VALIDATEC" -gt 0 ]]; then
        printfo ok "Config file successfully edited to $WORKERNAME [$ACCESS_KEY]"
      else
        printfo fail "Something went wrong. Use Discovery function to add worker after reboot."
      fi
    else
      printfo fail "Config file not found on the partition. Use Discovery function to add worker after reboot."
    fi
  fi

  # Save changes to disk
  sync

  # Force reboot
  printfo info "Automatic reboot in 15 seconds ..."
  sleep 15
  printfo warn "Rebooting ..."
  echo 1 > /proc/sys/kernel/sysrq
  # (*S*nc) Sync all cached disk operations to disk
  #sudo echo s > /proc/sysrq-trigger
  echo b > /proc/sysrq-trigger

fi

echo
