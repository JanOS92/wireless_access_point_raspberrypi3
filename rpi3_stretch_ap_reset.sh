#!/bin/bash
#

if [ "$EUID" -ne 0 ]

	then echo "Please run this script as root user."
	exit

fi

echo "--------------------------------"
echo "Rasperry Pi 3 Access-Point reset"
echo "--------------------------------"
echo "JanOS92 (GitHub)"
echo ""

# SHA-1 Hash: "configured"
FLAG="##3be9f957f29f905f10f7b652cab1c95ba8a2c205"

# Purge some packages
echo "Remove the hostapd ..."
apt-get remove --purge hostapd -yqq
echo "Done"

#########################
#  Reset the dnsmasq

DNSMASQ_CONF_PATH="/etc/dnsmasq.conf"

# set the right permissions
sudo chmod 0777 $DNSMASQ_CONF_PATH

# clear the file
sudo echo -n >$DNSMASQ_CONF_PATH

# reset permissions
sudo chmod 600 $DNSMASQ_CONF_PATH

####################
# Reset the hostapd

HOSTAPD_CONF_PATH="/etc/hostapd/hostapd.conf"

# set the right permissions
sudo chmod 0777 $HOSTAPD_CONF_PATH

# clear the file
sudo echo -n >$HOSTAPD_CONF_PATH

# reset permissions
sudo chmod 600 $HOSTAPD_CONF_PATH

##############################
# Reset the network interfaces

NETWORK_INTERFACES_CONF_PATH="/etc/network/interfaces"

# set the right permissions
sudo chmod 0777 $NETWORK_INTERFACES_CONF_PATH

# clear the file
sudo echo -n >$NETWORK_INTERFACES_CONF_PATH

cat >> $NETWORK_INTERFACES_CONF_PATH <<EOF
# interfaces(5) file used by ifup(8) and ifdown(8)

# Please note that this file is written to be used with dhcpcd
# For static IP, consult /etc/dhcpcd.conf and 'man dhcpcd.conf'

# Include files from /etc/network/interfaces.d:
source-directory /etc/network/interfaces.d

auto lo
iface lo inet loopback

auto eth0
iface eth0 inet manual

allow-hotplug wlan0
iface wlan0 inet manual
wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
EOF

# reset permissions
sudo chmod 600 $HOSTAPD_CONF_PATH

###############################
# Reset the DHCP Client Daemon

DHCPCD_CONF_PATH="/etc/dhcpcd.conf"

sudo sed -i -- 's/# Do not remove the following line//g' $DHCPCD_CONF_PATH
sudo sed -i -- 's/$FLAG//g' $DHCPCD_CONF_PATH
sudo sed -i -- 's/denyinterfaces wlan0//g' $DHCPCD_CONF_PATH

###########################
# Reset the hostapd process

HOSTAPD_PATH="/etc/default/hostapd"

sudo sed -i -- 's/# Do not remove the following line//g' $HOSTAPD_PATH
sudo sed -i -- 's/$FLAG//g' $HOSTAPD_PATH
sudo sed -i -- 's/RUN_DAEMON=yes//g' $HOSTAPD_PATH
sudo sed -i -- 's/DAEMON_CONF="\/etc\/hostapd\/hostapd.conf"//g' $HOSTAPD_PATH

systemctl disable hostapd
systemctl disable dnsmasq
sudo service hostapd stop
sudo service dnsmasq stop

echo "All done!"
