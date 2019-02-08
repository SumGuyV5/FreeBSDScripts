#!/bin/sh
if [ `whoami` != root ]; then 
  echo "Please run as root"
  exit 1
fi
fetch -o /tmp ftp://ftp.freebsd.org/pub/`uname -s`/snapshots/`uname -m`/`uname -r | cut -d'-' -f1,2`/src.txz

tar -C / -xvf /tmp/src.txz
