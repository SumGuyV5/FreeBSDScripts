#!/bin/sh
if [ `whoami` != root ]; then 
  echo "Please run as root"
  exit 1
fi

UPDATE=false

PKG=false
VMWARE=false

HELP=false

KDE=false
GNOME=false
XFCE=false

DIS=false
DISPLAYMAN=gdm

GDM=false
SDDM=false
LIGHTDM=false
NONE=false

SUDO=false
USERS_SUDO=""

BASH=false
USERS_BASH=""

FIREFOX=false

REBOOT=false

OPT=false

while getopts UpvkgxsubfRh option
do
  case "${option}"
  in
  U) UPDATE=true;;
  p) PKG=true;;
  v) VMWARE=true;;
  h) HELP=true;;
  k) KDE=true;;
  g) GNOME=true;;
  g) XFCE=true;;
  s) SUDO=true;;
  u) SUDO=true
    USERS_SUDO=$OPTARG;;
  b) BASH=true;;
  f) FIREFOX=true;;
  R) REBOOT=true;;
  esac
  OPT=true
done

header() {
  HEADER=$1
  STRLENGTH=$(echo -n $HEADER | wc -m)
  DISPLAY="  " #65
  center=`expr $STRLENGTH / 2`
  max=`expr 33 - $center`
  echo $max
  for i in $(seq 1 $max)
  do
    DISPLAY="${DISPLAY}-"    
  done
  DISPLAY="${DISPLAY} "$HEADER" "
  
  STRLENGTH=$(echo -n $DISPLAY | wc -m)
  max=`expr 65 - $STRLENGTH`
  for i in $(seq 1 $max)
  do
    DISPLAY="${DISPLAY}-"
  done
    
  clear
  echo "  =================================================================="
  echo "$DISPLAY"
  echo "  =================================================================="
  echo ""
}

help() {
  header "Help"
  echo "-U flag to update kernel."
  
  echo "-p flag to use pkg default ports are used."
  echo "-v flag to install vmware tools."
  
  echo "-k install KDE."
  echo "-g install Gnome."
  echo "-x install XFCE."
  echo "-d select and install a display manager. GDM(Gnome), SDDM(KDE), LightDM(XFCE). ie -d lightdm will select and install LightDM as your display manager."
  
  
  echo "-f install FireFox."
  echo "-s install sudo."
  echo "-u add users to sudo group. This will install sudo if not already installed. ie -u richard will add user richard to group sudo."
  echo "-b make default users shell bash. This will install bash if not already installed. ie -b richard will set richard's default shell to bash."
  echo "-R Reboots computer after excuting the script."
  echo "-h this help text." 
}

Is_installed() {
  PACKAGE = $1
  RTN = 0
  
  pkg info $PACKAGE
  
  if [ $? = 0 ]; then
    RTN = 1
  fi
    
  return $RTN
}

portsUpdate() {
  if [ -s /usr/ports ] && [ "$(ls -A /usr/ports)" ]; then
  	echo "Files"
  else
  	portsnap fetch extract
  fi
  
  portsnap fetch update
}

update_kernel() {
  if [ $UPDATE = true ]; then
    echo "Updating Kernel."
    #freebsd-update fetch >> /tmp/fetch
    #freebsd-update cron
    freebsd-update install --not-running-from-cron
  fi
}

pkgorports() {
  if [ $PKG = true ]; then
    pkg upgrade
  else
    portsUpdate
  fi
}

kernal_src() {
  if [ "$(ls -A /usr/src)" ]; then
    echo "src all ready download."
  else
    fetch ftp://ftp.freebsd.org/pub/`uname -s`/releases/`uname -m`/`uname -r`/src.txz
  fi
  tar -C / -zxvf src.txz
}

