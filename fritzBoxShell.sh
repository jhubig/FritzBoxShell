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

DIRECTORY=$(cd `dirname $0` && pwd)
source $DIRECTORY/fritzBoxShellConfig.sh

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

UPNPMetaData(){
		location="/tr64desc.xml"

		curl -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" http://$BoxIP:49000$location 
}

IGDMetaData(){
		location="/igddesc.xml"

		curl -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" http://$BoxIP:49000$location 
}

readout() {
		curlOutput1=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" http://$BoxIP:49000$location -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep "<New" | awk -F"</" '{print $1}' |sed -En "s/<(.*)>(.*)/\1 \2/p")
		echo "$curlOutput1"
}

WLANstatistics() {
		location="/upnp/control/wlanconfig1"
		uri="urn:dslforum-org:service:WLANConfiguration:1"
		action='GetStatistics'

		readout

		action='GetTotalAssociations'

		readout

		action='GetInfo'

		readout
		echo "NewGHz 2.4"
}

WLAN5statistics() {
		location="/upnp/control/wlanconfig2"
		uri="urn:dslforum-org:service:WLANConfiguration:2"
		action='GetStatistics'
		
		readout

		action='GetTotalAssociations'

		readout

		action='GetInfo'

		readout
		echo "NewGHz 5"
}

LANstate() {
		location="/upnp/control/lanethernetifcfg"
		uri="urn:dslforum-org:service:LANEthernetInterfaceConfig:1"
		action='GetStatistics'

		readout
}

DSLstate() {
		location="/igdupnp/control/wandslifconfig1"
		uri="urn:dslforum-org:service:WANDSLInterfaceConfig:1"
		action='GetInfo'

		readout
}

WANstate() {
		location="/upnp/control/wancommonifconfig1"
		uri="urn:dslforum-org:service:WANCommonInterfaceConfig:1"
		action='GetTotalBytesReceived'

		readout

		action='GetTotalBytesSent'

		readout

		action='GetTotalPacketsReceived'

		readout

		action='GetTotalPacketsSent'

		readout

		action='GetCommonLinkProperties'

		readout

		#action='GetInfo'

		#readout

}

WANDSLLINKstate() {
		location="/upnp/control/wandsllinkconfig1"
		uri="urn:dslforum-org:service:WANDSLLinkConfig:1"
		action='GetStatistics'

		readout

}

IGDWANstate() {
		location="/igdupnp/control/WANCommonIFC1"
		uri="urn:schemas-upnp-org:service:WANCommonInterfaceConfig:1"
		action='GetAddonInfos'

		readout

}

IGDDSLLINKstate() {
		location="/igdupnp/control/WANDSLLinkC1"
		uri="urn:schemas-upnp-org:service:WANDSLLinkConfig:1"
		action='GetDSLLinkInfo'

		readout

		action='GetAutoConfig'

		readout

		action='GetModulationType'

		readout

		action='GetDestinationAddress'

		readout

		action='GetATMEncapsulation'

		readout

		action='GetFCSPreserved'

		readout

}

IGDIPstate() {
		location="/igdupnp/control/WANIPConn1"
		uri="urn:schemas-upnp-org:service:WANIPConnection:1"
		action='GetConnectionTypeInfo'

		readout

		action='GetAutoDisconnectTime'

		readout

		action='GetIdleDisconnectTime'

		readout

		action='GetStatusInfo'

		readout

		action='GetNATRSIPStatus'

		readout

		action='GetExternalIPAddress'

		readout

		action='X_AVM_DE_GetExternalIPv6Address'

		readout

		action='X_AVM_DE_GetIPv6Prefix'

		readout

		action='X_AVM_DE_GetDNSServer'

		readout

		action='X_AVM_DE_GetIPv6DNSServer'

		readout

}

