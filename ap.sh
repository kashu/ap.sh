#!/bin/bash
#Author: kashu
#My Website: https://kashu.org
#Date: 2016-01-16
#Filename: ap.sh
#Description:  Create an Ad-Hoc wireless network on my Xubuntu laptop.
#More: https://help.ubuntu.com/community/WifiDocs/WirelessAccessPoint

help_info(){
	cat <<- 'EOF'
	Usage: $ ./ap.sh

	Exit Codes With Special Meanings:
	10	hostapd or isc-dhcp-server install failed.
	11	No device support AP mode.
	EOF
}

if [ "X$*" != "X" ]; then
  help_info
fi

# Required: hostapd isc-dhcp-server
dpkg -s hostapd isc-dhcp-server &> /dev/null || sudo apt-get install hostapd isc-dhcp-server -y
dpkg -s hostapd isc-dhcp-server &> /dev/null || { echo "hostapd or isc-dhcp-server install failed"; exit 10; }

pgrep hostapd
s=$?
if [ $s -eq 0 ]; then
	t=Enable; o=Disable; i='warning'
	zenity --question --window-icon=$i --title="Ad-Hoc status: *${t}d*" --text=" I want to [Enable] or [Disable] Ad-Hoc " --cancel-label=$t --ok-label=$o 
else
	t=Enable; o=Disable; i='error'
	zenity --question --window-icon=$i --title="Ad-Hoc status: *${o}d*" --text=" I want to [Enable] or [Disable] Ad-Hoc " --ok-label=$o --cancel-label=$t
fi

if [ $? -eq 0 ]; then
	if [ $s -eq 0 ]; then
		zenity --password --title=" [sudo] password for `id -nu`: "|sudo -S pkill hostapd
		sudo pkill dhcpd
		sudo nmcli nm wifi off
		exit
	else
			exit
	fi
else
	if [ $s -eq 0 ]; then
		exit
	fi
fi

# Check if there is any device support AP mode
`iw list | grep -sq "* AP"` || { echo "No device support AP mode." && exit 11; }

zenity --password --title=" [sudo] password for `id -nu`: " | sudo -S nmcli nm wifi off
sudo rfkill unblock wlan
sudo ifconfig wlan0 192.168.11.1 netmask 255.255.255.0
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -t nat -F
sudo iptables -t nat -A POSTROUTING -j MASQUERADE
sudo pkill -9 dhcpd

if [ ! -f /etc/apparmor.d/disable/usr.sbin.dhcpd ]; then
	sudo ln -s /etc/apparmor.d/usr.sbin.dhcpd /etc/apparmor.d/disable/
	sudo /etc/init.d/apparmor restart
fi

cat > /tmp/dhcpd.conf << EOF
default-lease-time 600;
max-lease-time 7200;
subnet 192.168.11.0 netmask 255.255.255.0
{
 range 192.168.11.100 192.168.11.110;
# Google Public DNS Server
 option domain-name-servers 8.8.8.8;
 option domain-name-servers 8.8.4.4;
 option routers 192.168.11.1;
}
EOF

sudo dhcpd -4 wlan0 -cf /tmp/dhcpd.conf -pf /var/run/dhcp-server/dhcpd.pid

cat > /tmp/hostapd.conf << EOF
interface=wlan0
driver=nl80211
ssid=kashu
hw_mode=g
channel=10
# wpa=1 for password access, wpa=0 for passwordless access.
wpa=1
auth_algs=1
wpa_passphrase=wifi_password
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

sudo hostapd -B /tmp/hostapd.conf
