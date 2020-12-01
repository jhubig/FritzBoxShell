#!/bin/bash
# shellcheck disable=SC1090,SC2154

#************************************************************#
#** Autor: Johannes Hubig <johannes.hubig@gmail.com>       **#
#** Autor: Jürgen Key https://elbosso.github.io/index.html **#
#************************************************************#

# The following script should work from FritzOS 6.0 on-
# wards.
#
# Protokoll TR-064 was used to control the Fritz!Box and
# Fritz!Repeater. For sure not all commands are
# available on Fritz!Repeater.
# Additional info and documentation can be found here:

# http://fritz.box:49000/tr64desc.xml
# https://wiki.fhem.de/wiki/FRITZBOX#TR-064
# https://avm.de/service/schnittstellen/

# AVM, FRITZ!, Fritz!Box and the FRITZ! logo are registered trademarks of AVM GmbH - https://avm.de/


version=1.0.5

dir=$(dirname "$0")

DIRECTORY=$(cd "$dir" && pwd)
source "$DIRECTORY/fritzBoxShellConfig.sh"

#******************************************************#
#*********************** SCRIPT ***********************#
#******************************************************#

# Parsing arguments
# Example:
# ./fritzBoxShell.sh --boxip 192.168.178.1 --boxuser foo --boxpw baa WLAN_2G 1
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
		--boxip)
    BoxIP="$2"
    shift ; shift
    ;;
		--boxuser)
    BoxUSER="$2"
    shift ; shift
    ;;
		--boxpw)
    BoxPW="$2"
    shift ; shift
    ;;
		--repeaterip)
    RepeaterIP="$2"
    shift ; shift
    ;;
		--repeateruser)
    RepeaterUSER="$2"
    shift ; shift
    ;;
		--repeaterpw)
    RepeaterPW="$2"
    shift ; shift
    ;;
		*)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
  esac
done

set -- "${POSITIONAL[@]}" # restore positional parameters

# Storing shell parameters in variables
# Example:
# ./fritzBoxShell.sh WLAN_2G 1
# $1 = "WLAN_2G"
# $2 = "1"

option1="$1"
option2="$2"
option3="$3"

### ----------------------------------------------------------------------------------------------------- ###
### --------- FUNCTION getSID is used to get a SID for all requests through AHA-HTTP-Interface----------- ###
### ------------------------------- SID is stored then in global variable ------------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

# Global variable for SID
SID=""

getSID(){
  location="/upnp/control/deviceconfig"
  uri="urn:dslforum-org:service:DeviceConfig:1"
  action='X_AVM-DE_CreateUrlSID'

  SID=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep "NewX_AVM-DE_UrlSID" | awk -F">" '{print $2}' | awk -F"<" '{print $1}' | awk -F"=" '{print $2}')
}

### ----------------------------------------------------------------------------------------------------- ###
### ----------- FUNCTION LEDswitch FOR SWITCHING ON OR OFF THE LEDS IN front of the Fritz!Box ----------- ###
### ----------------------------- Here the TR-064 protocol cannot be used. ------------------------------ ###
### ----------------------------------------------------------------------------------------------------- ###
### ---------------------------------------- AHA-HTTP-Interface ----------------------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

LEDswitch(){
	# Get the a valid SID
	getSID

	if [ "$option2" = "0" ]; then LEDstate=2; fi # When
	if [ "$option2" = "1" ]; then LEDstate=0; fi

	# led_display=0 -> ON
	# led_display=1 -> DELAYED ON (20200106: not really slower that option 0 - NOT USED)
	# led_display=2 -> OFF
	wget -O - --post-data sid=$SID\&led_display=$LEDstate\&apply= http://$BoxIP/system/led_display.lua 2>/dev/null
	if [ "$option2" = "0" ]; then echo "LEDs switched OFF"; fi
	if [ "$option2" = "1" ]; then echo "LEDs switched ON"; fi

	# Logout the "used" SID
	wget -O - "http://$BoxIP/home/home.lua?sid=$SID&logout=1" &>/dev/null
}

