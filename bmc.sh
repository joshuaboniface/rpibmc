#!/bin/bash

#
# bmc.sh - BMC command shell
#
# This program works as the main user shell for the RPi BMC. It provides a
# command-line interface for interfacing with the GPIOs used for the BMC, a few
# distinct functions such as a serial console, as well as managing the BMC
# itself (e.g. BMC hostname, IP address, or host system name).
#
# It is designed so it can be started automatically on login to the BMC.  For
# example, as a 'bmc' user with the following passwd file entry:
#
#   bmc:x:2000:2000:BMC:/home/dir:/path/to/bmc.sh
#
# Has dependencies on the 'screen' utility.  The user must also be part of the
# 'gpio' group, and should be able to use 'sudo'.
#
# Adapted from the RPiBMC project.
#
# The RPiBMC project
# Copyright (c) 2017  Joshua Boniface
#
# This software is licenced under the terms of the GNU GPL version 3. For
# details please see LICENSE.
#

stty eof undef
stty intr undef

gpio_rsw=17
gpio_psw=18
gpio_state=27

gpio_setup() {
	for dir in "out" "in"; do
		if [[ "${dir}" == "out" ]]; then
			gpios=("${gpio_rsw}" "${gpio_psw}")
		else
			gpios=("${gpio_state}")
		fi
		for gpio in "${gpios[@]}"; do
			if [[ ! -d "/sys/class/gpio/gpio${gpio}" ]]; then
				echo "${gpio}" >"/sys/class/gpio/export"
				sleep 0.1
			fi
			echo "${dir}" >"/sys/class/gpio/gpio${gpio}/direction"
		done
	done
}
gpio_press() {
	gpio="${1}"
	seconds="${2}"
	echo 1 >"/sys/class/gpio/gpio${gpio}/value"
	sleep "${seconds}"
	echo 0 >"/sys/class/gpio/gpio${gpio}/value"
}

hostsystem="$( cat /etc/bmchost )"

help() {
	echo -e "Available commands:"
	echo -e "  \e[1mstate\e[0m - Show the system power state"
	echo -e "  \e[1mconsole\e[0m - Connect to host via serial console; ^A+D to disconnect"
	echo -e "  \e[1mpower\e[0m - Press power switch on host"
	echo -e "  \e[1mreset\e[0m - Press reset switch on host"
	echo -e "  \e[1mkill\e[0m - Forcibly power off host"
	# TODO echo -e "  \e[1mlocate\e[0m - Enable locator (flash power LED)"
	# TODO echo -e "  \e[1munlocate\e[0m - Disable locator"
	echo -e "  \e[1mhelp\e[0m - This help menu"
	echo -e "  \e[1mbmc\e[0m - Show BMC information"
	echo -e "  \e[1mhostname\e[0m - Set BMC hostname"
	echo -e "  \e[1mhost\e[0m - Set host system name"
	echo -e "  \e[1mpassword\e[0m - Set BMC password"
	echo -e "  \e[1mshell\e[0m - Start a BMC bash shell"
	echo -e "  \e[1mexit/logout\e[0m - Disconnect from the BMC"
}
bmcinfo() {
	echo -e "BMC information:"
	echo -e "  IP address: $( ip -4 addr list eth0 | grep inet | awk '{ print $2 }' )"
	echo -e "  Hostname: $( hostname )"
	echo -e "  BMC temperature: $( sudo /opt/vc/bin/vcgencmd measure_temp | awk -F'=' '{ print $2 }' )"
}
sethostname() {
	newhostname="${1}"
	echo "Setting hostname to '${newhostname}'."
	sudo sed -i '/^127.0.1.1/d' /etc/hosts &>/dev/null
	sudo tee -a /etc/hosts <<<"127.0.1.1 ${newhostname}" &>/dev/null
	sudo hostname ${newhostname} &>/dev/null
	sudo tee /etc/hostname <<<"${newhostname}" &>/dev/null
}
sethost() {
	newbmcname="${1}"
	echo "Setting host system name to '${newbmcname}'."
	sudo tee /etc/bmcname <<<"${newbmcname}" &>/dev/null
}
setpassword() {
	password="${1}"
	echo "Setting BMC password."
	sudo chpasswd <<<"bmc:${password}"
}
resetsw_press() {
	echo "Pressing reset switch."
	gpio_press "${gpio_rsw}" 0.5
}
powersw_press() {
	echo "Pressing power switch."
	gpio_press "${gpio_psw}" 0.5
	sleep 2 # Wait a bit to let it sink in
}
powersw_hold() {
	echo "Holding power switch."
	gpio_press "${gpio_psw}" 8
	sleep 2 # wait a bit to let it sink in
}
locate_on() {
	echo "Enabling locator - host power LED will flash."
	echo "Not implemented"
}
locate_off() {
	echo "Disabling locator."
	echo "Not implemented"
}
readpower() {
	powerstate_raw=$(cat "/sys/class/gpio/gpio${gpio_state}/value")
	if [[ "${powerstate_raw}" -eq 1 ]]; then
		powerstate="\e[32mOn\e[0m"
	else
		powerstate="\e[31mOff\e[0m"
	fi
}

# export and configure GPIOs
gpio_setup

# Read the power state
readpower

# Print our login splash
echo
echo -e "--------------------"
echo -e "| Raspberry Pi BMC |"
echo -e "--------------------"
echo
echo -e "Host system: \e[1m${hostsystem}\e[0m"
echo -e "Host state: ${powerstate}"
echo
help
echo

# Main loop
while true; do
	stty eof undef
	stty intr undef

	# Prompt
	echo -en "\e[1m\e[34m[$(hostname)]>\e[0m "
	# Read input
	read input
	# Process input
	case ${input} in
		'state')
			readpower
			echo -e "Host state: ${powerstate}"
			echo
		;;
		'console')
			echo "Starting console..."
			# Connect to screen, or start it
			sudo screen -r serialconsole &>/dev/null || sudo screen -S serialconsole /dev/ttyAMA0 115200
			# If the user killed screen, restart it - just in case
			pgrep screen &>/dev/null || sudo screen -S serialconsole /dev/ttyAMA0 115200
			echo
		;;
		'power')
			powersw_press
			readpower
			echo -e "Host state: ${powerstate}"
			echo
		;;
		'reset')
			resetsw_press
			echo
		;;
		'kill')
			powersw_hold
			readpower
			echo -e "Host state: ${powerstate}"
			echo
		;;
		'locate')
			locate_on
			echo
		;;
		'unlocate')
			locate_off
			echo	
		;;
		'help')
			help
			echo
		;;
		'bmc')
			bmcinfo
			echo
		;;
		'hostname')
			echo -n "Enter new hostname: "
			read newhostname
			sethostname ${newhostname}
			echo
		;;
		'host')
			echo -n "Enter new host system name: "
			read newhost
			sethost ${newhost}
			echo -n "Update BMC hostname to '${newhost}-bmc'? (y/N) "
			read updatehostnameyn
			if [[ "${updatehostnameyn}" =~ "y" ]]; then
				sethostname "${newhost}-bmc"
			fi
		;;
		'password')
			echo -n "Enter new BMC password: "
			read -s password_1
			echo
			echo -n "Reenter new BMC password: "
			read -s password_2
			echo
			if [ "${password_1}" == "${password_2}" ]; then
				setpassword "${password_1}"
			else
				echo "Passwords to not match!"
			fi
			echo
		;;
		'shell')
			stty sane
			/bin/bash
			help
			echo
		;;
		'exit'|'logout')
			exit 0
		;;
		'')
			continue
		;;
		*)
			echo "Invalid command."
			echo
		;;
	esac
done
