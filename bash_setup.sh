#!/bin/sh
if [ `whoami` != root ]; then 
  echo "Please run as root"
  exit 1
fi
if [ "$1" = "" ] || [ "$1" = "-h" ]; then 
  echo "Please run as root and pass the user name."
  exit 1
fi
if [ ! -x /usr/local/bin/bash ]; then
  echo "Please install bash."
  echo "Would you like to install 'bash'? [Y/N]"
  
  read yesno
  case $yesno in
    [Yy]* );;
    [Nn]* ) exit 1;;
  esac
  
  pkg install -y bash
  
fi

BASH_USER=$1

if id "$BASH_USER" >/dev/null 2>&1; then
  echo "user does exist."
else
  echo "user does not exist."
  exit 1
fi

if [ -n "$BASH_USER" ]; then
  chsh -s /usr/local/bin/bash $BASH_USER  
fi