### ----------------------------------------------------------------------------------------------------- ###
### --------- FUNCTION keyLockSwitch FOR ACTIVATING or DEACTIVATING the buttons on the Fritz!Box -------- ###
### ----------------------------- Here the TR-064 protocol cannot be used. ------------------------------ ###
### ----------------------------------------------------------------------------------------------------- ###
### ---------------------------------------- AHA-HTTP-Interface ----------------------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

keyLockSwitch(){
	# Get the a valid SID
	getSID
	wget -O - --post-data sid=$SID\&keylock_enabled=$option2\&apply= http://$BoxIP/system/keylocker.lua 2>/dev/null
	if [ "$option2" = "0" ]; then echo "KeyLock NOT active"; fi
	if [ "$option2" = "1" ]; then echo "KeyLock active"; fi

	# Logout the "used" SID
	wget -O - "http://$BoxIP/home/home.lua?sid=$SID&logout=1" &>/dev/null
}

### ----------------------------------------------------------------------------------------------------- ###
### -------------------------------- FUNCTION readout - TR-064 Protocol --------------------------------- ###
### -- General function for sending the SOAP request via TR-064 Protocol - called from other functions -- ###
### ----------------------------------------------------------------------------------------------------- ###

readout() {
		curlOutput1=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep "<New" | awk -F"</" '{print $1}' |sed -En "s/<(.*)>(.*)/\1 \2/p")
		echo "$curlOutput1"
}

### ----------------------------------------------------------------------------------------------------- ###
### ------------------------------ FUNCTION UPNPMetaData - TR-064 Protocol ------------------------------ ###
### ----------------------------------------------------------------------------------------------------- ###

UPNPMetaData(){
		location="/tr64desc.xml"

		if [ "$option2" = "STATE" ]; then curl -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location"
	else curl -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" >"$DIRECTORY/$option2"
		fi
}

### ----------------------------------------------------------------------------------------------------- ###
### ------------------------------ FUNCTION IGDMetaData - TR-064 Protocol ------------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

IGDMetaData(){
		location="/igddesc.xml"

		if [ "$option2" = "STATE" ]; then curl -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location"
	else curl -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" >"$DIRECTORY/$option2"
		fi
}

### ----------------------------------------------------------------------------------------------------- ###
### ---- FUNCTION getWLANGUESTNum returns WLAN-Guest service number (if available) - TR-064 Protocol ---- ###
### ----------------------------------------------------------------------------------------------------- ###

getWLANGUESTNum() {
    for wlanNum in {2..4}; do
        location="/upnp/control/wlanconfig$wlanNum"
        uri="urn:dslforum-org:service:WLANConfiguration:$wlanNum"
        action="X_AVM-DE_GetWLANExtInfo"

        wlanType=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewX_AVM-DE_APType | awk -F">" '{print $2}' | awk -F"<" '{print $1}')

        if [ "$wlanType" = "guest" ]; then
            echo $wlanNum
			break
        fi
    done
}

### ----------------------------------------------------------------------------------------------------- ###
### ----------------------- FUNCTION WLANstatistics for 2.4 Ghz - TR-064 Protocol ----------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

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

### ----------------------------------------------------------------------------------------------------- ###
### ------------------------ FUNCTION WLANstatistics for 5 Ghz - TR-064 Protocol ------------------------ ###
### ----------------------------------------------------------------------------------------------------- ###

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

### ----------------------------------------------------------------------------------------------------- ###
### -------------------- FUNCTION WLANstatistics for Guest Network - TR-064 Protocol -------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

WLANGUESTstatistics() {
		wlanNum=$(getWLANGUESTNum)
		if [ -z $wlanNum ]; then
			echo "Guest Network not available"
		else
			location="/upnp/control/wlanconfig$wlanNum"
			uri="urn:dslforum-org:service:WLANConfiguration:$wlanNum"
			action='GetStatistics'

			readout

			action='GetTotalAssociations'

			readout

			action='GetInfo'

			readout
		fi		
}

