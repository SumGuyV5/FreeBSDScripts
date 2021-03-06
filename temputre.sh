#!/bin/sh
if [ `whoami` != root ]; then 
  echo "Please run as root."
  exit 1
fi

### Parameters ###
cores=4
drives="ada0 ada1 ada2 ada3"

### CPU ###
echo ""
cores=$((cores - 1))
for core in $(seq 0 $cores)
do
    temp="$(sysctl -a | grep "cpu.${core}.temp" | cut -c24-25 | tr -d "\n")"
    printf "CPU %s: %s C\n" "$core" "$temp"
done

### Disks ###
echo ""
for drive in $drives
do
    serial="$(smartctl -i /dev/${drive} | grep "Serial Number" | awk '{print $3}')"
    temp="$(smartctl -A /dev/${drive} | grep "Temperature_Celsius" | awk '{print $10}')"
    printf "%s %-15s: %s C\n" "$drive" "$serial" "$temp"
done
echo ""
