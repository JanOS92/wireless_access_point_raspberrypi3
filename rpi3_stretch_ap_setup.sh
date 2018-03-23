#!/bin/bash
#

# Check if the input file includes the "FLAG"
# @ $1: Path to the file
# @ $2: FLAG
check_config() {

        while read line; do
                if [ "${line}" == "$2" ]; then
                        return 1
                fi
        done <"$1"

        return 0

}

if [ "$EUID" -ne 0 ]

	then echo "Please run this script as root user."
	exit

fi

if [[ $# -lt 2 ]];

	then echo "Please commit a name and a password for the WLAN-Access-Point"
	echo "-----------------------------"
	echo "Usage Pattern:"
	echo "sudo $0 [apPassword] [apName]"
	echo "-----------------------------"
	exit

fi

# Get the input parameters
APPASS="$1"
APSSID="$2"

# SHA-1 Hash: "configured"
FLAG="##3be9f957f29f905f10f7b652cab1c95ba8a2c205"

echo "--------------------------------"
echo "Rasperry Pi 3 Access-Point setup"
echo "--------------------------------"
echo "JanOS92 (GitHub)"
echo ""

# Purge and install some required packages
#echo "Remove the actual hostapd ..."
#apt-get remove --purge hostapd -yqq
#echo "Done"

echo "Update all packages ..."
apt-get update -yqq
apt-get upgrade -yqq
echo "Done"

echo "Install the required packages hostapd and dnsmasq ..."
apt-get install hostapd dnsmasq -yqq
echo "Done"

#########################
#  Configure the dnsmasq

DNSMASQ_CONF_PATH="/etc/dnsmasq.conf"

# check if the file is already configured/updated
# usage: "$?" contains the return value of "check_config"
check_config $DNSMASQ_CONF_PATH $FLAG
configured=$?

if [ "$configured" == 0 ]; then
	
	echo "Set the dnsmasq configuration (/etc/dnsmasq.conf) ..."

	cat > $DNSMASQ_CONF_PATH <<EOF
# Do not remove the following line
$FLAG

interface=wlan0
dhcp-range=192.168.42.2,192.168.42.255,255.255.255.0,12h 
EOF

	echo "Done"

else

	echo "dnsmasq (/etc/dnsmasq.conf) is already configured, skip..." 

fi

#########################
# Configure the hostapd

HOSTAPD_CONF_PATH="/etc/hostapd/hostapd.conf"

# check whether the file is already configured/updated
# usage: "$?" contains the return value of "check_config"
check_config $HOSTAPD_CONF_PATH $FLAG
configured=$?

if [ "$configured" == 0 ]; then

	echo "Set the hostapd configuration (/etc/hostapd/hostapd.conf)..."
	
	cat > $HOSTAPD_CONF_PATH <<EOF

# Do not remove the following line
$FLAG

# Interface
interface=wlan0

# WLAN-configuration
ssid=$APSSID
channel=10
hw_mode=g
ieee80211n=1
ieee80211d=1
country_code=DE
wmm_enabled=1

# WLAN-encryption
auth_algs=1
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP
wpa_passphrase=$APPASS
ht_capab=[HT40][SHORT-GI-20][DSSS_CCK-40]
EOF
	
	echo "Done"

else

	echo "hostapd (/etc/hostapd/hostapd.conf) is already configured, skip..." 

fi


echo -n "Set the /etc/hostapd/hostapd.conf as read only ..."
sudo chmod 600 /etc/hostapd/hostapd.conf
echo "Done"

##################################
# Configure the network interfaces

NETWORK_INTERFACES_CONF_PATH="/etc/network/interfaces"

# check whether the file is already configured/updated
# usage: "$?" contains the return value of "check_config"
check_config $NETWORK_INTERFACES_CONF_PATH $FLAG
configured=$?

if [ "$configured" == 0 ]; then

	echo "Configure the network interfaces (/etc/network/interfaces) and set the static IP..."

	sed -i -- 's/allow-hotplug wlan0//g' $NETWORK_INTERFACES_CONF_PATH
	sed -i -- 's/iface wlan0 inet manual//g' $NETWORK_INTERFACES_CONF_PATH
	sed -i -- 's/wpa-conf \/etc\/wpa_supplicant\/wpa_supplicant.conf//g' $NETWORK_INTERFACES_CONF_PATH
	sed -i -- 's/auto lo//g' $NETWORK_INTERFACES_CONF_PATH
	sed -i -- 's/iface lo inet loopback//g' $NETWORK_INTERFACES_CONF_PATH
	sed -i -- 's/auto eth0//g' $NETWORK_INTERFACES_CONF_PATH
	sed -i -- 's/iface eth0 inet manual//g' $NETWORK_INTERFACES_CONF_PATH

	cat >> $NETWORK_INTERFACES_CONF_PATH <<EOF

# Do not remove the following line
$FLAG

# Added by rPi Access Point Setup
allow-hotplug wlan0
iface wlan0 inet static
	address 192.168.42.1
	gateway 192.168.1.1
	netmask 255.255.255.0
	#network 10.0.0.0
	#broadcast 10.0.0.255
EOF

	echo "Done"

	echo "Enable NAT, Masquerading and IP-Forwarding..."

	cat >> $NETWORK_INTERFACES_CONF_PATH <<EOF

# Purge the actual firewall configuration
up /sbin/iptables -F
up /sbin/iptables -X
up /sbin/iptables -t nat -F

# Allow loopback
up /sbin/iptables -A INPUT -i lo -j ACCEPT
up /sbin/iptables -A OUTPUT -o lo -j ACCEPT

# Enable NAT and Masquerading
up /sbin/iptables -A FORWARD -o eth0 -i wlan0 -m conntrack --cstate NEW -j ACCEPT
up /sbin/iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
up /sbin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Enable IP-forwarding
up sysctl -w net.ipv4.ip_forward=1
up sysctl -w net.ipv6.conf.all.forwarding=1

# Restart hostapd and dnsmasq
up service hostapd restart
up service dnsmasq restart
EOF

	echo "Done"

else
	
	echo -n "interfaces (/etc/network/interfaces) are already configured, skip..." 

fi

####################################
# Reconfigure the DHCP Client Daemon

DHCPCD_CONF_PATH="/etc/dhcpcd.conf"

# check whether the file is already configured/updated
# usage: "$?" contains the return value of "check_config"
check_config $DHCPCD_CONF_PATH $FLAG
configured=$?

if [ "$configured" == 0 ]; then

	echo "Reconfigre the DHCP Client Daemon (/etc/dhcpcd.conf)..."
	
	cat >> $DHCPCD_CONF_PATH <<EOF	
	  
# Do not remove the following line
$FLAG

denyinterfaces wlan0
EOF

	echo "done"

else

	echo -n "DHCP Client Daemon (/etc/dhcpcd.conf) is already configured, skip..." 

fi

###############################################
# Reconfigure the hostapd as background process

HOSTAPD_PATH="/etc/default/hostapd"

# check whether the file is already configured/updated
# usage: "$?" contains the return value of "check_config"
check_config $HOSTAPD_PATH $FLAG
configured=$?

if [ "$configured" == 0 ]; then

	echo "Set hostapd as background process..."

	sed -i -- 's/#DAEMON_CONF=""/DAEMON_CONF="\/etc\/hostapd\/hostapd.conf"/g' $HOSTAPD_PATH

	cat >> $HOSTAPD_PATH <<EOF

# Do not remove the following line
$FLAG

RUN_DAEMON=yes
EOF

	echo "done"

else

	echo -n "hostapd (/etc/default/hostapd) is already configured, skip..." 

fi

echo "Enable and start hostapd and dnsmasq..."
systemctl enable hostapd
systemctl enable dnsmasq
sudo service hostapd start
sudo service dnsmasq start

echo "All done!"
echo "Please REBOOT using 'shutdown -r'."
echo "To change SSID '$APSSID', please edit using 'sudo nano /etc/hostapd/hostapd.conf'"