### ----------------------------------------------------------------------------------------------------- ###
### -------------------------------- FUNCTION LANstate - TR-064 Protocol -------------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

LANstate() {
		location="/upnp/control/lanethernetifcfg"
		uri="urn:dslforum-org:service:LANEthernetInterfaceConfig:1"
		action='GetStatistics'

		readout
}

### ----------------------------------------------------------------------------------------------------- ###
### -------------------------------- FUNCTION DSLstate - TR-064 Protocol -------------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

DSLstate() {
		location="/upnp/control/wandslifconfig1"
		uri="urn:dslforum-org:service:WANDSLInterfaceConfig:1"
		action='GetInfo'

		readout
}

### ----------------------------------------------------------------------------------------------------- ###
### -------------------------------- FUNCTION WANstate - TR-064 Protocol -------------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

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

### ----------------------------------------------------------------------------------------------------- ###
### ---------------------------- FUNCTION WANDSLLINKstate - TR-064 Protocol ----------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

WANDSLLINKstate() {
		location="/upnp/control/wandsllinkconfig1"
		uri="urn:dslforum-org:service:WANDSLLinkConfig:1"
		action='GetStatistics'

		readout

}

### ----------------------------------------------------------------------------------------------------- ###
### ------------------------------ FUNCTION IGDWANstate - TR-064 Protocol ------------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

IGDWANstate() {
		location="/igdupnp/control/WANCommonIFC1"
		uri="urn:schemas-upnp-org:service:WANCommonInterfaceConfig:1"
		action='GetAddonInfos'

		readout

}

### ----------------------------------------------------------------------------------------------------- ###
### ---------------------------- FUNCTION IGDDSLLINKstate - TR-064 Protocol ----------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

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

### ----------------------------------------------------------------------------------------------------- ###
### ------------------------------ FUNCTION IGDIPstate - TR-064 Protocol -------------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

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

### ----------------------------------------------------------------------------------------------------- ###
### ------------------------------ FUNCTION Deviceinfo - TR-064 Protocol -------------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

Deviceinfo() {
		location="/upnp/control/deviceinfo"
		uri="urn:dslforum-org:service:DeviceInfo:1"
		action='GetInfo'

		readout

#		location="/upnp/control/userif"
#		uri="urn:dslforum-org:service:UserInterface:1"
#		action='X_AVM-DE_GetInfo'

#		readout

}

### ----------------------------------------------------------------------------------------------------- ###
### --------------------------------- FUNCTION TAM - TR-064 Protocol ------------------------------------ ###
### -- Function to switch ON or OFF the answering machine and getting info about the answering machine -- ###
### ----------------------------------------------------------------------------------------------------- ###

TAM() {
		location="/upnp/control/x_tam"
		uri="urn:dslforum-org:service:X_AVM-DE_TAM:1"

		if [ "$option3" = "GetInfo" ]; then
			action='GetInfo'
			curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'><NewIndex>$option2</NewIndex></u:$action></s:Body></s:Envelope>" | grep "<New" | awk -F"</" '{print $1}' |sed -En "s/<(.*)>(.*)/\1 \2/p"

		# Switch ON the TAM
	elif [ "$option3" = "ON" ]; then
			action='SetEnable'
			curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'><NewIndex>$option2</NewIndex><NewEnable>1</NewEnable></u:$action></s:Body></s:Envelope>" | grep "<New" | awk -F"</" '{print $1}' |sed -En "s/<(.*)>(.*)/\1 \2/p"
			echo "Answering machine is switched ON"

		# Switch OFF the TAM
	elif [ "$option3" = "OFF" ]; then
			action='SetEnable'
			curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'><NewIndex>$option2</NewIndex><NewEnable>0</NewEnable></u:$action></s:Body></s:Envelope>" | grep "<New" | awk -F"</" '{print $1}' |sed -En "s/<(.*)>(.*)/\1 \2/p"
			echo "Answering machine is switched OFF"

		# Get CallList from TAM
	elif [ "$option3" = "GetMsgs" ]; then
			action='GetMessageList'
			curlOutput1=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'><NewIndex>$option2</NewIndex></u:$action></s:Body></s:Envelope>" | grep "<New" | awk -F"</" '{print $1}' |sed -En "s/<(.*)>(.*)/\1 \2/p")

			#WGETresult=$(wget -O - "$curlOutput1" 2>/dev/null) Doesn't work with double quotes. Therefore in line below the shellcheck fails.
			WGETresult=$(wget -O - $curlOutput1 2>/dev/null)
			echo "$WGETresult"

		fi
}

