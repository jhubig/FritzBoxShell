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


version=1.0.dev

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
    -O|--outputformat)
    OutputFormat="$2"
    shift ; shift
    ;;
    -F|--outputfilter)
    OutputFilter="$2"
    shift ; shift
    ;;
		*)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
  esac
done

set -- "${POSITIONAL[@]}" # restore positional parameters

# handle output format as wrapper to self
if [ -n "$OutputFormat" ]; then
  # call self again with arguments
  export BoxIP BoxUSER BoxPW RepeaterIP RepeaterUSER RepeaterPW
  output=$($0 $*)
  rc=$?

  if [ $rc -ne 0 ]; then
    echo "$(basename "$0"): error occured, output suppressed because option '-O|--outputformat ...' is provided" >&2
    exit $rc
  fi

  if [ -n "$OutputFilter" ]; then
    # apply output filter
    output=$(echo "$output" | egrep $OutputFilter)
  fi

  # quote non-numbered values (skip empty lines)
  output=$(echo "$output" | awk 'length($0) > 0 { if ($2 ~ "^[0-9]+$") print $1 " " $2; else print $1 " \"" $2 "\""; }')

  case $OutputFormat in
    influx)
      # convert to influx input data string with prefix 'fritz'
      echo "$output" | tr '\n' ',' | tr ' ' '=' | sed "s/,$//" | echo "fritz $(cat -)"
      exit $rc
      ;;
    graphite)
      # convert to . separated key=value (skip empty lines)
      echo "$output" | awk 'length($0) > 0 { print "fritz." $1 "=" $2 }'
      exit $rc
      ;;
    mrtg)
      # convert to 2-line separated bytes received/sent value
      echo "$output" | awk '$1 ~ /Bytes(Received|Sent)$/ { print $2 }'
      exit $rc
      ;;
    *)
      # unsupported OutputFormat
      echo "$(basename "$0"): error occured, '-O|--outputformat ...' active, but format not supported: $OutputFormat" >&2
      exit 1
      ;;
  esac
fi

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
### ---------------------- FUNCTION SetInternet FOR allowing / disallowing Internet --------------------- ###
### ----------------------------- Here the TR-064 protocol cannot be used. ------------------------------ ###
### ----------------------------------------------------------------------------------------------------- ###
### ---------------------------------------- AHA-HTTP-Interface ----------------------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

SetInternet(){
        # Get the a valid SID
        getSID

        # param2 = profile
        # param3 = on/off

        wget -O /dev/null --post-data "sid=$SID&toBeBlocked=$option2&blocked=$option3&page=kidLis" "http://$BoxIP/data.lua" 2>/dev/null
        echo "Kindersicherung für $option2 steht auf $option3"

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

	# led_display=0 -> ON
	# led_display=1 -> DELAYED ON (20200106: not really slower that option 0 - NOT USED)
	# led_display=2 -> OFF
	if [ "$option2" = "0" ]; then LEDstate=2; fi # When
	if [ "$option2" = "1" ]; then LEDstate=0; fi

	# Check if device supports LED dimming
	json=$(wget -q -O - --post-data "xhr=1&sid=$SID&page=led" "http://$BoxIP/data.lua" | tr -d '"')
	if grep -q 'canDim:1' <<< "$json"
	then
		# Extract LED brightness
		dim=$(grep -o 'dimValue:[[:digit:]]*' <<< "$json" | cut -d : -f 2)
		[[ -z "$dim" || "$dim" -lt 1 || "$dim" -gt 3 ]] && dim=3

		wget -O /dev/null --post-data "sid=$SID&led_brightness=$dim&dimValue=$dim&led_display=$LEDstate&ledDisplay=$LEDstate&page=led&apply=" "http://$BoxIP/data.lua" 2>/dev/null

	else

		# For newer FritzOS (>5.5)
		if grep -q 'ledDisplay:' <<< "$json"
		then
			wget -O - --post-data "sid=$SID&apply=&page=led&ledDisplay=$LEDstate" "http://$BoxIP/data.lua" &>/dev/null
		else
			wget -O - --post-data "sid=$SID&led_display=$LEDstate&apply=" "http://$BoxIP/system/led_display.lua" &>/dev/null
		fi

	fi

	if [ "$option2" = "0" ]; then echo "LEDs switched OFF"; fi
	if [ "$option2" = "1" ]; then echo "LEDs switched ON"; fi

	# Logout the "used" SID
	wget -O - "http://$BoxIP/home/home.lua?sid=$SID&logout=1" &>/dev/null
}

