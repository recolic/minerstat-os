#!/bin/bash
#exec 2>/dev/null

if [ ! $1 ]; then
  echo ""
  echo "--- EXAMPLE ---"
  echo "./overclock_navi.sh 1 2 3 4 5 6 7"
  echo "1 = GPUID"
  echo "2 = Memory Clock"
  echo "3 = Core Clock"
  echo "4 = Fan Speed"
  echo "5 = VDDC"
  echo "6 = MVDD"
  echo "7 = VDDCI"
  echo ""
  echo "-- Full Example --"
  echo "./overclock_navi.sh 0 875 1300 70 800 1250 825"
  echo ""
fi

if [ $1 ]; then

  #################################£
  # Declare
  GPUID=$1
  MEMCLOCK=$2
  CORECLOCK=$3
  FANSPEED=$4
  VDDC=$5
  MVDD=$6
  COREINDEX=$7
  VDDCI=$8
  POWERLIMIT=$9
  SOC=${10}
  version=`cat /etc/lsb-release | grep "DISTRIB_RELEASE=" | sed 's/[^.0-9]*//g'`

  # Setting up limits
  MCMIN=670  #minimum vddci
  MCMAX=850  #max vddci
  MVMIN=1250 #minimum mvdd
  MVMAX=1350 #max mvdd
  #MCDEF=820  #default vddci
  #MVDEF=1300 #default mvdd
  SOCMIN=507
  SOCMAX=1267

  # Check Python3 PIP
  CHECKPY=$(dpkg -l | grep python3-pip)
  if [[ -z $CHECKPY ]]; then
    sudo apt-get update
    sudo apt-get -y install python3-pip --fix-missing
    sudo su minerstat -c "pip3 install setuptools"
    sudo su minerstat -c "pip3 install git+https://labs.minerstat.farm/repo/upp"
    sudo su -c "pip3 install git+https://labs.minerstat.farm/repo/upp"
  fi

  # Check UPP installed
  FILE=/home/minerstat/.local/bin/upp
  if [ -f "$FILE" ]; then
    echo "UPP exists."
  else
    sudo su minerstat -c "pip3 install setuptools"
    sudo su minerstat -c "pip3 install git+https://labs.minerstat.farm/repo/upp"
    sudo su -c "pip3 install git+https://labs.minerstat.farm/repo/upp"
  fi

  if [ -z "$COREINDEX" ]; then
    COREINDEX="2"
  fi

  if [ "$COREINDEX" = "skip" ]; then
    COREINDEX="2"
  fi

  if [ "$COREINDEX" = "5" ]; then
    COREINDEX="2"
  fi

  if [ "$version" = "1.4" ] || [ "$version" = "1.4.5" ] || [ "$version" = "1.4.6" ] || [ "$version" = "1.4.7" ] || [ "$version" = "1.4.8" ] || [ "$version" = "1.5.3" ] || [ "$version" = "1.4.9" ] || [ "$version" = "1.5.2" ]; then
    if [ "$COREINDEX" = "1" ]; then
      COREINDEX="2"
    fi
  fi

  #for fid in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
  #  TEST=$(cat "/sys/class/drm/card$GPUID/device/hwmon/hwmon$fid/pwm1_max" 2>/dev/null)
  #  if [ ! -z "$TEST" ]; then
  #    MAXFAN=$TEST
  #  fi
  #done
  MAXFAN="255"
  RPMMIN=$(cat /sys/class/drm/card$GPUID/device/hwmon/hwmon*/fan1_min)
  RPMMAX=$(cat /sys/class/drm/card$GPUID/device/hwmon/hwmon*/fan1_max)
  RPMVAL="0"

  # FANS
  if [ "$FANSPEED" != 0 ]; then
    FANVALUE=$(echo - | awk "{print $MAXFAN / 100 * $FANSPEED}" | cut -f1 -d".")
    FANVALUE=$(printf "%.0f\n" $FANVALUE)
    FANVALUE=$(awk -v n="$FANVALUE" 'BEGIN{print int((n+5)/10) * 10}')

    RPMVAL=$(echo - | awk "{print $RPMMAX / 100 * $FANSPEED}" | cut -f1 -d".")
    RPMVAL=$(printf "%.0f\n" $RPMVAL)
    RPMVAL=$(awk -v n="$RPMVAL" 'BEGIN{print int((n+5)/10) * 10}')

    echo "GPU$GPUID : FANSPEED => $FANSPEED% ($FANVALUE) [RPM: $RPMVAL]"
  else
    FANVALUE=$(echo - | awk "{print $MAXFAN / 100 * 70}" | cut -f1 -d".")
    FANVALUE=$(printf "%.0f\n" $FANVALUE)

    RPMVAL=$(echo - | awk "{print $RPMMAX / 100 * 70}" | cut -f1 -d".")
    RPMVAL=$(printf "%.0f\n" $RPMVAL)
    RPMVAL=$(awk -v n="$RPMVAL" 'BEGIN{print int((n+5)/10) * 10}')

    echo "GPU$GPUID : FANSPEED => 70% ($FANVALUE) [RPM: $RPMVAL]"
  fi

  if [[ $FANVALUE -gt $MAXFAN ]]; then
    FANVALUE=$MAXFAN
  fi

  echo "--**--**-- GPU $1 : NAVI --**--**--"

  # Compare user input and apply min/max
  if [[ ! -z $VDDCI && $VDDCI != "0" && $VDDCI != "skip" ]]; then
    PARSED_VDDCI=$VDDCI
    if [[ $VDDCI -gt $MCMAX ]]; then
      PARSED_VDDCI=$MCMAX
    fi
    if [[ $VDDCI -lt $MCMIN ]]; then
      PARSED_VDDCI=$MCMIN
      # Ignore if set below limit
      echo "VDDCI value ignored as below $MCMIN mV limit"
    else
      AVDDCI=$((PARSED_VDDCI * 4)) #actual
      pvddci="smc_pptable/MemVddciVoltage/1=$AVDDCI smc_pptable/MemVddciVoltage/2=$AVDDCI smc_pptable/MemVddciVoltage/3=$AVDDCI"
    fi
  fi

  if [[ ! -z $MVDD && $MVDD != "0" && $MVDD != "skip" ]]; then
    PARSED_MVDD=$MVDD
    if [[ $MVDD -gt $MVMAX ]]; then
      PARSED_MVDD=$MVMAX
    fi
    if [[ $MVDD -lt $MVMIN ]]; then
      PARSED_MVDD=$MVMIN
      # Ignore if set below limit
      echo "MVDD value ignored as below $MVMIN mV limit"
    else
      AMVDD=$((PARSED_MVDD * 4)) #actual
      pmvdd="smc_pptable/MemMvddVoltage/1=$AMVDD smc_pptable/MemMvddVoltage/2=$AMVDD smc_pptable/MemMvddVoltage/3=$AMVDD"
    fi
  fi

  if [[ ! -z $SOC && $SOC != "0" && $SOC != "skip" ]]; then
    PARSED_SOC=$SOC
    if [[ $SOC -gt $SOCMAX ]]; then
      PARSED_SOC=950
      echo "SoC can't be higher than $SOCMAX using safe value 950"
    fi
    if [[ $SOC -lt $SOCMIN ]]; then
      PARSED_SOC=$SOCMIN
      # Ignore if set below limit
      echo "SOCCLK value ignored as below $SOCMIN Mhz limit"
    else
      psoc="smc_pptable/FreqTableSocclk/0=$PARSED_SOC smc_pptable/FreqTableSocclk/1=$PARSED_SOC smc_pptable/FreqTableSocclk/2=$PARSED_SOC smc_pptable/FreqTableSocclk/3=$PARSED_SOC smc_pptable/FreqTableSocclk/4=$PARSED_SOC smc_pptable/FreqTableSocclk/5=$PARSED_SOC smc_pptable/FreqTableSocclk/6=$PARSED_SOC smc_pptable/FreqTableSocclk/7=$PARSED_SOC"
    fi
  fi

  if [ "$version" = "1.5.4" ]; then
    echo "To enable PP_Table unlock flash to v1.6 or higher"
  else

    # Target temp
    FILE=/media/storage/fans.txt
    TT=50
    if [ -f "$FILE" ]; then
      TARGET=$(cat /media/storage/fans.txt | grep "TARGET_TEMP=" | xargs | sed 's/[^0-9]*//g')
      if [[ ! -z "$TARGET" ]]; then
        TT=$TARGET
        echo "NAVI Fan Curve Target: $TT"
      else
        TT=50
      fi
    else
      TT=50
    fi

    sudo rm /dev/shm/safetycheck.txt &> /dev/null
    sudo /home/minerstat/.local/bin/upp -p /sys/class/drm/card$GPUID/device/pp_table get smc_pptable/MinVoltageGfx &> /dev/shm/safetycheck.txt
    # Reinstall upp if error
    SAFETY=$(cat /dev/shm/safetycheck.txt)
    if [[ $SAFETY == *"has no attribute"* ]] || [[ $SAFETY == *"ModuleNotFoundError"* ]] || [[ $SAFETY == *"table version"* ]]; then
      sudo su minerstat -c "yes | sudo pip3 uninstall setuptools"
      sudo su minerstat -c "yes | sudo pip3 uninstall click"
      sudo su minerstat -c "yes | sudo pip3 uninstall upp"
      sudo su -c "yes | sudo pip3 uninstall upp"
      sudo su minerstat -c "pip3 install setuptools"
      sudo su minerstat -c "pip3 install git+https://labs.minerstat.farm/repo/upp"
      sudo su -c "pip3 install git+https://labs.minerstat.farm/repo/upp"
    fi

    sudo /home/minerstat/.local/bin/upp -p /sys/class/drm/card$GPUID/device/pp_table set \
      overdrive_table/max/8=960 overdrive_table/min/3=650 overdrive_table/min/5=650 overdrive_table/min/7=650 smc_pptable/MinVoltageGfx=2600 \
      smc_pptable/FanTargetTemperature=$TT smc_pptable/FanThrottlingRpm=3000 $pmvdd $pvddci $psoc \
      smc_pptable/FanStopTemp=0 smc_pptable/FanStartTemp=0 smc_pptable/FanZeroRpmEnable=0 --write
  fi

  # Apply powerlimit
  if [[ ! -z "$POWERLIMIT" ]] && [[ "$POWERLIMIT" != "skip" ]] && [[ "$POWERLIMIT" != "pwrskip" ]] && [[ "$POWERLIMIT" != "pwrSkip" ]] && [[ $POWERLIMIT == *"pwr"* ]]; then
    POWERLIMIT=$(echo $POWERLIMIT | sed 's/[^0-9]*//g')
    if [[ ! -z "$POWERLIMIT" ]] && [[ "$POWERLIMIT" != "0" ]]; then
      # Navi limits (default 180)
      PW_MIN=$((80 * 1000000))
      PW_MAX=$((250 * 1000000))
      # CONVERT
      CNV=$(($POWERLIMIT * 1000000))
      if [[ $CNV -lt $PW_MIN ]]; then
        echo "ERROR: New power limit not set, because less than allowed minimum $PW_MIN"
      else
        if [[ $CNV -lt $PW_MAX ]]; then
          FROM=$(cat /sys/class/drm/card$GPUID/device/hwmon/hwmon*/power1_cap)
          echo "Changing power limit from $FROM W to $CNV W"
          sudo su -c "echo $CNV > /sys/class/drm/card$GPUID/device/hwmon/hwmon*/power1_cap"
        else
          echo "ERROR: New power limit not set, because more than allowed maximum $PW_MAX"
        fi
      fi
    fi
  fi

  TESTD=$(timeout 5 dpkg -l | grep opencl-amdgpu-pro-icd | head -n1 | awk '{print $3}' | xargs | cut -f1 -d"-")

  if [ -z "$TESTD" ]; then
    TESTD=$(timeout 5 dpkg -l | grep amdgpu-pro-rocr-opencl | head -n1 | awk '{print $3}' | xargs | cut -f1 -d"-")
  fi

  # Disable fans this will ramp up RPM to max
  echo "Waiting for fans 2 second as new pptable just got applied"
  sudo su -c "echo 0 > /sys/class/drm/card$GPUID/device/hwmon/hwmon*/pwm1_enable" 2>/dev/null
  sudo su -c "echo 0 > /sys/class/drm/card$GPUID/device/hwmon/hwmon*/fan1_enable" 2>/dev/null
  sleep 2

  if [ "$TESTD" = "20.30" ] || [ "$TESTD" = "20.40" ] || [ "$TESTD" = "20.45" ] || [ "$TESTD" = "20.50" ]; then

    # Enable fan and manual control
    sudo su -c "echo 1 > /sys/class/drm/card$GPUID/device/hwmon/hwmon*/pwm1_enable" 2>/dev/null
    sudo su -c "echo 1 > /sys/class/drm/card$GPUID/device/hwmon/hwmon*/fan1_enable" 2>/dev/null

    sudo timeout 5 /home/minerstat/minerstat-os/bin/rocm-smi --setfan $FANVALUE -d $GPUID
    sudo su -c "echo 1 > /sys/class/drm/card$GPUID/device/hwmon/hwmon*/pwm1_enable" 2>/dev/null
    sudo su -c "echo $FANVALUE > /sys/class/drm/card$GPUID/device/hwmon/hwmon*/pwm1" 2>/dev/null # 70%
    sudo rm /dev/shm/fantype.txt 2>/dev/null

    if [[ "$version" = "1.7.4" ]] || [[ "$version" = "1.7.3" ]] || [[ "$version" = "1.7.2" ]] || [[ "$version" = "1.7.1" ]] || [[ "$version" = "1.7.0" ]]; then

      RB=$(cat /sys/class/drm/card$GPUID/device/hwmon/hwmon*/pwm1 | xargs)
      echo "Reading back fan value .. $RB"
      if [[ "$RB" = "0" ]]; then
        # RPM KICK
        echo "RPM KICK Method $RB"
        sudo su -c "echo 1 > /sys/class/drm/card$GPUID/device/hwmon/hwmon*/fan1_enable" 2>/dev/null
        sudo su -c "echo $RPMVAL > /sys/class/drm/card$GPUID/device/hwmon/hwmon*/fan1_target" 2>/dev/null
        sleep 2
      fi

      sleep 2

      RB=$(cat /sys/class/drm/card$GPUID/device/hwmon/hwmon*/pwm1 | xargs)
      echo "Reading back fan value .. $RB"
      if [[ "$RB" = "0" ]]; then
        echo "2" > /dev/shm/fantype.txt
        echo "Driver autofan kick .."
        sleep 1
        sudo su -c "echo 2 > /sys/class/drm/card$GPUID/device/hwmon/hwmon*/pwm1_enable" 2>/dev/null
        sleep 1
        sudo su -c "echo 1 > /sys/class/drm/card$GPUID/device/hwmon/hwmon*/pwm1_enable" 2>/dev/null
        sleep 1
        sudo su -c "echo 2 > /sys/class/drm/card$GPUID/device/hwmon/hwmon*/pwm1_enable" 2>/dev/null
        sleep 1
      else
        sudo rm /dev/shm/fantype.txt 2>/dev/null
      fi

      RB=$(cat /sys/class/drm/card$GPUID/device/hwmon/hwmon*/pwm1 | xargs)
      if [[ "$RB" = "0" ]]; then
        # 100% fans
        echo "Nothing worked 100% fans then auto"
        sudo su -c "echo 0 > /sys/class/drm/card$GPUID/device/hwmon/hwmon*/pwm1_enable" 2>/dev/null
        sleep 1
        sudo su -c "echo 2 > /sys/class/drm/card$GPUID/device/hwmon/hwmon*/pwm1_enable" 2>/dev/null
      fi

    fi

  else
    echo "2" > /dev/shm/fantype.txt
    sudo su -c "echo 2 > /sys/class/drm/card$GPUID/device/hwmon/hwmon*/pwm1_enable" 2>/dev/null
    sudo su -c "echo 1 > /sys/class/drm/card$GPUID/device/hwmon/hwmon*/pwm1_enable" 2>/dev/null
    sudo su -c "echo 255 > /sys/class/drm/card$GPUID/device/hwmon/hwmon*/pwm1" 2>/dev/null # 70%
  fi

  #if [ "$FANSPEED" = "100" ]; then
  #  echo "2" > /dev/shm/fantype.txt
  #  sudo su -c "echo 2 > /sys/class/drm/card$GPUID/device/hwmon/hwmon*/pwm1_enable" 2>/dev/null
  #  sudo su -c "echo 1 > /sys/class/drm/card$GPUID/device/hwmon/hwmon*/pwm1_enable" 2>/dev/null
  #  sudo su -c "echo 255 > /sys/class/drm/card$GPUID/device/hwmon/hwmon*/pwm1" 2>/dev/null # 70%
  #fi

  # Requirements
  sudo su -c "echo manual > /sys/class/drm/card$GPUID/device/power_dpm_force_performance_level"
  sudo su -c "echo 5 > /sys/class/drm/card$GPUID/device/pp_power_profile_mode"

  # CoreClock
  if [ "$VDDC" = "0" ] || [ "$VDDC" = "skip" ] || [ -z "$VDDC" ]; then
    VDDC="850"
  fi

  #if [ "$MVDD" = "0" ] || [ "$MVDD" = "skip" ] || [ -z "$MVDD" ]; then
  #  MVDD="1350"
  #fi

  # MemoryClock
  if [ "$MEMCLOCK" != "skip" ]; then
    # Auto fix Windows Clocks to linux ones
    # Windows is memclock * 2
    if [[ $MEMCLOCK -gt "1001" ]]; then
      echo "!! MEMORY CLOCK CONVERTED TO LINUX FORMAT [WINDOWS_MEMCLOCK/2]"
      MEMCLOCK=$((MEMCLOCK/2))
    fi
    if [[ $MEMCLOCK -gt "960" ]]; then
      echo "!! Invalid memory clock detected, auto fixing.."
      echo "Maximum recommended clock atm 950Mhz (Windows: 950*2 = 1900Mhz)"
      echo "You have set $MEMCLOCK Mhz reducing back to 950Mhz"
      MEMCLOCK=940
    fi
    echo "GPU$GPUID : MEMCLOCK => $MEMCLOCK Mhz"
    sudo /home/minerstat/minerstat-os/bin/msos_od_clk $GPUID "m 1 $MEMCLOCK"
    sudo /home/minerstat/minerstat-os/bin/msos_od_clk $GPUID "m 2 $MEMCLOCK"
    sudo /home/minerstat/minerstat-os/bin/msos_od_clk $GPUID "m 3 $MEMCLOCK"

    sudo su -c "echo '0' > /sys/class/drm/card$GPUID/device/pp_mclk_od"
    sudo su -c "echo '1' > /sys/class/drm/card$GPUID/device/pp_mclk_od"

    sudo su -c "echo 2 > /sys/class/drm/card$GPUID/device/pp_dpm_mclk"
    sudo su -c "echo 1 > /sys/class/drm/card$GPUID/device/pp_dpm_mclk"
    sudo /home/minerstat/minerstat-os/bin/msos_od_clk $GPUID "c"

  fi

  if [ "$VDDC" != "skip" ]; then
    if [ "$CORECLOCK" != "skip" ]; then
      if [ "$version" = "1.5.4" ]; then
        if [ "$VDDC" -lt "800" ]; then
          echo "Driver accept VDDC range until 800mV, you have set $VDDC and it got adjusted to 800mV"
          echo "You can set Core State 1 or Core State 2 for lower voltages or flash to v1.6 or higher where lowest possible value is 700mv"
          VDDC=800
        fi
      else
        if [ "$VDDC" -lt "649" ]; then
          echo "Driver accept VDDC range until 650mV, you have set $VDDC and it got adjusted to 800mV"
          echo "You can set Core State 1 or Core State 2 for lower voltages"
          VDDC=800
        fi
      fi

      echo "GPU$GPUID : CORECLOCK => $CORECLOCK Mhz ($VDDC mV, state: $COREINDEX)"

      sudo /home/minerstat/minerstat-os/bin/msos_od_clk $GPUID "s 1 $CORECLOCK"
      sudo /home/minerstat/minerstat-os/bin/msos_od_clk $GPUID "vc 2 $CORECLOCK $VDDC"

      sudo su -c "echo '0' > /sys/class/drm/card$GPUID/device/pp_sclk_od"
      sudo su -c "echo '1' > /sys/class/drm/card$GPUID/device/pp_sclk_od"

      sudo su -c "echo 1 > /sys/class/drm/card$GPUID/device/pp_dpm_sclk"
      sudo su -c "echo 2 > /sys/class/drm/card$GPUID/device/pp_dpm_sclk"

    fi
  fi

  ###########################################################################
  if [ "$version" = "1.4" ] || [ "$version" = "1.4.5" ] || [ "$version" = "1.4.6" ] || [ "$version" = "1.4.7" ] || [ "$version" = "1.4.8" ]; then
    sudo su -c "echo '1' > /sys/class/drm/card$GPUID/device/pp_dpm_sclk"
    sudo su -c "echo '3' > /sys/class/drm/card$GPUID/device/pp_dpm_mclk"
  fi
  #if [ "$version" = "1.5.3" ]; then
  #  sudo su -c "echo '2' > /sys/class/drm/card$GPUID/device/pp_dpm_sclk"
  #  sudo su -c "echo '3' > /sys/class/drm/card$GPUID/device/pp_dpm_mclk"
  #fi
  ##########################################################################

  # Apply Changes
  sudo su -c "echo '1' > /sys/class/drm/card$GPUID/device/pp_dpm_mclk"
  sudo su -c "echo '2' > /sys/class/drm/card$GPUID/device/pp_dpm_mclk"
  sudo su -c "echo '3' > /sys/class/drm/card$GPUID/device/pp_dpm_mclk"
  sudo /home/minerstat/minerstat-os/bin/msos_od_clk $GPUID "c"


  sudo su -c "echo '1' > /sys/class/drm/card$GPUID/device/pp_dpm_mclk"
  sudo su -c "echo '2' > /sys/class/drm/card$GPUID/device/pp_dpm_mclk"
  sleep 0.25
  sudo su -c "echo '3' > /sys/class/drm/card$GPUID/device/pp_dpm_mclk"

  # ECHO Changes
  echo "-÷-*-****** CORE CLOCK *****-*-*÷-"
  sudo su -c "cat /sys/class/drm/card$GPUID/device/pp_dpm_sclk"
  echo "-÷-*-****** MEM  CLOCKS *****-*-*÷-"
  sudo su -c "cat /sys/class/drm/card$GPUID/device/pp_dpm_mclk"

  exit 1

fi
