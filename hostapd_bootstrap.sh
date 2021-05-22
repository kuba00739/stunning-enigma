#!/bin/bash

set -o pipefail -o noclobber -o nounset

! getopt --test > /dev/null 
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
	echo 'Sorry, `getopt --test` has not returned 4. Is your getopt up to date?'
	exit 1
fi

OPTIONS=Pdmahi:re:
LONGOPTS=pihole,default,ip:,dnsmasq,mount,airmon,help,interface:,routing,exit_int:

! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    exit 2
fi

eval set -- "$PARSED"

P=n d=n ip=- dnsmasq=n m=n airmon=n help_flag=n interface=- routing=n exit_interface=-

while true; do
	case "$1" in
		-r|--routing)
			routing="y"
			shift
			;;
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
		-e|--exit_interface)
			exit_interface="$2"
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
	-e	--exit_int	Sets and exit interface name\n\
	-a	--airmon	Will use airmon-ng to kill problematic services\n\
	-r	--routing	Sets iptables rules for routing beetween AP interface and exit interface\n\
	-h	--help		You know what it does
\n\
Written by Jakub Niezabitowski, 2021.\n\n"
	exit
fi

if [[ $interface = "-" ]]; then
	interface="wlo1"
fi

if [[ $exit_interface = "-" ]]; then
	exit_interface="wlp0s20f0u1"
fi

if [[ $ip = "-" ]]; then
	ip="192.168.200.1/24"
fi

if [[ $d = "y" || $airmon = "y" ]]; then
	echo "Running airmon-ng check kill"
	/usr/sbin/airmon-ng check kill
fi

if [[ $d = "y" || $dnsmasq = "y" ]]; then
	echo "Killing dnsmasq"
	/usr/bin/killall dnsmasq
fi

if [[ $d = "y" || $m = "y" ]]; then
	echo "Creating /sys/fs/cgroup/systemd directory and mounting cgroup"
	/usr/bin/mkdir /sys/fs/cgroup/systemd
	/usr/bin/mount -t cgroup -o none,name=systemd cgroup /sys/fs/cgroup/systemd/
fi

if [[ $d = "y" || $P = "y" ]]; then
	echo "Starting docker pihole"
	/usr/bin/docker rm pihole
	/usr/bin/docker run -p 53:53/tcp -p 80:80/tcp -p 53:53/udp --env WEBPASSWORD=Adam1000 --name pihole -d pihole/pihole #-p 67:67/udp for DHCP
fi

/usr/sbin/ip addr add $ip dev $interface

if [[ $d = "y" || $dnsmasq = "y" ]]; then
	echo "Starting dnsmasq"
	/usr/sbin/dnsmasq -C /etc/dnsmasq.conf -i $interface
fi

if [[ $routing = "y" || $d = "y" ]]; then
	echo "Adding routing rules to iptables"
	iptables -A INPUT -i lo -j ACCEPT
	iptables -A INPUT -i $interface -j ACCEPT
	iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
	iptables -t nat -A POSTROUTING -o $exit_interface -j MASQUERADE
	iptables -A FORWARD -i $exit_interface -o $interface -m state --state RELATED,ESTABLISHED -j ACCEPT
	iptables -A FORWARD -i $interface -o $exit_interface -j ACCEPT
fi

echo "Starting hostapd"
/usr/sbin/hostapd /etc/hostapd/hostapd.conf -i $interface