### ----------------------------------------------------------------------------------------------------- ###
### ------ FUNCTION LEDbrightness FOR SETTING THE BRIGHTNESS OF THE LEDS IN front of the Fritz!Box ------ ###
### ----------------------------- Here the TR-064 protocol cannot be used. ------------------------------ ###
### ----------------------------------------------------------------------------------------------------- ###
### ---------------------------------------- AHA-HTTP-Interface ----------------------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

LEDbrightness(){
	# Get the a valid SID
	getSID

	# led_display=0 -> ON
	# led_display=1 -> DELAYED ON (20200106: not really slower that option 0 - NOT USED)
	# led_display=2 -> OFF

	# Check if device supports LED dimming
	json=$(wget -q -O - --post-data "xhr=1&sid=$SID&page=led" "http://$BoxIP/data.lua" | tr -d '"')
	if grep -q 'canDim:1' <<< "$json"
	then
		# Extract LED state
		display=$(grep -o 'ledDisplay:[[:digit:]]*' <<< "$json" | cut -d : -f 2)
		[[ -z "$display" || "$display" -lt 0 || "$display" -gt 2 ]] && display=0

		# Extract LED brightness
		dim=$(grep -o 'dimValue:[[:digit:]]*' <<< "$json" | cut -d : -f 2)
		[[ -z "$dim" || "$dim" -lt 1 || "$dim" -gt 3 ]] && dim=3

		if [ "$option2" -eq 0 ]
		then
			display=2
		else
			display=0
			dim=$option2
		fi

		wget -O /dev/null --post-data "sid=$SID&led_brightness=$dim&dimValue=$dim&led_display=$display&ledDisplay=$display&page=led&apply=" "http://$BoxIP/data.lua" 2>/dev/null
		echo "Brightness set to $dim; LEDs switched $(if [ "$display" -eq 2 ]; then echo "OFF"; else echo "ON"; fi)"
	else
		echo "Brightness setting on this FritzBox not possible."
	fi

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
	wget -O - --post-data "sid=$SID&keylock_enabled=$option2&apply=" "http://$BoxIP/system/keylocker.lua" 2>/dev/null
	if [ "$option2" = "0" ]; then echo "KeyLock NOT active"; fi
	if [ "$option2" = "1" ]; then echo "KeyLock active"; fi

	# Logout the "used" SID
	wget -O - "http://$BoxIP/home/home.lua?sid=$SID&logout=1" &>/dev/null
}

### ----------------------------------------------------------------------------------------------------- ###
### ---------------------------------- FUNCTION SIGNAL STRENGTH change ---------------------------------- ###
### ----------------------------- Here the TR-064 protocol cannot be used. ------------------------------ ###
### ----------------------------------------------------------------------------------------------------- ###
### ---------------------------------------- AHA-HTTP-Interface ----------------------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

SignalStrengthChange(){
	# Get the a valid SID
	getSID

	# Check for possible values for signal strength
	# {"value":"1","text":"100 %"},{"value":"2","text":"50 %"},{"value":"3","text":"25 %"},{"value":"4","text":"12 %"},{"value":"5","text":"6 %"}

	if [ "$option2" = "100" ]; then SIGNALStrengthlevel=1;
		elif [ "$option2" = "50" ]; then SIGNALStrengthlevel=2;
		elif [ "$option2" = "25" ]; then SIGNALStrengthlevel=3;
		elif [ "$option2" = "12" ]; then SIGNALStrengthlevel=4;
		elif [ "$option2" = "6" ]; then SIGNALStrengthlevel=5;
		else DisplayArguments # No valid input given
	fi

	wget -O - --post-data "xhr=1&sid=$SID&page=chan&channelSelectMode=manual&autopowerlevel=$SIGNALStrengthlevel&apply=" "http://$BoxIP/data.lua" &>/dev/null

	# Logout the "used" SID
	wget -O - "http://$BoxIP/home/home.lua?sid=$SID&logout=1" &>/dev/null
}

