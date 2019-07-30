#!/bin/bash

#    This file is part of usbgadget taken from P4wnP1.
#
#    Copyright (c) 2017, Marcus Mengs. Amended 2019 Steve Hearnden
#
#    usbgadget is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    P4wnP1 is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    usbgadget is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    P4wnP1 is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#

#    You should have received a copy of the GNU General Public License
#    along with P4wnP1.  If not, see <http://www.gnu.org/licenses/>.


# usbgadget (P4wnP1) install script.
#       Author: Marcus Mengs (MaMe82)
#       amended : Steve Hearnden (mksteveuk)

# Notes:
#   - install.sh should only be run ONCE
#   - work in progress (contains possible errors and typos)


# get DIR the script is running from (by CD'ing in and running pwd
wdir=$( cd $(dirname $BASH_SOURCE[0]) && pwd)

# check for wifi capability
if $wdir/wifi/check_wifi.sh; then WIFI=true; else WIFI=false; fi

# check Internet conectivity against 
echo "Testing Internet connection and name resolution..."
if [ "$(curl -s http://www.msftncsi.com/ncsi.txt)" != "Microsoft NCSI" ]; then 
        echo "...[Error] No Internet connection or name resolution doesn't work!"
else
    echo "...[pass] Internet connection works"
fi


echo "Backing up resolv.conf"
sudo cp /etc/resolv.conf /tmp/resolv.conf

echo "Installing needed packages..."
sudo apt-get -y update
sudo apt-get -y upgrade # include patched bluetooth stack
#if $WIFI; then
#	sudo apt-get install -y dnsmasq git python-pip python-dev screen sqlite3 inotify-tools hostapd
#else
#	sudo apt-get install -y dnsmasq git python-pip python-dev screen sqlite3 inotify-tools
#fi

# hostapd gets installed in even if WiFi isn't present (SD card could be moved from "Pi Zero" to "Pi Zero W" later on)
sudo apt-get -y install dnsmasq python-pip python-dev screen sqlite3 inotify-tools hostapd bluez bluez-tools bridge-utils

echo "Enable SSH server..."
sudo update-rc.d ssh enable

echo "Checking network setup.."
# set manual configuration for usb0 (RNDIS) if not already done
if ! grep -q -E '^iface usb0 inet manual$' /etc/network/interfaces; then
	echo "Entry for manual configuration of RNDIS interface not found, adding..."
	sudo /bin/bash -c "printf '\niface usb0 inet manual\n' >> /etc/network/interfaces"
else
	echo "Entry for manual configuration of RNDIS interface found"
fi

# set manual configuration for usb1 (CDC ECM) if not already done
if ! grep -q -E '^iface usb1 inet manual$' /etc/network/interfaces; then
	echo "Entry for manual configuration of CDC ECM interface not found, adding..."
	sudo /bin/bash -c "printf '\niface usb1 inet manual\n' >> /etc/network/interfaces"
else
	echo "Entry for manual configuration of CDC ECM interface found"
fi


# create 128 MB image for USB storage
echo "Creating 128 MB image for USB Mass Storage emulation"
mkdir -p $wdir/USB_STORAGE
dd if=/dev/zero of=$wdir/USB_STORAGE/image.bin bs=1M count=128
mkdosfs $wdir/USB_STORAGE/image.bin


# create systemd service unit for usbgadget startup
# Note: switched to multi-user.target to make nexmon monitor mode work
if [ ! -f /etc/systemd/system/usbgadget.service ]; then
        echo "Adding usbgadget startup script..."
        cat <<- EOF | sudo tee /etc/systemd/system/usbgadget.service > /dev/null
                [Unit]
                Description=usbgadget Startup Service
                #After=systemd-modules-load.service
                After=local-fs.target
                DefaultDependencies=no
                Before=sysinit.target

                [Service]
                #Type=oneshot
                Type=forking
                RemainAfterExit=yes
                ExecStart=/bin/bash $wdir/boot/boot_usbgadget
                StandardOutput=journal+console
                StandardError=journal+console

                [Install]
                WantedBy=multi-user.target
                #WantedBy=sysinit.target
EOF
fi

sudo systemctl enable usbgadget.service

# setup USB gadget capable overlay FS (needs Pi Zero, but shouldn't be checked - setup must 
# be possible from other Pi to ease up Internet connection)
echo "Enable overlay filesystem for USB gadgedt suport..."
sudo sed -n -i -e '/^dtoverlay=/!p' -e '$adtoverlay=dwc2' /boot/config.txt

# add libcomposite to /etc/modules
echo "Enable kernel module for USB Composite Device emulation..."
if [ ! -f /tmp/modules ]; then sudo touch /etc/modules; fi
sudo sed -n -i -e '/^libcomposite/!p' -e '$alibcomposite' /etc/modules

echo "Removing all former modules enabled in /boot/cmdline.txt..."
sudo sed -i -e 's/modules-load=.*dwc2[',''_'a-zA-Z]*//' /boot/cmdline.txt

source $wdir/setup.cfg


echo
echo
echo "===================================================================================="
echo "If you came till here without errors, you shoud be good to go with your usbgadget..."
echo "...if not - sorry, you're on your own, as this is work in progress"
echo 
echo "Attach usbgadget to a host and you should be able to SSH in with pi@172.16.0.1 (via RNDIS/CDC ECM)"
echo
echo "If you use a USB OTG adapter to attach a keyboard, guest boots into interactive mode"
echo
echo "If you're using a Pi Zero W, a WiFi AP should be opened. You could use the AP to setup usbgadget, too."
echo "          WiFi name:    $(WIFI_ACCESSPOINT_NAME)"
echo "          Key:          $(WIFI_ACCESSPOINT_PSK)"
echo "          SSH access:    pi@$(WIFI_ACCESSPOINT_IP) (password: raspberry)"
echo
echo
echo "Go to your installation directory. From there you can alter the settings in the file 'setup.cfg',"
echo 
echo "You need to reboot the Pi now!"
echo "===================================================================================="