### ----------------------------------------------------------------------------------------------------- ###
### ------------------------------ FUNCTION WLANstate - TR-064 Protocol --------------------------------- ###
### ----- Function to switch ON or OFF 2.4 and/or 5 Ghz WiFi and also getting the state of the WiFi ----- ###
### ----------------------------------------------------------------------------------------------------- ###

WLANstate() {

	# Building the inputs for the SOAP Action based on which WiFi to switch ON/OFF

	if [ "$option1" = "WLAN_2G" ] || [ "$option1" = "WLAN" ]; then
		location="/upnp/control/wlanconfig1"
		uri="urn:dslforum-org:service:WLANConfiguration:1"
		action='SetEnable'
		if [ "$option2" = "0" ] || [ "$option2" = "1" ]; then echo "Sending WLAN_2G $1"; curl -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'><NewEnable>$option2</NewEnable></u:$action></s:Body></s:Envelope>" -s > /dev/null; fi # Changing the state of the WIFI

		action='GetInfo'
		if [ "$option2" = "STATE" ]; then
			curlOutput1=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewEnable | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
			curlOutput2=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewSSID | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
			echo "2,4 Ghz Network $curlOutput2 is $curlOutput1"
		fi
	fi

	if [ "$option1" = "WLAN_5G" ] || [ "$option1" = "WLAN" ]; then
		location="/upnp/control/wlanconfig2"
		uri="urn:dslforum-org:service:WLANConfiguration:2"
		action='SetEnable'
		if [ "$option2" = "0" ] || [ "$option2" = "1" ]; then echo "Sending WLAN_5G $1"; curl -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'><NewEnable>$option2</NewEnable></u:$action></s:Body></s:Envelope>" -s > /dev/null; fi # Changing the state of the WIFI

		action='GetInfo'
		if [ "$option2" = "STATE" ]; then
			curlOutput1=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewEnable | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
			curlOutput2=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewSSID | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
			echo "  5 Ghz Network $curlOutput2 is $curlOutput1"
		fi
	fi

	if [ "$option1" = "WLAN_GUEST" ] || [ "$option1" = "WLAN" ]; then
		wlanNum=$(getWLANGUESTNum)
		if [ -z $wlanNum ]; then
			echo "Guest Network not available"
		else
			location="/upnp/control/wlanconfig$wlanNum"
			uri="urn:dslforum-org:service:WLANConfiguration:$wlanNum"
			action='SetEnable'
			if [ "$option2" = "0" ] || [ "$option2" = "1" ]; then echo "Sending WLAN_GUEST $1"; curl -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'><NewEnable>$option2</NewEnable></u:$action></s:Body></s:Envelope>" -s > /dev/null; fi # Changing the state of the WIFI

			action='GetInfo'
			if [ "$option2" = "STATE" ]; then
				curlOutput1=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewEnable | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
				curlOutput2=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewSSID | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
				echo "  Guest Network $curlOutput2 is $curlOutput1"
			fi
		fi
	fi
}

### ----------------------------------------------------------------------------------------------------- ###
### --------------------------- FUNCTION RepeaterWLANstate - TR-064 Protocol ---------------------------- ###
### -------------------------- Function to switch OFF the WiFi of the repeater -------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

