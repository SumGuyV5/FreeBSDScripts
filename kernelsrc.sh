#!/bin/sh
if [ `whoami` != root ]; then 
  echo "Please run as root"
  exit 1
fi
if [ "$1" = "-h" ]; then 
  echo "-s to use snapshots instead of releases"
  exit 1
fi
TRAIN="releases"
if [ "$1" = "-s" ]; then
  TRAIN="snapshots"
fi

fetch -o /tmp ftp://ftp.freebsd.org/pub/`uname -s`/$TRAIN/`uname -m`/`uname -r | cut -d'-' -f1,2`/src.txz

tar -C / -xvf /tmp/src.txz
