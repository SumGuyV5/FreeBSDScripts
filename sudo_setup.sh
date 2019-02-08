#!/bin/sh
if [ `whoami` != root ]; then 
  echo "Please run as root"
  exit 1
fi
if [ "$1" = "" ] || [ "$1" = "-h" ]; then 
  echo "Please run as root and pass the user name."
  exit 1
fi
if [ ! -x /usr/local/bin/sudo ] && [ ! -x /usr/bin/sudo ]; then
  echo "Please install sudo."
  exit 1
fi

SUDO_USER=$1

if id "$SUDO_USER" >/dev/null 2>&1; then
  echo "user does exist."
else
  echo "user does not exist."
  exit 1
fi

if [ -n "$SUDO_USER" ]; then
  if [ "$(uname)" == 'Linux' ]; then
    [ $(getent group sudo) ] || groupadd sudo
    usermod -a -G sudo $SUDO_USER
  elif [ "$(uname)" == 'FreeBSD' ]; then
      [ $(getent group sudo) ] || pw groupadd sudo
      pw groupmod sudo -m $SUDO_USER
  fi  
fi

if [ -f /usr/local/etc/sudoers ]; then
  sed -i.bak '/^# %sudo/s/^#//g' /usr/local/etc/sudoers
elif [ -f /etc/sudoers ]; then
    sed -i.bak '/^# %sudo ALL=(ALL) ALL/s/^#//g' /etc/sudoers 
fi