RepeaterWLANstate() {

	# Building the inputs for the SOAP Action

	location="/upnp/control/wlanconfig1"
	uri="urn:dslforum-org:service:WLANConfiguration:1"
	action='SetEnable'
	echo "Sending Repeater WLAN $1"; curl -k -m 5 --anyauth -u "$RepeaterUSER:$RepeaterPW" "http://$RepeaterIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'><NewEnable>$option2</NewEnable></u:$action></s:Body></s:Envelope>" -s > /dev/null

}

### ----------------------------------------------------------------------------------------------------- ###
### --------------------------------- FUNCTION Reboot - TR-064 Protocol --------------------------------- ###
### ------------------------ Function to reboot the Fritz!Box or Fritz!Repeater ------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

Reboot() {

	# Building the inputs for the SOAP Action

	location="/upnp/control/deviceconfig"
	uri="urn:dslforum-org:service:DeviceConfig:1"
	action='Reboot'
	if [[ "$option2" = "Box" ]]; then echo "Sending Reboot command to $1"; curl -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" -s > /dev/null; fi
	if [[ "$option2" = "Repeater" ]]; then echo "Sending Reboot command to $1"; curl -k -m 5 --anyauth -u "$RepeaterUSER:$RepeaterPW" "http://$RepeaterIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" -s > /dev/null; fi
}

### ----------------------------------------------------------------------------------------------------- ###
### ------------------------------------- FUNCTION script_version --------------------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

script_version(){
		echo "fritzBoxShell.sh version ${version}"
}

DisplayArguments() {
	echo ""
	echo "Invalid Action and/or parameter. Possible combinations:"
	echo ""
	echo "|--------------|------------------------|-------------------------------------------------------------------------|"
	echo "|  Action      | Parameter              | Description                                                             |"
	echo "|--------------|------------------------|-------------------------------------------------------------------------|"
	echo "|--------------|------------------------|-------------------------------------------------------------------------|"
	echo "| DEVICEINFO   | STATE                  | Show information about your Fritz!Box like ModelName, SN, etc.          |"
	echo "| WLAN_2G      | 0 or 1 or STATE        | Switching ON, OFF or checking the state of the 2,4 Ghz WiFi             |"
	echo "| WLAN_2G      | STATISTICS             | Statistics for the 2,4 Ghz WiFi easily digestible by telegraf           |"
	echo "| WLAN_5G      | 0 or 1 or STATE        | Switching ON, OFF or checking the state of the 5 Ghz WiFi               |"
	echo "| WLAN_5G      | STATISTICS             | Statistics for the 5 Ghz WiFi easily digestible by telegraf             |"
	echo "| WLAN_GUEST   | 0 or 1 or STATE        | Switching ON, OFF or checking the state of the Guest WiFi               |"
	echo "| WLAN_GUEST   | STATISTICS             | Statistics for the Guest WiFi easily digestible by telegraf             |"
	echo "| WLAN         | 0 or 1 or STATE        | Switching ON, OFF or checking the state of the 2,4Ghz and 5 Ghz WiFi    |"
	echo "|--------------|------------------------|-------------------------------------------------------------------------|"
	echo "| TAM          | <index> and GetInfo    | e.g. TAM 0 GetInfo (gives info about answering machine)                 |"
	echo "| TAM          | <index> and ON or OFF  | e.g. TAM 0 ON (switches ON the answering machine)                       |"
	echo "| TAM          | <index> and GetMsgs    | e.g. TAM 0 GetMsgs (gives XML formatted list of messages)               |"
	echo "|--------------|------------------------|-------------------------------------------------------------------------|"
	echo "| LED          | 0 or 1                 | Switching ON (1) or OFF (0) the LEDs in front of the Fritz!Box          |"
	echo "| KEYLOCK      | 0 or 1                 | Activate (1) or deactivate (0) the Keylock (buttons de- or activated)   |"
	echo "|--------------|------------------------|-------------------------------------------------------------------------|"
	echo "| LAN          | STATE                  | Statistics for the LAN easily digestible by telegraf                    |"
	echo "| DSL          | STATE                  | Statistics for the DSL easily digestible by telegraf                    |"
	echo "| WAN          | STATE                  | Statistics for the WAN easily digestible by telegraf                    |"
	echo "| LINK         | STATE                  | Statistics for the WAN DSL LINK easily digestible by telegraf           |"
	echo "| IGDWAN       | STATE                  | Statistics for the WAN LINK easily digestible by telegraf               |"
	echo "| IGDDSL       | STATE                  | Statistics for the DSL LINK easily digestible by telegraf               |"
	echo "| IGDIP        | STATE                  | Statistics for the DSL IP easily digestible by telegraf                 |"
	echo "| REPEATER     | 0                      | Switching OFF the WiFi of the Repeater                                  |"
	echo "| REBOOT       | Box or Repeater        | Rebooting your Fritz!Box or Fritz!Repeater                              |"
	echo "| UPNPMetaData | STATE or <filename>    | Full unformatted output of tr64desc.xml to console or file              |"
	echo "| IGDMetaData  | STATE or <filename>    | Full unformatted output of igddesc.xml to console or file               |"
	echo "|--------------|------------------------|-------------------------------------------------------------------------|"
	echo "| VERSION      |                        | Version of the fritzBoxShell.sh                                         |"
	echo "|--------------|------------------------|-------------------------------------------------------------------------|"
	echo ""
}

