#!/bin/bash

stty eof undef
stty intr undef

hostsystem="$( cat /etc/bmchost )"
packages=( screen wiringpi )
pkgfail=""
for package in ${packages[@]}; do
        dpkg -l | grep "^ii  ${package}" &>/dev/null || pkgfail="true"
done
if test -n "$pkgfail"; then
        echo -n "Installing required packages... "
        sudo apt update &>/dev/null
        sudo apt install -y ${packages[@]} &>/dev/null
        echo "done."
fi

help() {
        echo -e "Available commands:"
        echo -e "  \e[1mstate\e[0m - Show the system power state"
        echo -e "  \e[1mconsole\e[0m - Connect to host via serial console; ^A+D to disconnect"
        echo -e "  \e[1mpowersw\e[0m - Press power switch on host"
        echo -e "  \e[1mresetsw\e[0m - Press reset switch on host"
        echo -e "  \e[1mkill\e[0m - Forcibly power off host"
        echo -e "  \e[1mhelp\e[0m - This help menu"
        echo -e "  \e[1mbmc\e[0m - Show BMC information"
        echo -e "  \e[1mhostname\e[0m - Set BMC hostname"
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
        echo -n "Enter new hostname: "
        read newhostname
        sudo sed -i '/^127.0.1.1/d' /etc/hosts &>/dev/null
        sudo tee -a /etc/hosts <<<"127.0.1.1 $newhostname" &>/dev/null
        sudo hostname $newhostname &>/dev/null
        sudo tee /etc/hostname <<<"$newhostname" &>/dev/null
        echo "Hostname set to $newhostname"
}
setpassword() {
        echo -n "Enter new BMC password: "
        read -s password_1
        echo
        echo -n "Reenter new BMC password: "
        read -s password_2
        echo
        if [ "${password_1}" == "${password_2}" ]; then
                echo -n "Setting BMC password... "
                sudo chpasswd <<<"bmc:${password_1}"
                echo "done."
        else
                echo "Passwords to not match!"
        fi
}
resetsw() {
        echo -n "Pressing reset switch... "
        gpio mode 0 out
        gpio write 0 1
        sleep 1
        gpio write 0 0
        sleep 1
        echo "done."
}
powersw() {
        if [ "$1" == "hard" ]; then
                delay='sleep 10'
                echo -n "Holding power switch... "
        else
                delay='sleep 1'
                echo -n "Pressing power switch... "
        fi
        gpio mode 1 out
        gpio write 1 1
        $delay
        gpio write 1 0
        sleep 2
        echo "done."
}
readpower() {
        gpio mode 2 in
        powerstate_raw=$(gpio read 2)
        if [ "${powerstate_raw}" -eq 1 ]; then
                powerstate="\e[32mOn\e[0m"
        else
                powerstate="\e[31mOff\e[0m"
        fi
}

readpower
echo
echo -e "--------------------"
echo -e "| Raspberry Pi BMC |"
echo -e "--------------------"
echo
echo -e "Host system: \e[1m${hostsystem}\e[0m"
echo -e "Host state: $powerstate"
echo
help
echo
while true; do
stty eof undef
stty intr undef
echo -en "\e[1m\e[34m[$(hostname)]>\e[0m "
read input
case $input in
        'state')
                readpower
                echo -e "Host state: $powerstate"
                echo
        ;;
        'console')
                echo "Starting console..."
                sudo screen -r serialconsole &>/dev/null || sudo screen -S serialconsole /dev/ttyUSB0 115200
                echo
        ;;
        'powersw')
                powersw soft
                readpower
                echo -e "Host state: $powerstate"
                echo
        ;;
        'resetsw')
                resetsw
                readpower
                echo -e "Host state: $powerstate"
                echo
        ;;
        'kill')
                powersw hard
                readpower
                echo -e "Host state: $powerstate"
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
                sethostname
                echo
        ;;
        'password')
                setpassword
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
