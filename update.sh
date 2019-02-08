#!/bin/sh
if [ `whoami` != root ]; then 
  echo "Please run as root"
  exit 1
fi

DELETE=false
CLEAN=false
FORCE=false
HELP=false
RESUME=false
POWEROFF=false
REBOOT=false
OSUPDATE=false

FLAGS="-Gayd --no-confirm"


while getopts dcfhpRo option
do
  case "${option}"
  in
  d) DELETE=true;;
  c) CLEAN=true;;
  f) FORCE=true;;
  h) HELP=true;;
  r) RESUME=true;;
  p) POWEROFF=true;;
  R) REBOOT=true;;
  o) OSUPDATE=true;;
  esac
done

if [ "$HELP" = true ]; then
  echo "-d flag delete and redownloads ports."
  echo "-c flag clean portsmaster."
  echo "-f flag Forces portsmaster to redo all ports."
  echo "-r resume runs command in /tmp/portmasterfail.txt."
  echo "-p power off computer when done."
  echo "-R reboot computer when done."
  echo "-o update OS."
  echo "-h this help text."
  exit 1
fi

if [ "$DELETE" = true ]; then
	echo "Delete ports."
	rm -R /usr/ports
fi

if [ -s /usr/ports ] && [ "$(ls -A /usr/ports)" ]; then
	echo "Files"
else
	portsnap fetch extract
fi

if [ -s /usr/local/sbin/portmaster ]; then
	echo "File Found"
else
	if [ "$(ls -A /usr/ports/ports-mgmt/portmaster)" ]; then
		cd /usr/ports/ports-mgmt/portmaster/
    make -DBATCH install clean
	fi
fi

portsnap fetch update 

if [ "$FORCE" = true ]; then
  FLAGS="-Gaydf --no-confirm"
fi

if [ "$CLEAN" = true ]; then
  portmaster -Gayd --no-confirm --clean-packages
  portmaster -Gayd --no-confirm --clean-distfiles
  portmaster -Gayd --no-confirm --delete-packages
fi

if [ "$RESUME" = true ]; then
  FLAGS="-Gyd --no-confirm"
  sed -i.bak "s/<flags>/$FLAGS/gi" /tmp/portmasterfail.txt
  sh /tmp/portmasterfail.txt
else
  portmaster $FLAGS
fi

if [ "$OSUPDATE" = true ]; then
  freebsd-update fetch
  freebsd-update install
fi

if [ "$POWEROFF" = true ]; then
  shutdown -p +1 "Shutting Down."
fi

if [ "$REBOOT" = true ]; then
  shutdown -r +1 "Rebooting Now."
fi