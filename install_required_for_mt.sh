#!/bin/bash

########################################
# Setup shell/environment variables
########################################

VNC_PASSWORD=123123

IS_SYSTEMD=$(which systemctl)
ABS_PWD=$(cd "$(dirname "$BASH_SOURCE")"; pwd)
ORG_USER=${SUDO_USER:-$USER}
DIR_WINECACHE=$HOME/.cache/wine

export WINEARCH=win32
export WINEDEBUG=-all,err+all
export WINEPREFIX=$HOME/.wine
export DISPLAY=:1

export DEBIAN_FRONTEND=noninteractive

. /etc/os-release

if [ -z "$VERSION_CODENAME" ]; then
  VERSION_CODENAME=`echo -n $VERSION | tr '[A-Z]' '[a-z]' | grep -Eo 'artful|bionic|cosmic|precise|trusty|xenial|yakkety|zesty|jessie|stretch|buster'`
fi

WINE_REPOS="deb https://dl.winehq.org/wine-builds/$ID/ $VERSION_CODENAME main"

########################################
# Creating directories
########################################

mkdir -p "$DIR_WINECACHE"

########################################
# Setup root crontab
########################################

# For old OpenVZ kernel. SSHD doesn't start after updating systemd without this.

cron_line=$(sudo bash -c "crontab -l 2>/dev/null" | grep -o "mkdir -p -m0755 /var/run/sshd")

if [ -z "$cron_line" ]; then
  sudo bash -c "cat <(crontab -l) <(echo '@reboot if [ ! -e /var/run/sshd  ]; then mkdir -p -m0755 /var/run/sshd; fi') | crontab"
fi

########################################
# Creating ~/.bash_profile if needed
########################################

BASH_PROFILE=$HOME/.bash_profile
if [ ! -f $BASH_PROFILE ] || [ -z "`cat $BASH_PROFILE | grep -o WINEARCH`" ]; then

  # write WINE param to the .bash_profile
  cat << EOS >> $BASH_PROFILE

export WINEARCH=$WINEARCH
export WINEDEBUG=$WINEDEBUG
export WINEPREFIX=$WINEPREFIX
export DISPLAY=$DISPLAY

if [ -e \$HOME/.bashrc ]; then
  . \$HOME/.bashrc
fi
EOS
fi


########################################
# Creating swap space if needed
########################################

# For vps which don't have swap such as GCE f1-micro.
# Create swap space and enable swap unless OpenVZ

swap_total=`cat /proc/meminfo | grep -i swaptotal | tr -s " " | cut -d' ' -f'2'`

if [ ! -e /proc/user_beancounters ] && [ "$swap_total" == "0" ]; then
  echo make 1024 MB swap file. please wait for few minutes.
  sudo dd if=/dev/zero of=/swapfile bs=1M count=1024
  sudo chmod 600 /swapfile
  sudo mkswap -f /swapfile
  sudo swapon /swapfile

  if [ $? -ne 0 ] ;then
    echo swapon faild. continue without swap.
    sudo rm /swapfile
  else
    sudo bash -c 'echo -e "/swapfile\tswap\tswap\tdefaults\t0\t0" >> /etc/fstab'
  fi
fi

########################################
# Upgrade existing packages
########################################

# upgrade packages.
sudo apt update
sudo apt -y -f install
sudo apt -y upgrade

########################################
# Install and setup Japanese locale, Timezone
########################################

sudo apt -y install dbus

# setting local and timezone.
sudo apt -y install tzdata

if [ "$ID" == "debian" ]; then
  # for debian
  sudo apt -y install task-japanese locales
  sudo bash -c 'echo "ja_JP.UTF-8 UTF-8" > /etc/locale.gen'
else
  sudo apt -y install language-pack-ja
fi

sudo locale-gen
sudo update-locale LANG=ja_JP.UTF-8
sudo timedatectl set-timezone Asia/Tokyo

export LANG=ja_JP.UTF-8

#####################################################
# Install packages required by MetaTrader
#####################################################

# install misc
sudo apt -y install apt-transport-https psmisc vim nano less tmux curl net-tools lsof

# install gui
sudo apt -y install vnc4server fonts-vlgothic xterm wm2

# install wine
sudo apt -y install software-properties-common
sudo dpkg --add-architecture i386
wget -q -nc -P "$DIR_WINECACHE" https://dl.winehq.org/wine-builds/winehq.key
sudo apt-key add "$DIR_WINECACHE/winehq.key"
sudo apt-add-repository "$WINE_REPOS"
sudo apt -y update
sudo apt -y install --install-recommends winehq-devel

#####################################################
# Setup VNC server (seup only. not start service here)
#####################################################