WLANstate() {

	# Building the inputs for the SOAP Action based on which WiFi to switch ON/OFF

	if [ $option1 = "WLAN_2G" ] || [ "$option1" = "WLAN" ]; then
		location="/upnp/control/wlanconfig1"
		uri="urn:dslforum-org:service:WLANConfiguration:1"
		action='SetEnable'
		if [ $option2 = "0" ] || [ "$option2" = "1" ]; then echo "Sending WLAN_2G $1"; curl -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" http://$BoxIP:49000$location -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'><NewEnable>$option2</NewEnable></u:$action></s:Body></s:Envelope>" -s > /dev/null; fi # Changing the state of the WIFI

		action='GetInfo'
		if [ $option2 = "STATE" ]; then
			curlOutput1=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" http://$BoxIP:49000$location -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewEnable | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
			curlOutput2=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" http://$BoxIP:49000$location -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewSSID | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
			echo "2,4 Ghz Network $curlOutput2 is $curlOutput1"
		fi
	fi

	if [ $option1 = "WLAN_5G" ] || [ "$option1" = "WLAN" ]; then
		location="/upnp/control/wlanconfig2"
		uri="urn:dslforum-org:service:WLANConfiguration:2"
		action='SetEnable'
		if [ $option2 = "0" ] || [ "$option2" = "1" ]; then echo "Sending WLAN_5G $1"; curl -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" http://$BoxIP:49000$location -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'><NewEnable>$option2</NewEnable></u:$action></s:Body></s:Envelope>" -s > /dev/null; fi # Changing the state of the WIFI

		action='GetInfo'
		if [ $option2 = "STATE" ]; then
			curlOutput1=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" http://$BoxIP:49000$location -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewEnable | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
			curlOutput2=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" http://$BoxIP:49000$location -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewSSID | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
			echo "  5 Ghz Network $curlOutput2 is $curlOutput1"
		fi
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

DisplayArguments() {
	echo ""
	echo "Invalid Action and/or parameter. Possible combinations:"
	echo ""
	echo "|----------|-----------------|----------------------------------------------------------------------|"
	echo "|  Action  | Parameter       | Description                                                          |"
	echo "|----------|-----------------|----------------------------------------------------------------------|"
	echo "| WLAN_2G  | 0 or 1 or STATE | Switching ON, OFF or checking the state of the 2,4 Ghz WiFi          |"
	echo "| WLAN_2G  | STATISTICS      | Statistics for the 2,4 Ghz WiFi easily digestible by telegraf        |"
	echo "| WLAN_5G  | 0 or 1 or STATE | Switching ON, OFF or checking the state of the 5 Ghz WiFi            |"
	echo "| WLAN_5G  | STATISTICS      | Statistics for the 5 Ghz WiFi easily digestible by telegraf          |"
	echo "| WLAN     | 0 or 1 or STATE | Switching ON, OFF or checking the state of the 2,4Ghz and 5 Ghz WiFi |"
	echo "| LAN      | STATE           | Statistics for the LAN easily digestible by telegraf                 |"
	echo "| DSL      | STATE           | Statistics for the DSL easily digestible by telegraf                 |"
	echo "| WAN      | STATE           | Statistics for the WAN easily digestible by telegraf                 |"
	echo "| LINK     | STATE           | Statistics for the WAN DSL LINK easily digestible by telegraf        |"
	echo "| IGDWAN   | STATE           | Statistics for the WAN LINK easily digestible by telegraf            |"
	echo "| IGDDSL   | STATE           | Statistics for the DSL LINK easily digestible by telegraf            |"
	echo "| IGDIP    | STATE           | Statistics for the DSL IP easily digestible by telegraf              |"
	echo "| REPEATER | 0               | Switching OFF the WiFi of the Repeater                               |"
	echo "| REBOOT   | Box or Repeater | Rebooting your Fritz!Box or Fritz!Repeater                           |"
	echo "|----------|-----------------|----------------------------------------------------------------------|"
	echo ""
}

# Check if an argument was supplied for shell script
if [ $# -eq 0 ]
then
  DisplayArguments
elif [ -z "$2" ]
then
	DisplayArguments
else
	#If argument was provided, check which function to be called
	if [ "$option1" = "WLAN_2G" ] || [ "$option1" = "WLAN_5G" ] || [ "$option1" = "WLAN" ]; then
		if [ "$option2" = "1" ]; then WLANstate "ON";
		elif [ "$option2" = "0" ]; then WLANstate "OFF";
		elif [ "$option2" = "STATE" ]; then WLANstate "STATE";
		elif [ "$option2" = "STATISTICS" ]; then
			if [ "$option1" = "WLAN_2G" ]; then WLANstatistics;
			elif [ "$option1" = "WLAN_5G" ]; then WLAN5statistics;
			else DisplayArguments
			fi
		else DisplayArguments
		fi
	elif [ "$option1" = "LAN" ]; then
		if [ "$option2" = "STATE" ]; then LANstate "$option2";
		else DisplayArguments
		fi
	elif [ "$option1" = "DSL" ]; then
		if [ "$option2" = "STATE" ]; then DSLstate "$option2";
		else DisplayArguments
		fi
	elif [ "$option1" = "WAN" ]; then
		if [ "$option2" = "STATE" ]; then WANstate "$option2";
		else DisplayArguments
		fi
	elif [ "$option1" = "LINK" ]; then
		if [ "$option2" = "STATE" ]; then WANDSLLINKstate "$option2";
		else DisplayArguments
		fi
	elif [ "$option1" = "IGDWAN" ]; then
		if [ "$option2" = "STATE" ]; then IGDWANstate "$option2";
		else DisplayArguments
		fi
	elif [ "$option1" = "IGDDSL" ]; then
		if [ "$option2" = "STATE" ]; then IGDDSLLINKstate "$option2";
		else DisplayArguments
		fi
	elif [ "$option1" = "IGDIP" ]; then
		if [ "$option2" = "STATE" ]; then IGDIPstate "$option2";
		else DisplayArguments
		fi
	elif [ "$option1" = "REPEATER" ]; then
		if [ "$option2" = "1" ]; then RepeaterWLANstate "ON"; # Usually this will not work because there is no connection possible to the Fritz!Repeater as long as WiFi is OFF
		elif [ "$option2" = "0" ]; then RepeaterWLANstate "OFF";
		else DisplayArguments
		fi
	elif [ "$option1" = "REBOOT" ]; then
		Reboot $option2
	else DisplayArguments
	fi
fi