### ----------------------------------------------------------------------------------------------------- ###
### ---------------------------- FUNCTION WIREGUARD VPN connection change ------------------------------- ###
### ----------------------------- Here the TR-064 protocol cannot be used. ------------------------------ ###
### ----------------------------------------------------------------------------------------------------- ###
### ---------------------------------------- AHA-HTTP-Interface ----------------------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

WireguardVPNstate(){
	# Get the a valid SID
	getSID

	connectionName="$option2"

	if [ "$option3" != "0" ] && [ "$option3" != "1" ]; then echo "Add 0 for switching OFF or 1 for switching ON."
	else
		connectionState=$option3
		if [ "$connectionState" = "1" ]; then connectionStateString="on";
		elif [ "$connectionState" = "0" ]; then connectionStateString="off";
		fi
		# Get the connection ID
		connectionID=$(wget -O - --post-data "xhr=1&sid=$SID&page=shareWireguard&xhrId=all" "http://$BoxIP/data.lua" 2>/dev/null | jq '.data.init.boxConnections | to_entries[] | select( .value.name == "'"$connectionName"'" ) | .key' | tr -d '"')
		
		# Switch on/off the connection if the connection was found
		if [ "$connectionID" != "" ]; then
			wget -O - --post-data "xhr=1&sid=$SID&page=shareWireguard&$connectionID=$connectionStateString&active_$connectionID=$connectionState&apply=" "http://$BoxIP/data.lua" &>/dev/null
			echo "$connectionName ($connectionID) successfuly switched $connectionStateString."
		elif [ "$connectionID" == "" ]; then
			echo "$connectionName not found."
		fi

	fi

	# Logout the "used" SID
	wget -O - "http://$BoxIP/home/home.lua?sid=$SID&logout=1" &>/dev/null
}

### ----------------------------------------------------------------------------------------------------- ###
### ------------------------------ FUNCTION to readout misc from data.lua ------------------------------- ###
### ----------------------------- Here the TR-064 protocol cannot be used. ------------------------------ ###
### ----------------------------------------------------------------------------------------------------- ###
### ---------------------------------------- AHA-HTTP-Interface ----------------------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