vmware() {
  if [ $VMWARE = true ]; then
    echo "Installing... open-vm-tools."
    echo ""
    if [ $PKG = true ]; then
      echo "pkg install"
      pkg install -y open-vm-tools
      if [ $KDE = true ] || [ $GNOME = true ] || [ $XFCE = true ]; then
        pkg install -y xf86-video-vmware xf86-input-vmmouse
      fi
    else
      kernal_src
      
      cd /usr/ports/emulators/open-vm-tools/
      make -DBATCH install clean
      
      if [ $KDE = true ] || [ $GNOME = true ] || [ $XFCE = true ]; then
        cd /usr/ports/x11-drivers/xf86-video-vmware/
        make -DBATCH install clean
      
        cd /usr/ports/x11-drivers/xf86-input-vmmouse/
        make -DBATCH install clean        
      fi
    fi
        
    sysrc vmware_guest_vmblock_enable="YES"
    sysrc vmware_guest_vmhgfs_enable="YES"
    sysrc vmware_guest_vmmemctl_enable="YES"
    sysrc vmware_guest_vmxnet_enable="YES"
    sysrc vmware_guestd_enable="YES"
  fi
}

xorg_config() {
  Xorg -configure

  cp /root/xorg.conf.new /usr/local/etc/X11/xorg.conf.d/xorg.conf
  
  if [ $XFCE = true ]; then
    #echo "exec /usr/local/bin/startxfce4 --with-ck-launch" > ~/.xinitrc
  else
    sed -i.bak '/proc/d' /etc/fstab

    echo "proc            /proc           procfs  rw      0       0" >> /etc/fstab
  fi
  
  sysrc moused_enable="YES"
  sysrc dbus_enable="YES"
  sysrc hald_enable="YES"
}

xorg_vm() {
  #if open-vm-tools is installed
  pkg info open-vm-tools
  
  if [ $? = 0 ]; then
    if [ -f /usr/local/etc/X11/xorg.conf.d/xorg.conf ]; then
      sed -i.bak '/Option       "AutoAddDevices" "Off"/d' /usr/local/etc/X11/xorg.conf.d/xorg.conf
      
      sed -i.bak 's/Driver      "mouse"/Driver      "vmmouse"/gi' /usr/local/etc/X11/xorg.conf.d/xorg.conf
    
      sed -i.bak '/InputDevice    "Keyboard0" "CoreKeyboard"/a\
              Option       "AutoAddDevices" "Off"
      ' /usr/local/etc/X11/xorg.conf.d/xorg.conf
    fi
  fi
  
  #if running on bhyve
  dmidecode -t bios | grep 'Vendor: BHYVE'
  if [ $? = 0 ]; then
    if [ -f /usr/local/etc/X11/xorg.conf.d/xorg.conf ]; then
      sed -i.bak 's/Driver      "vesa"/Driver      "scfb"/gi' /usr/local/etc/X11/xorg.conf.d/xorg.conf
      
      sed -i.bak 's/Driver      "mouse"/Driver      "scfb"/gi' /usr/local/etc/X11/xorg.conf.d/xorg.conf      
    fi
  fi
}

xorg_install() {
  echo "Installing... xorg."
  
  sed -i.bak '/dbus_enable/d' /etc/rc.conf
  sed -i.bak '/hald_enable/d' /etc/rc.conf
  sed -i.bak '/kdm4_enable/d' /etc/rc.conf
  sed -i.bak '/gdm_enable/d' /etc/rc.conf
  sed -i.bak '/lightdm_enable/d' /etc/rc.conf
  sed -i.bak '/gnome_enable/d' /etc/rc.conf
  sed -i.bak '/moused_enable/d' /etc/rc.conf
  sed -i.bak '/sddm_enable/d' /etc/rc.conf
  
  if [ $PKG = true ]; then
    pkg install -y xorg
  else
    cd /usr/ports/x11/xorg/
    make -DBATCH install clean
  fi
  
  xorg_config
  xorg_vm
}

kde() {
  if [ $KDE = true ]; then
    xorg_install
    echo "Installing... KDE."
    echo ""
    if [ $PKG = true ]; then
      pkg install -y x11/kde4
    else
      cd /usr/ports/x11/kde4/
      make -DBATCH install clean
    fi      
  fi
}

gnome() {
  if [ $GNOME = true ]; then
    xorg_install
    echo "Installing... Gnome."
    echo ""
    if [ $PKG = true ]; then
      pkg install -y gnome3
    else
      cd /usr/ports/x11/gnome3/
      make -DBATCH install clean
    fi      
  fi
}

