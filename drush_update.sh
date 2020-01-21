#!/bin/sh
if [ `whoami` != root ]; then 
  echo "Please run as root"
  exit 1
fi
if [ "$1" = "" ] || [ "$1" = "-h" ]; then 
  echo "Please run as root and pass your drupal dir."
  exit 1
fi
if [ ! -x /usr/local/bin/drush ]; then
  echo "Please install drush."
  echo "Would you like to install 'drush'? [Y/N]"
  
  read yesno
  case $yesno in
    [Yy]* );;
    [Nn]* ) exit 1;;
  esac
  
  pkg install -y drush
  
fi

DIR=$1

if [ ! -d "$DIR" ]; then
  echo "Directory is not found."
  exit 1
fi

cd $DIR

echo "Going into maintenance mode."
drush sset system.maintenance_mode 1
drush cache-rebuild

echo "Doing Update."
drush up --yes

echo "Leaving maintenance mode."
drush sset system.maintenance_mode 0
drush cache-rebuild