LUAmisc(){
	# Get the a valid SID
	getSID

	overview=$(wget -O - --post-data "xhr=1&sid=$SID&page=overview&xhrId=first&noMenuRef=1" "http://$BoxIP/data.lua" 2>/dev/null)

	# This could be extended in the future to also get other information
	if [ "$option2" == "totalConnectionsWLAN" ]; then
		# - not working on all machines - maybe linked to different jq versions - Works with 1.7 but not with 1.5 and 1.6
		# totalConnectionsWLAN=$(wget -O - --post-data "xhr=1&sid=$SID&page=overview&xhrId=first&noMenuRef=1" "http://$BoxIP/data.lua" 2>/dev/null | jq '.data.net.devices.[] | select(.type=="wlan" ) | length' | wc -l)
		
		totalConnectionsWLAN2G=$(grep -ow '"desc":"2,4 GHz"' <<< $overview | wc -l)
		totalConnectionsWLAN5G=$(grep -ow '"desc":"5 GHz"' <<< $overview | wc -l)
		totalConnectionsWLANguest=$(grep -ow '"guest":true,"online"' <<< $overview | wc -l)
		echo "2,4G WLAN: $totalConnectionsWLAN2G"
		echo "5G WLAN: $totalConnectionsWLAN5G"
		echo "Guest WLAN: $totalConnectionsWLANguest"
	elif [ "$option2" == "totalConnectionsWLAN2G" ]; then
		totalConnectionsWLAN2G=$(grep -ow '"desc":"2,4 GHz"' <<< $overview | wc -l)
		echo $totalConnectionsWLAN2G
	elif [ "$option2" == "totalConnectionsWLAN5G" ]; then
		totalConnectionsWLAN5G=$(grep -ow '"desc":"5 GHz"' <<< $overview | wc -l)
		echo $totalConnectionsWLAN5G
	elif [ "$option2" == "totalConnectionsWLANguest" ]; then
		totalConnectionsWLANguest=$(grep -ow '"guest":true,"online"' <<< $overview | wc -l)
		echo $totalConnectionsWLANguest
	elif [ "$option2" == "totalConnectionsLAN" ]; then
		# - not working on all machines - maybe linked to different jq versions - Works with 1.7 but not with 1.5 and 1.6
		# totalConnectionsLAN=$(wget -O - --post-data "xhr=1&sid=$SID&page=overview&xhrId=first&noMenuRef=1" "http://$BoxIP/data.lua" 2>/dev/null | jq '.data.net.devices.[] | select(.type=="lan" ) | length' | wc -l)
		
		totalConnectionsLAN=$(echo $overview | grep -ow '"type":"lan"' | wc -l)
		echo $totalConnectionsLAN
	fi

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
		if [ -z "$wlanNum" ]; then
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
### -------------------------------- FUNCTION WANreconnect - TR-064 Protocol -------------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

WANreconnect() {

    #Display IP Address before reconnect
    location="/igdupnp/control/WANIPConn1"
    uri="urn:schemas-upnp-org:service:WANIPConnection:1"
    action='GetConnectionTypeInfo'

    action='GetExternalIPAddress'

    readout

    location="/igdupnp/control/WANIPConn1"
		uri="urn:schemas-upnp-org:service:WANIPConnection:1"
		action='ForceTermination'

    echo ""
    echo "WAN RECONNECT initiated - Waiting for new IP... (30 seconds)"

    curl -s "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?> <s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'> <s:Body> <u:$action xmlns:u='$uri' /> </s:Body> </s:Envelope>" &>/dev/null

    sleep 30

    echo ""
    echo "FINISHED. Find new IP Address below:"

    #Display IP Address after reconnect
    location="/igdupnp/control/WANIPConn1"
    uri="urn:schemas-upnp-org:service:WANIPConnection:1"
    action='GetConnectionTypeInfo'

    action='GetExternalIPAddress'

    readout

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
			WGETresult=$(wget -O - "$curlOutput1" 2>/dev/null)
			echo "$WGETresult"

		fi
}

### ----------------------------------------------------------------------------------------------------- ###
### -------------------------------- FUNCTION OnTel - TR-064 Protocol ----------------------------------- ###
### ---------------------- Function to get the call list for a given number of days --------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

OnTel() {
		location="/upnp/control/x_contact"
		uri="urn:dslforum-org:service:X_AVM-DE_OnTel:1"

		if [ "$option2" = "GetCallList" ]; then
			action='GetCallList'
			listurl=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep "<New" | awk -F"</" '{print $1}' | sed -En "s/<(.*)>(.*)/\1 \2/p" | awk '{print $2}')
			curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "$listurl&days=$option3"
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

		action='SetChannel'
		if [ "$option2" = "CHANGECH" ]; then
			channels=("1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13")
			case " ${channels[*]} " in
				*" $option3 "*) 
					NEW_CH="$option3"
    				;;
				*)
					NEW_CH=$( shuf -e ${channels[@]} -n1 )
    				;;
			esac
			echo "2.4Ghz: Change channel"; curl -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'><NewChannel>$NEW_CH</NewChannel></u:$action></s:Body></s:Envelope>" -s > /dev/null;
			echo "2.4Ghz: Channel changed to $NEW_CH"
		fi


		action='GetSSID'
		if [ "$option2" =  "QRCODE" ]; then
			ssid=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewSSID | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
			action='GetSecurityKeys'
			keyPassphrase=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewKeyPassphrase | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
			echo "QR Code for 2,4 Ghz:"
			qrencode -t ansiutf8 "WIFI:S:$ssid;T:WPA;P:$keyPassphrase;;"
			echo ""
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

		action='SetChannel'
		if [ "$option2" = "CHANGECH" ]; then
			channels=("36" "40" "44" "48" "52" "56" "60" "64" "100" "104" "108" "112" "116" "120" "124" "128") 
			case " ${channels[*]} " in
				*" $option3 "*) 
					NEW_CH="$option3"
    				;;
				*)
					NEW_CH=$( shuf -e ${channels[@]} -n1 )
    				;;
			esac
			echo "5Ghz: Changing channel"; curl -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'><NewChannel>$NEW_CH</NewChannel></u:$action></s:Body></s:Envelope>" -s > /dev/null;
			echo "5Ghz: Channel changed to $NEW_CH"
		fi

		action='GetSSID'
		if [ "$option2" =  "QRCODE" ]; then
			ssid=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewSSID | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
			action='GetSecurityKeys'
			keyPassphrase=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewKeyPassphrase | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
			echo "QR Code for 5 Ghz:"
			qrencode -t ansiutf8 "WIFI:S:$ssid;T:WPA;P:$keyPassphrase;;"
			echo ""
		fi
	fi

	if [ "$option1" = "WLAN_GUEST" ] || [ "$option1" = "WLAN" ]; then
		wlanNum=$(getWLANGUESTNum)
		if [ -z "$wlanNum" ]; then
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

			action='GetSSID'
			if [ "$option2" =  "QRCODE" ]; then
				ssid=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewSSID | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
				action='GetSecurityKeys'
				keyPassphrase=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewKeyPassphrase | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
				echo "QR Code for Guest Wifi:"
				qrencode -t ansiutf8 "WIFI:S:$ssid;T:WPA;P:$keyPassphrase;;"
				echo ""
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
### ------------------------- FUNCTION FritzBox Conf Backup - TR-064 Protocol --------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