xfce() {
  if [ $XFCE = true ]; then
    xorg_install
    echo "Installing... XFCE."
    echo ""
    if [ $PKG = true ]; then
      pkg install -y xfce
      pkg install -y xfce4-pulseaudio-plugin
      pkg install -y xfce4-pulseaudio-pulse
    else
      cd /usr/ports/x11-wm/xfce4/
      make -DBATCH install clean
      cd /usr/ports/audio/xfce4-pulseaudio-plugin
      make -DBATCH install clean
    fi      
  fi
}

display_man() {
  if [ $NONE = true ]; then
    return
  fi
  
  if [ $DIS = true ]; then
    case $DISPLAYMAN in
      [Gg]* ) GDM=true;;
      [Ss]* ) SDDM=true;;
      [Ll]* ) LIGHTDM=true;;
    esac
  fi
  
  if [ $GDM = true ]; then
    if [ $PKG = true ]; then
      pkg install -y gdm
    else
      cd /usr/ports/x11/gdm/
      make -DBATCH install clean
    fi
    sysrc gnome_enable="YES"
  else
    if [ $SDDM = true ]; then
      if [ $PKG = true ]; then
        pkg install -y sddm
      else
        cd /usr/ports/x11/sddm/
        make -DBATCH install clean
      fi
      sysrc sddm_enable="YES"
    else
      if [ $LIGHTDM = true ]; then
        if [ $PKG = true ]; then
          pkg install -y lightdm
          pkg install -y lightdm-gtk-greeter
        else
          cd /usr/ports/x11/lightdm/
          make -DBATCH install clean
          cd /usr/ports/x11/lightdm-gtk-greeter/
          make -DBATCH install clean          
        fi
        sysrc lightdm_enable="YES"
      fi
    fi   
  fi  
}

firefox() {
  if [ $FIREFOX = true ]; then
    echo "Installing... Firefox."
    echo ""
    if [ $PKG = true ]; then
      pkg install -y firefox
    else
      cd /usr/ports/www/firefox/
      make -DBATCH install clean
    fi      
  fi
}

sudo_install() {
  if [ $SUDO = true ]; then
    if [ $PKG = true ]; then
      pkg install -y sudo
    else
      cd /usr/ports/security/sudo/
      make -DBATCH install clean
    fi    
    sed -i.bak '/^# %sudo ALL=(ALL) ALL/s/^#//g' /usr/local/etc/sudoers
  fi
}

add_sudo_user() {
  if [ -f /usr/local/etc/sudoers ]; then
    sed -i.bak '/^# %sudo/s/^#//g' /usr/local/etc/sudoers
  fi
  if [ -n "$SUDO_USER" ]; then
    [ $(getent group sudo) ] || pw groupadd sudo
    pw groupmod sudo -m $USER_ADD
  fi
}

bash_install() {
  if [ $BASH = true ]; then
    if [ $PKG = true ]; then
      pkg install -y bash
    else
      cd /usr/ports/shell/bash/
      make -DBATCH install clean
    fi
  fi
}

add_bash_user() {
  if [ -f /usr/local/bin/bash ]; then
    if id "$BASH_USER" >/dev/null 2>&1; then
      echo "user does exist."
      chsh -s /usr/local/bin/bash $BASH_USER 
    fi
  fi  
}

reboot_com() {
  if [ $REBOOT = true ]; then
    echo "Rebooting..."
    echo ""
    
    reboot
  fi
}

question() {
  HEADER=$1
  QUESTION=$2
  RTN=0
  
  header "$HEADER"
  echo "    $QUESTION? [Y/N]"
  
  read yesno
  
  case $yesno in
    [Yy]* ) RTN=1;;
    [Nn]* ) RTN=0;;
  esac
  
  return $RTN
}

questionDis() {
  HEADER=$1
  QUESTION=$2
  RTN=0
  
  header "$HEADER"
  echo "    $QUESTION? [S/G/L/N]"
  
  read yesno
  
  case $yesno in
    [Ss]* ) SDDM=true;;
    [Gg]* ) GDM=true;;
    [Ll]* ) LIGHTDM=true;;
    [Xx]* ) LIGHTDM=true;;
    [Nn]* ) NONE=true;;
    * ) NONE=true
  esac
}

