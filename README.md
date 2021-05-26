# stunning-enigma

This project is just a simple script for rapid setup of AP with routing and DNS on your local linux machine.

Required:

Two network interfaces, one with the AP capability (you can check it with `iw list` and look under 'Supported interface modes') and one as external interface.
It's sometimes necessary to disable firewalld service.

Before you run this script run it with -h option and make sure you know what options you need.

Flag -d means 'default', it's like running scripts with -P, -m, -a, -r flags.

Flag -P runs dockerized pihole, more on that here: https://github.com/pi-hole/pi-hole. On some systems it is necessary to run -m flag to mount cgroup.

Flag -a runs airmon-ng check kill to kill all services which can affect AP.

Flag -r creates iptables rules for routing.

Remember to change WEBPASSWORD for pihole!

Tested on Fedora 33 and 34.