confBackup() {
		location="/upnp/control/deviceinfo"
		uri="urn:dslforum-org:service:DeviceInfo:1"
		action='GetSecurityPort'

		securityPort=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewSecurityPort | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
		
		#echo "$securityPort"

		location="/upnp/control/deviceconfig"
		uri="urn:dslforum-org:service:DeviceConfig:1"
		action='X_AVM-DE_GetConfigFile'
		option2='testing'

		curlOutput1=$(curl -s --connect-timeout 60 -k -m 60 --anyauth -u "$BoxUSER:$BoxPW" "https://$BoxIP:$securityPort$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'><NewX_AVM-DE_Password>$option2</NewX_AVM-DE_Password></u:$action></s:Body></s:Envelope>" | grep NewX_AVM-DE_ConfigFileUrl | awk -F">" '{print $2}' | awk -F"<" '{print $1}')

		# File Downlaod
		dt=$(date '+%Y%m%d_%H%M%S');
		
		$(curl -s -k "$curlOutput1" -o "${dt}_SicherungEinstellungen.export" --anyauth -u "$BoxUSER:$BoxPW")
		if [ -e "${dt}_SicherungEinstellungen.export" ]; then
    		echo "File successfully downloaded: ${dt}_SicherungEinstellungen.export"
		fi

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
	echo "|-----------------|---------------------------|-----------------------------------------------------------------------------|"
	echo "|  Action         | Parameter                 | Description                                                                 |"
	echo "|-----------------|---------------------------|-----------------------------------------------------------------------------|"
	echo "|-----------------|---------------------------|-----------------------------------------------------------------------------|"
	echo "| DEVICEINFO      | STATE                     | Show information about your Fritz!Box like ModelName, SN, etc.              |"
	echo "| WLAN_2G         | 0 or 1 or STATE           | Switching ON, OFF or checking the state of the 2,4 Ghz WiFi                 |"
	echo "| WLAN_2G         | STATISTICS                | Statistics for the 2,4 Ghz WiFi easily digestible by telegraf               |"
	echo "| WLAN_2G         | QRCODE                    | Show a qr code to connect to the 2,4 Ghz WiFi                               |"
	echo "| WLAN_2G         | CHANGECH and <channel>    | Change channel of the 2,4 Ghz WiFi to optional <channel> (random if absent) |"
	echo "| WLAN_5G         | 0 or 1 or STATE           | Switching ON, OFF or checking the state of the 5 Ghz WiFi                   |"
	echo "| WLAN_5G         | STATISTICS                | Statistics for the 5 Ghz WiFi easily digestible by telegraf                 |"
	echo "| WLAN_5G         | QRCODE                    | Show a qr code to connect to the 5 Ghz WiFi                                 |"
	echo "| WLAN_5G         | CHANGECH and <channel>    | Change channel of the 5 Ghz WiFi to optional <channel> (random if absent)   |"
	echo "| WLAN_GUEST      | 0 or 1 or STATE           | Switching ON, OFF or checking the state of the Guest WiFi                   |"
	echo "| WLAN_GUEST      | STATISTICS                | Statistics for the Guest WiFi easily digestible by telegraf                 |"
	echo "| WLAN_GUEST      | QRCODE                    | Show a qr code to connect to the Guest WiFi                                 |"
	echo "| WLAN            | 0 or 1 or STATE           | Switching ON, OFF or checking the state of the 2,4Ghz and 5 Ghz WiFi        |"
	echo "| WLAN            | QRCODE                    | Show a qr code to connect to the 2,4 and 5 Ghz WiFi                         |"
	echo "| WLAN            | CHANGECH and <channel>    | Change channel of the 2,4 and 5 Ghz WiFi to optional <channel>              |"
	echo "|-----------------|---------------------------|-----------------------------------------------------------------------------|"
	echo "| TAM             | <index> and GetInfo       | e.g. TAM 0 GetInfo (gives info about answering machine)                     |"
	echo "| TAM             | <index> and ON or OFF     | e.g. TAM 0 ON (switches ON the answering machine)                           |"
	echo "| TAM             | <index> and GetMsgs       | e.g. TAM 0 GetMsgs (gives XML formatted list of messages)                   |"
	echo "|-----------------|---------------------------|-----------------------------------------------------------------------------|"
	echo "| OnTel           | GetCallList and <days>    | e.g. OnTel GetCallList 7 for all calls of the last seven days               |"
	echo "|-----------------|---------------------------|-----------------------------------------------------------------------------|"
	echo "| LED             | 0 or 1                    | Switching ON (1) or OFF (0) the LEDs in front of the Fritz!Box              |"
	echo "| LED_BRIGHTNESS  | 1 or 2 or 3               | Setting the brightness of the LEDs in front of the Fritz!Box                |"
	echo "| KEYLOCK         | 0 or 1                    | Activate (1) or deactivate (0) the Keylock (buttons de- or activated)       |"
	echo "| SIGNAL_STRENGTH | 100,50,25,12 or 6 %       | Set your signal strength (channel settings will then be set to manual)      |"
	echo "| WIREGUARD_VPN   | <name> and 0 or 1         | Name of your connection in "" (e.g. "Test 1"). 0 (OFF) and 1 (ON)           |"
	echo "|-----------------|---------------------------|-----------------------------------------------------------------------------|"
	echo "| MISC_LUA        | totalConnectionsWLAN      | Number of total connected WLAN clients (incl. full Mesh)                    |"
	echo "| MISC_LUA        | totalConnectionsWLAN2G    | Number of total connected 2,4 Ghz WLAN clients (incl. full Mesh)            |"
	echo "| MISC_LUA        | totalConnectionsWLAN5G    | Number of total connected 5 Ghz WLAN clients (incl. full Mesh)              |"
	echo "| MISC_LUA        | totalConnectionsWLANguest | Number of total connected Guest WLAN clients (incl. full Mesh)              |"
	echo "|                 | totalConnectionsLAN       | Number of total connected LAN clients (incl. full Mesh)                     |"
	echo "|-----------------|---------------------------|-----------------------------------------------------------------------------|"
    echo "| LAN             | STATE                     | Statistics for the LAN easily digestible by telegraf                        |"
	echo "| DSL             | STATE                     | Statistics for the DSL easily digestible by telegraf                        |"
	echo "| WAN             | STATE                     | Statistics for the WAN easily digestible by telegraf                        |"
	echo "| WAN             | RECONNECT                 | Ask for a new IP Address from your provider                                 |"
	echo "| LINK            | STATE                     | Statistics for the WAN DSL LINK easily digestible by telegraf               |"
	echo "| IGDWAN          | STATE                     | Statistics for the WAN LINK easily digestible by telegraf                   |"
	echo "| IGDDSL          | STATE                     | Statistics for the DSL LINK easily digestible by telegraf                   |"
	echo "| IGDIP           | STATE                     | Statistics for the DSL IP easily digestible by telegraf                     |"
	echo "| REPEATER        | 0                         | Switching OFF the WiFi of the Repeater                                      |"
	echo "| REBOOT          | Box or Repeater           | Rebooting your Fritz!Box or Fritz!Repeater                                  |"
	echo "| UPNPMetaData    | STATE or <filename>       | Full unformatted output of tr64desc.xml to console or file                  |"
	echo "| IGDMetaData     | STATE or <filename>       | Full unformatted output of igddesc.xml to console or file                   |"
    echo "|-----------------|---------------------------|-----------------------------------------------------------------------------|"
    echo "| KIDS            | userid and true|false     | Block / unblock internet access for certain machine                         |"
    echo "|-----------------|---------------------------|-----------------------------------------------------------------------------|"
    echo "| BACKUP          | <password>			    | Parameter <password> to define a password for your conf file                |"
	echo "|-----------------|---------------------------|-----------------------------------------------------------------------------|"
	echo "| VERSION         |                           | Version of the fritzBoxShell.sh                                             |"
	echo "|-----------------|---------------------------|-----------------------------------------------------------------------------|"
	echo ""
  cat <<END
Supported command line options and their related environment value:
  --boxip <IP address>      <-> BoxIP="<IP address>"
  --boxuser <user>          <-> BoxUSER="<user>"
  --boxpw <password>        <-> BoxPW="<password>"
  --repeaterip <IP address> <-> RepeaterIP="<IP address>"
  --repeateruser <user>     <-> RepeaterUSER="<user>"
  --repeaterpw <password>   <-> RepeaterPW="<password>"

Supported optional output format/filter:
  -O|--outputformat influx|graphite|mrtg
  -F|--outputfilter <regular expression>
END

  exit 1
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
		elif [ "$option2" = "CHANGECH" ]; then WLANstate "CHANGECH";
		elif [ "$option2" = "QRCODE" ]; then
			if ! command -v qrencode &> /dev/null; then
				echo "Error: qrencode is request to show the qr code"
				exit 1
			fi
			WLANstate "QRCODE";
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
  elif [ "$option2" = "RECONNECT" ]; then WANreconnect "$option2";
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
	elif [ "$option1" = "LED_BRIGHTNESS" ]; then
		LEDbrightness "$option2";
	elif [ "$option1" = "KEYLOCK" ]; then
		keyLockSwitch "$option2";
	elif [ "$option1" = "SIGNAL_STRENGTH" ]; then
		SignalStrengthChange "$option2";
	elif [ "$option1" = "WIREGUARD_VPN" ]; then
		if [ "$option2" = "" ]; then echo "Please enter VPN Wireguard conmnection"
		else WireguardVPNstate "$option2" "$option3";
		fi
	elif [ "$option1" = "MISC_LUA" ]; then
		LUAmisc "$option2";
	elif [ "$option1" = "TAM" ]; then
		if [[ $option2 =~ ^[+-]?[0-9]+$ ]] && { [ "$option3" = "GetInfo" ] || [ "$option3" = "ON" ] || [ "$option3" = "OFF" ] || [ "$option3" = "GetMsgs" ];}; then TAM
		else DisplayArguments
		fi
	elif [ "$option1" = "OnTel" ]; then
		if [ "$option2" = "GetCallList" ]; then OnTel
		else DisplayArguments
		fi
	elif [ "$option1" = "REPEATER" ]; then
		if [ "$option2" = "1" ]; then RepeaterWLANstate "ON"; # Usually this will not work because there is no connection possible to the Fritz!Repeater as long as WiFi is OFF
		elif [ "$option2" = "0" ]; then RepeaterWLANstate "OFF";
		else DisplayArguments
		fi
	elif [ "$option1" = "REBOOT" ]; then
		Reboot "$option2"
    elif [ "$option1" = "KIDS" ]; then
        SetInternet "$option2" "$option3";
    elif [ "$option1" = "BACKUP" ]; then
        confBackup "$option2";
	else DisplayArguments
	fi
fi
