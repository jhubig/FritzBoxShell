#!/bin/bash

#******************************************************#
#** Autor: Johannes Hubig <johannes.hubig@gmail.com> **#
#******************************************************#

# The following script should work from FritzOS 6.0 on-
# wards.
# Was tested successfully on:
#  * Fritz!Box 7490 FritzOS 6.93
#  * Fritz!Repeater 310 FritzOS 6.92

# Protokoll TR-064 was used to control the Fritz!Box and
# Fritz!Repeater. For sure not all commands are
# available on Fritz!Repeater.
# Additional info and documentation can be found here:

# http://fritz.box:49000/tr64desc.xml
# https://wiki.fhem.de/wiki/FRITZBOX#TR-064
# https://avm.de/service/schnittstellen/

#******************************************************#
#*********************** CONFIG ***********************#
#******************************************************#

# Fritz!Box Config
BoxIP="fritz.box"
BoxUSER="YourUser"
BoxPW="YourPassword"

# Fritz!Repeater Config
RepeaterIP="fritz.repeater"
RepeaterUSER="" #Usually on Fritz!Repeater no User is existing. Can be left empty.
RepeaterPW="YourPassword"

#******************************************************#
#*********************** SCRIPT ***********************#
#******************************************************#

# Storing shell parameters in variables
# Example:
# ./fritzBoxShell.sh WLAN_2G 1
# $1 = "WLAN_2G"
# $2 = "1"

option1=$1
option2=$2

WLANstate() {

	# Building the inputs for the SOAP Action based on which WiFi to switch ON/OFF

	if [ $option1 = "WLAN_2G" ] || [ "$option1" = "WLAN" ]; then
		location="/upnp/control/wlanconfig1"
		uri="urn:dslforum-org:service:WLANConfiguration:1"
		action='SetEnable'
		echo "Sending WLAN_2G $1"; curl -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" http://$BoxIP:49000$location -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'><NewEnable>$option2</NewEnable></u:$action></s:Body></s:Envelope>" -s > /dev/null
	fi

	if [ $option1 = "WLAN_5G" ] || [ "$option1" = "WLAN" ]; then
		location="/upnp/control/wlanconfig2"
		uri="urn:dslforum-org:service:WLANConfiguration:2"
		action='SetEnable'
		echo "Sending WLAN_5G $1"; curl -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" http://$BoxIP:49000$location -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'><NewEnable>$option2</NewEnable></u:$action></s:Body></s:Envelope>" -s > /dev/null
	fi
}

RepeaterWLANstate() {

	# Building the inputs for the SOAP Action

	location="/upnp/control/wlanconfig1"
	uri="urn:dslforum-org:service:WLANConfiguration:1"
	action='SetEnable'
	echo "Sending Repeater WLAN $1"; curl -k -m 5 --anyauth -u "$RepeaterUSER:$RepeaterPW" http://$RepeaterIP:49000$location -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'><NewEnable>$option2</NewEnable></u:$action></s:Body></s:Envelope>" -s > /dev/null

}

Reboot() {

	# Building the inputs for the SOAP Action

	location="/upnp/control/deviceconfig"
	uri="urn:dslforum-org:service:DeviceConfig:1"
	action='Reboot'
	if [[ "$option2" = "Box" ]]; then echo "Sending Reboot command to $1"; curl -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" http://$BoxIP:49000$location -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" -s > /dev/null; fi
	if [[ "$option2" = "Repeater" ]]; then echo "Sending Reboot command to $1"; curl -k -m 5 --anyauth -u "$RepeaterUSER:$RepeaterPW" http://$RepeaterIP:49000$location -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" -s > /dev/null; fi
}

# Check if an argument was supplied for shell script
if [ $# -eq 0 ]
then
  echo "No argument supplied. See readme (https://github.com/jhubig/FritzBoxShell/blob/master/README.md) for all possible actions and parameters."
elif [ -z "$2" ]
then
	echo "Second argument needed. See readme (https://github.com/jhubig/FritzBoxShell/blob/master/README.md) for all possible actions and parameters."
fi

#If argument was provided, check which function to be called
if [ "$option1" = "WLAN_2G" ] || [ "$option1" = "WLAN_5G" ] || [ "$option1" = "WLAN" ]; then
	if [ "$option2" = "1" ]; then WLANstate "ON"; fi
	if [ "$option2" = "0" ]; then WLANstate "OFF"; fi
elif [ "$option1" = "REPEATER" ]; then
	if [ "$option2" = "1" ]; then RepeaterWLANstate "ON"; fi # Usually this will not work because there is no connection possible to the Fritz!Repeater as long as WiFi is OFF
	if [ "$option2" = "0" ]; then RepeaterWLANstate "OFF"; fi
elif [ "$option1" = "REBOOT" ]; then
	Reboot $option2
fi