if [ -n "$IS_SYSTEMD" ]; then
    # for systemd
    echo Registering VNC Server as systemd service.

    if [ ! -f "/etc/systemd/system/vncserver@:1.service" ]; then
      sudo install -o root -g root -m 644 -D "$ABS_PWD/vncserver@:1.service" "/etc/systemd/system/vncserver@:1.service"
      sudo sed -i -e 's/%%USER_NAME%%/'$ORG_USER'/g' "/etc/systemd/system/vncserver@:1.service"
    fi

    sudo systemctl enable "vncserver@:1.service"
else
    # for upstart
    echo Registering VNC Server as upstart service.

    if [ ! -f "/etc/init.d/vncserver" ]; then
      sudo install -o root -g root -m 644 -D "$ABS_PWD/vncserver_for_upstart" "/etc/init.d/vncserver"
      sudo sed -i -e 's/%%USER_NAME%%/'$ORG_USER'/g' "/etc/init.d/vncserver"
      sudo chmod +x /etc/init.d/vncserver
    fi

    sudo update-rc.d vncserver defaults
fi

# setting default password for vncserver
echo 'Setting default VNC password "123123". Please change this yourself later :-)'
echo -e "$VNC_PASSWORD\n$VNC_PASSWORD" | vncpasswd &>/dev/null

#####################################################
# Downlaod Wine-Mono and Wine-Gecko package.
#####################################################

LATEST_MONO=$(curl -s http://dl.winehq.org/wine/wine-mono/ | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | sort -nr | head -n1)
LATEST_GECKO=$(curl -s http://dl.winehq.org/wine/wine-gecko/ | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | sort -nr | head -n1)

MSI_ARCH=x86

if [ "win64" == "$WINEARCH" ]; then
    MSI_ARCH=x86_64
fi

MSI_MONO=wine-mono-$LATEST_MONO.msi
MSI_GECKO=wine_gecko-$LATEST_GECKO-$MSI_ARCH.msi

echo -n Downlaoding mono: $LATEST_MONO ...
wget -q -N -P "$DIR_WINECACHE" "http://dl.winehq.org/wine/wine-mono/$LATEST_MONO/$MSI_MONO"

if [ $? == 0 ]; then
    echo done.
else
    echo failed.
fi

echo -n Downlaoding gecko: $LATEST_GECKO ...
wget -q -N -P "$DIR_WINECACHE" "http://dl.winehq.org/wine/wine-gecko/$LATEST_GECKO/$MSI_GECKO"

if [ $? == 0 ]; then
    echo done.
else
    echo failed.
fi

#####################################################
# Setup Wine
#####################################################

export WINEDEBUG=-all

# initialize wineprefix
echo Initializing wine.. this takes few minutes.
wineserver -kw
wineboot -i
wineserver -w

# setting japanese fonts
fot_replace_exist=$(cat $WINEPREFIX/user.reg | tr -d '\r' | grep -o '\[Software\\\\Wine\\\\Fonts\\\\Replacements\]')
if [ -z "$fot_replace_exist" ]; then
    cat "$ABS_PWD/font_replace.reg" >> "$WINEPREFIX/user.reg"
fi

# install wine-mono and wine-gecko
echo Installing Wine-Mono
wine msiexec /i "$DIR_WINECACHE/$MSI_MONO"

echo Installing Wine-Gecko
wine msiexec /i "$DIR_WINECACHE/$MSI_GECKO"

#####################################################
# Start VNC Server
#####################################################

echo -n Starting VNC Server ...
if [ -n "$IS_SYSTEMD" ]; then
    sudo systemctl start "vncserver@:1"
else
    sudo service vncserver start
fi

if [ $? == "0" ]; then
    echo stared!
else
    echo failed!
fi

#####################################################
# Clean needless files
#####################################################

sudo apt-get -y autoremove
sudo apt-get -y clean
rm "$DIR_WINECACHE/$MSI_MONO"
rm "$DIR_WINECACHE/$MSI_GECKO"
rm "$DIR_WINECACHE/winehq.key"
"$ABS_PWD/minimize_wine.sh"

#####################################################
# Download MT4 and start installer
#####################################################

echo Downloading MetaTrader4 ...
if [ -f "$DIR_WINECACHE/landfx4setup.exe" ]; then
    rm "$DIR_WINECACHE/landfx4setup.exe"
fi

wget -q -N -P "$DIR_WINECACHE" 'https://download.mql5.com/cdn/web/land.prime.ltd/mt4/landfx4setup.exe'

echo Staring MetaTrader4 installer...
WINEDEBUG=-all wine start /unix "$DIR_WINECACHE/landfx4setup.exe"

echo ""
echo "====================================================="
echo "Now MetaTrader4 installer is running on VNC(GUI) !!"
echo "====================================================="
