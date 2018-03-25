#!/bin/bash

#******************************************************#
#** Autor: Johannes Hubig <johannes.hubig@gmail.com> **#
#******************************************************#

# The following script should work from FritzOS 6.0 on-
# wards. Was tested successfully on FritzOS 6.93.

# Protokoll TR-064 was used to control the Fritz!Box.
# Additional info and documentation can be found here:

# http://fritz.box:49000/tr64desc.xml
# https://wiki.fhem.de/wiki/FRITZBOX#TR-064
# https://avm.de/service/schnittstellen/

#******************************************************#
#*********************** CONFIG ***********************#
#******************************************************#

IP="fritz.box" #IP address can also be used
USER="YourUserAccount"
PW="YourPassword"

#******************************************************#
#*********************** SCRIPT ***********************#
#******************************************************#

# Storing shell parameters in variables

option1=$1
option2=$2

WLANstate() {

	# Building the inputs for the SOAP Action based on which WiFi to switch ON/OFF

	if [ $option1 = "WLAN_2G" ] || [ "$option1" = "WLAN" ]; then
		location="/upnp/control/wlanconfig1"
		uri="urn:dslforum-org:service:WLANConfiguration:1"
		action='SetEnable'
		echo "Sending WLAN_2G $1"; curl -k -m 5 --anyauth -u "$USER:$PW" http://$IP:49000$location -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'><NewEnable>$option2</NewEnable></u:$action></s:Body></s:Envelope>" -s > /dev/null
	fi

	if [ $option1 = "WLAN_5G" ] || [ "$option1" = "WLAN" ]; then
		location="/upnp/control/wlanconfig2"
		uri="urn:dslforum-org:service:WLANConfiguration:2"
		action='SetEnable'
		echo "Sending WLAN_5G $1"; curl -k -m 5 --anyauth -u "$USER:$PW" http://$IP:49000$location -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'><NewEnable>$option2</NewEnable></u:$action></s:Body></s:Envelope>" -s > /dev/null
	fi
}

# Checking shell script parameters
if [ "$1" = "WLAN_2G" ] || [ "$1" = "WLAN_5G" ] || [ "$1" = "WLAN" ]; then
	if [ "$2" = "1" ]; then WLANstate "ON"; fi
	if [ "$2" = "0" ]; then WLANstate "OFF"; fi
fi
