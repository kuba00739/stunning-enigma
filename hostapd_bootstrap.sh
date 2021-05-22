#!/bin/bash

set -o pipefail -o noclobber -o nounset

! getopt --test > /dev/null 
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
	echo 'Sorry, `getopt --test` has not returned 4. Is your getopt up to date?'
	exit 1
fi

OPTIONS=Pdmahi:
LONGOPTS=pihole,default,ip:,dnsmasq,mount,airmon,help,interface:

! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    exit 2
fi

eval set -- "$PARSED"

P=n d=n ip=- dnsmasq=n m=n airmon=n help_flag=n interface=-

while true; do
	case "$1" in
		-d|--default)
			d="y"
			shift
			;;
		-P|--pihole)
			p="y"
			shift
			;;
		--ip)
			ip="$2"
			shift 2
			;;
		--dnsmasq)
			dnsmasq="y"
			shift
			;;
		-m|--mount)
			m="y"
			shift
			;;
		-i|--interface)
			interface="$2"
			shift 2
			;;
		-a|--airmon)
			airmon="y"
			shift
			;;
		-h|--help)
			help_flag="y"
			shift
			;;
		--)
			shift
			break
			;;
		*)
			echo "Programming error"
			exit 3
			;;
	esac
done

if [[ $help_flag = "y" ]]; then
	printf "\nScript for quick deployment of hostapd and pihole.\nUsage:\n\
	-d	--default	Run with default options\n\
	-P	--pihole	Run pihole\n\
		--ip		Specify non-default ip address and netmask for AP interface. Default is 192.168.200.1/24\n\
		--dnsmasq	With this option script will kill any instance of dnsmasq and start a new one\n\
	-m	--mount		Will create /sys/fs/cgroup/systemd directory and mount cgroup (for pihole)\n\
	-i	--interface	Set interface to use with AP.\n\
	-a	--airmon	Will use airmon-ng to kill problematic services\n\
	-h	--help		You know what it does
\n\
Written by Jakub Niezabitowski, 2021.\n\n"
	exit
fi

if [[ $interface = "-" ]]; then
	interface="wlo1"
fi

if [[ $ip = "-" ]]; then
	ip="192.168.200.1/24"
fi

if [[ $d = "y" || $airmon = "y" ]]; then
	/usr/sbin/airmon-ng check kill
fi

if [[ $d = "y" || $dnsmasq = "y" ]]; then
	/usr/bin/killall dnsmasq
fi

if [[ $d = "y" || $m = "y" ]]; then
	/usr/bin/mkdir /sys/fs/cgroup/systemd
	/usr/bin/mount -t cgroup -o none,name=systemd cgroup /sys/fs/cgroup/systemd/
fi

if [[ $d = "y" || $P = "y" ]]; then
	/usr/bin/docker rm pihole
	/usr/bin/docker run -p 53:53/tcp -p 80:80/tcp -p 53:53/udp --env WEBPASSWORD=Adam1000 --name pihole -d pihole/pihole #-p 67:67/udp for DHCP
fi

/usr/sbin/ip addr add $ip dev $interface

if [[ $d = "y" || $dnsmasq = "y" ]]; then
	/usr/sbin/dnsmasq -C /etc/dnsmasq.conf -i $interface
fi

/usr/sbin/hostapd /etc/hostapd/hostapd.conf -i $interface