# Check if an argument was supplied for shell script
if [ $# -eq 0 ]
then
  DisplayArguments
elif [ -z "$2" ]
then
        if [ "$option1" = "VERSION" ]; then
                script_version
        else DisplayArguments
        fi
else
	#If argument was provided, check which function to be called
	if [ "$option1" = "WLAN_2G" ] || [ "$option1" = "WLAN_5G" ] || [ "$option1" = "WLAN_GUEST" ] || [ "$option1" = "WLAN" ]; then
		if [ "$option2" = "1" ]; then WLANstate "ON";
		elif [ "$option2" = "0" ]; then WLANstate "OFF";
		elif [ "$option2" = "STATE" ]; then WLANstate "STATE";
		elif [ "$option2" = "STATISTICS" ]; then
			if [ "$option1" = "WLAN_2G" ]; then WLANstatistics;
			elif [ "$option1" = "WLAN_5G" ]; then WLAN5statistics;
			elif [ "$option1" = "WLAN_GUEST" ]; then WLANGUESTstatistics;
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
	elif [ "$option1" = "UPNPMetaData" ]; then
		UPNPMetaData "$option2";
	elif [ "$option1" = "IGDMetaData" ]; then
		IGDMetaData "$option2";
	elif [ "$option1" = "DEVICEINFO" ]; then
		Deviceinfo "$option2";
	elif [ "$option1" = "LED" ]; then
		LEDswitch "$option2";
	elif [ "$option1" = "KEYLOCK" ]; then
		keyLockSwitch "$option2";
	elif [ "$option1" = "TAM" ]; then
		if [[ $option2 =~ ^[+-]?[0-9]+$ ]] && { [ "$option3" = "GetInfo" ] || [ "$option3" = "ON" ] || [ "$option3" = "OFF" ] || [ "$option3" = "GetMsgs" ];}; then TAM
		else DisplayArguments
		fi
	elif [ "$option1" = "REPEATER" ]; then
		if [ "$option2" = "1" ]; then RepeaterWLANstate "ON"; # Usually this will not work because there is no connection possible to the Fritz!Repeater as long as WiFi is OFF
		elif [ "$option2" = "0" ]; then RepeaterWLANstate "OFF";
		else DisplayArguments
		fi
	elif [ "$option1" = "REBOOT" ]; then
		Reboot "$option2"
	else DisplayArguments
	fi
fi