question_adduser_sudo() {
  echo "Add user to group 'sudo'? [Y/N]"
  read yesno
    
  case $yesno in
    [Yy]* );;
    [Nn]* ) return;;
  esac
  
  if [ -f /usr/local/etc/sudoers ]; then
    sed -i.bak '/^# %sudo/s/^#//g' /usr/local/etc/sudoers
  fi
    
  END=false
  while [ $END = false ]
  do
    echo "Enter user to add to group 'sudo' or leave blank to exit."
    read USER_ADD
      
    if id "$USER_ADD" >/dev/null 2>&1; then
      echo "user does exist."
      [ $(getent group sudo) ] || pw groupadd sudo
      pw groupmod sudo -m $USER_ADD
    else
      echo "user does not exist."
      echo "    would you like to exit? [Y/N]"
        
      read yesno
        
      case $yesno in
        [Yy]* ) END=true;;
        [Nn]* ) ;;
      esac
    fi    
  done
}

question_adduser_bash() {
  echo "make bash defaut shell? [Y/N]"
  read yesno
    
  case $yesno in
    [Yy]* );;
    [Nn]* ) return;;
  esac
  
  if [ -f /usr/local/bin/bash ]; then
    echo "Bash not found!"
    echo "exit"
    return
  fi
    
  END=false
  while [ $END = false ]
  do
    echo "Enter user to add to group 'sudo' or leave blank to exit."
    read USER_ADD
      
    if id "$USER_ADD" >/dev/null 2>&1; then
      echo "user does exist."
      chsh -s /usr/local/bin/bash $USER_ADD 
    else
      echo "user does not exist."
      echo "    would you like to exit? [Y/N]"
        
      read yesno
        
      case $yesno in
        [Yy]* ) END=true;;
        [Nn]* ) ;;
      esac
    fi    
  done
}

ask_questions() {
  question "Update Kernel." "Would you like to update the Kernel"
  if [ "$?" = 1 ]; then
    UPDATE=true
  fi
  
  question "Use PKG." "Would you like to use PKG"
  if [ "$?" = 1 ]; then
    PKG=true
  fi
    
  question "Install open-vm-tools." "Would you like to install open-vm-tools"
  if [ "$?" = 1 ]; then
    VMWARE=true
  fi
  
  question "Install Gnome." "Would you like to install Gnome"
  if [ "$?" = 1 ]; then
    GNOME=true
  fi
  
  question "Install KDE." "Would you like to install KDE"
  if [ "$?" = 1 ]; then
    KDE=true
  fi
  
  question "Install XFCE." "Would you like to install XFCE"
  if [ "$?" = 1 ]; then
    XFCE=true
  fi
  
  questionDis "Display Manager." "What display manager would you like to use sddm(KDE) gdm(Gnome) lightdm(XFCE) or (None) to install no display manager"
    
  question "Install Firefox." "Would you like to install Firefox"
  if [ "$?" = 1 ]; then
    FIREFOX=true
  fi
  
  question "Install sudo." "Would you like to install sudo"
  if [ "$?" = 1 ]; then
    SUDO=true
  fi
  
  question_adduser_sudo
  
  question "Install bash." "Would you like to install bash"
  if [ "$?" = 1 ]; then
    BASH=true
  fi
  
  question_adduser_bash
  
  question "Reboot Computer." "Would you like to Reboot the Computer"
  if [ "$?" = 1 ]; then
    REBOOT=true
  fi
}

execute_selection() {
  header "Installing..."
  
  update_kernel
  
  pkgorports
  
  vmware
  
  gnome
  
  kde
  
  xfce
  
  display_man
  
  firefox
    
  sudo_install
  
  add_sudo_user
  
  bash_install
  
  add_bash_user
  
  reboot_com
}

#------------------------------------------
#-    Main
#------------------------------------------
if [ $HELP = true ]; then
  help
  exit 1
fi

#If no flags have been passed we ask the user what they would like to do.
if [ $OPT = false ]; then
  ask_questions
fi

execute_selection