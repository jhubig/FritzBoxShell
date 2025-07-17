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

cd "$(dirname "$0")"

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
    	--backupconffolder)
    backupConfFolder="$2"
    shift ; shift
    ;;
    	--backupconffilename)
    backupConfFilename="$2"
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
option4="$4"
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
  
  if [ -z "$SID" ]; then
    echo "No SID could be retrieved. Please check your password and username either by parameter or defined in the fritzBoxShellConfig.sh."
  fi

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
### ---------------------- FUNCTION SetProfile FOR putting a device into a profiles list ---------------- ###
### ----------------------------- Here the TR-064 protocol cannot be used. ------------------------------ ###
### ----------------------------------------------------------------------------------------------------- ###
### ---------------------------------------- AHA-HTTP-Interface ----------------------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

SetProfile(){
        # Get the a valid SID
        getSID

        # param2 = device name
        # param3 = device ID
        # param4 = profile ID
 
        wget -O /dev/null  --post-data "sid=$SID&dev_name=$option2&dev=$option3&kisi_profile=$option4&page=edit_device&apply=true" "http://$BoxIP/data.lua" 2>/dev/null
        echo "Gerät $option2 ($option3) in Profil $option4 verschoben"

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
### ------------------------- FUNCTION get_filtered_clients - TR-064 Protocol --------------------------- ###
### -------------- Function to get total number of 2.4 Ghz, 5 Ghz, ethernet or all clients -------------- ###
### ----------------------------------------------------------------------------------------------------- ###

# Function for SOAP requests
soap_request() {
    local location=$1
    local service=$2
    local action=$3
    local body=$4
    local FRITZBOX_URL="http://$BoxIP:49000"
    local USERNAME=$BoxUSER
    local PASSWORD=$BoxPW

    curl -m 25 --anyauth -s -u "$USERNAME:$PASSWORD" \
        -H 'Content-Type: text/xml; charset="utf-8"' \
        -H "SOAPAction: \"$service#$action\"" \
        -d "$body" \
        "$FRITZBOX_URL$location"
}

get_ip_from_mac() {
    local mac=$1
    local show_ip=$2  # Parameter that indicates whether the IP address should be retrieved

    # If the -withIP parameter is set, retrieve the IP address
    if [ "$show_ip" == "-withIP" ]; then
        local SOAP_BODY='<?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" 
                    s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
            <s:Body>
                <u:GetSpecificHostEntry xmlns:u="urn:dslforum-org:service:Hosts:1">
                    <NewMACAddress>'$mac'</NewMACAddress>
                </u:GetSpecificHostEntry>
            </s:Body>
        </s:Envelope>'

        # Use curl to send the SOAP request (replace this with your actual method)
        local response=$(soap_request "/upnp/control/hosts" "urn:dslforum-org:service:Hosts:1" "GetSpecificHostEntry" "$SOAP_BODY")
        local ip=$(echo "$response" | xmlstarlet sel -t -v "//NewIPAddress" 2>/dev/null)

        echo "$ip"
    else
        echo ""  # If -withIP is not set, leave the IP empty
    fi
}

get_filtered_clients() {
    local filter=$1
    local show_ip=$2  # Parameter that indicates whether the IP address should be retrieved

    # Retrieve the host list
    local SOAP_BODY='<?xml version="1.0" encoding="utf-8"?>
    <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" 
                s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
        <s:Body>
            <u:GetMeshListPath xmlns:u="urn:dslforum-org:service:Hosts:1" />
        </s:Body>
    </s:Envelope>'

    local mesh_list_xml=$(soap_request "/upnp/control/hosts" "urn:dslforum-org:service:Hosts:1" "X_AVM-DE_GetMeshListPath" "$SOAP_BODY")
    local mesh_list_path=$(echo "$mesh_list_xml" | xmlstarlet sel -t -v "//NewX_AVM-DE_MeshListPath")

    if [[ -z "$mesh_list_path" ]]; then
        echo "Error: Could not retrieve mesh list."
        return 1
    fi

    # Retrieve the Security Port
    location="/upnp/control/deviceinfo"
    uri="urn:dslforum-org:service:DeviceInfo:1"
    action="GetSecurityPort"
    securityPort=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewSecurityPort | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
    
    # Retrieve the mesh list
    local sid=$(echo "$mesh_list_path" | grep -o 'sid=[^&]*' | cut -d'=' -f2)

    local mesh_url="https://$BoxIP:$securityPort/meshlist.lua?sid=$sid"

    # echo "DEBUG: Retrieving the mesh list from: $mesh_url"

    # Retrieve the mesh list
    local mesh_list_json=$(curl -s -k -m 30 --anyauth -u "$BoxUSER:$BoxPW" "$mesh_url")

    # Check if the response is HTML (e.g., an error page)
    if echo "$mesh_list_json" | grep -iq "<html>"; then
        echo "Error: Received HTML response (likely an authentication problem)."
        return 1
    fi

    # Check if the response is valid JSON
    if ! echo "$mesh_list_json" | jq empty 2>/dev/null; then
        echo "Error: Retrieved JSON data is invalid."
        echo "DEBUG: Raw data:"
        echo "$mesh_list_json"
        return 1
    fi

    # Clean the JSON data
    mesh_list_json=$(echo "$mesh_list_json" | tr -d '\r' | sed 's/\\//g')

    if [ -z "$mesh_list_json" ]; then
        echo "Error: mesh_list_json is empty!"
        return 1
    fi

    # Filtering the devices based on the specified filter
    local clients=""
    echo "DEBUG: Applying filter '$filter' to the mesh list..."

	case "$filter" in
		"2.4")
			# Filter for 2.4 GHz (only WLAN devices)
			clients=$(echo "$mesh_list_json" | jq -r '.nodes[] | select(.device_name != "fritz.repeater" and .device_name != "fritz.box") | select(.node_interfaces[] | .type == "WLAN" and .current_channel_info?.primary_freq < 3000000) | {mac: .node_interfaces[].mac_address, name: .device_name, type: "WLAN_2G", ip: .node_interfaces[].ip_address, status: (if (.node_interfaces[].node_links | length) > 0 then "ONLINE" else "OFFLINE" end)}')
			;;
		"5")
			# Filter for 5 GHz (only WLAN devices)
			clients=$(echo "$mesh_list_json" | jq -r '.nodes[] | select(.device_name != "fritz.repeater" and .device_name != "fritz.box") | select(.node_interfaces[] | .type == "WLAN" and .current_channel_info?.primary_freq >= 5000000) | {mac: .node_interfaces[].mac_address, name: .device_name, type: "WLAN_5G", ip: .node_interfaces[].ip_address, status: (if (.node_interfaces[].node_links | length) > 0 then "ONLINE" else "OFFLINE" end)}')
			;;
		"ETH")
			# Filter for Ethernet (only LAN devices)
			clients=$(echo "$mesh_list_json" | jq -r '.nodes[] | select(.device_name != "fritz.repeater" and .device_name != "fritz.box") | select(.node_interfaces[] | .type == "LAN") | {mac: .node_interfaces[].mac_address, name: .device_name, type: "ETH", ip: .node_interfaces[].ip_address, status: (if (.node_interfaces[].node_links | length) > 0 then "ONLINE" else "OFFLINE" end)}')
			;;
		"all")
			# Clear clients variable
			clients=""

			# Filter for 2.4 GHz WLAN
			clients+=$(echo "$mesh_list_json" | jq -r '.nodes[] | select(.device_name != "fritz.repeater" and .device_name != "fritz.box") | select(.node_interfaces[] | .type == "WLAN" and .current_channel_info?.primary_freq < 3000000) | {mac: .node_interfaces[].mac_address, name: .device_name, type: "WLAN_2G", ip: .node_interfaces[].ip_address, status: (if (.node_interfaces[].node_links | length) > 0 then "ONLINE" else "OFFLINE" end)}')
			

			# Filter for 5 GHz WLAN
			clients+=$(echo "$mesh_list_json" | jq -r '.nodes[] | select(.device_name != "fritz.repeater" and .device_name != "fritz.box") | select(.node_interfaces[] | .type == "WLAN" and .current_channel_info?.primary_freq >= 5000000) | {mac: .node_interfaces[].mac_address, name: .device_name, type: "WLAN_5G", ip: .node_interfaces[].ip_address, status: (if (.node_interfaces[].node_links | length) > 0 then "ONLINE" else "OFFLINE" end)}')
			

			# Filter for Ethernet (LAN)
			clients+=$(echo "$mesh_list_json" | jq -r '.nodes[] | select(.device_name != "fritz.repeater" and .device_name != "fritz.box") | select(.node_interfaces[] | .type == "LAN") | {mac: .node_interfaces[].mac_address, name: .device_name, type: "ETH", ip: .node_interfaces[].ip_address, status: (if (.node_interfaces[].node_links | length) > 0 then "ONLINE" else "OFFLINE" end)}')

			;;
		*)
			echo "Invalid filter. Available options: 2.4, 5, ETH, all"
			return 1
			;;
	esac

    # Remove duplicate devices based on MAC address but display device names
    unique_clients=$(echo "$clients" | jq -s 'map({mac, name, type, ip, status}) | unique_by(.mac)')

    # echo "$unique_clients" > unique_clients_debug.json

    # Loop over all clients and retrieve the IP only if -withIP is set
	#
	# OLD CODE which was making toubles on Cygwin or windows based shell envorinments
	#
    # for i in $(echo "$unique_clients" | jq -r '. | keys_unsorted | .[]'); do
    #     mac=$(echo "$unique_clients" | jq -r ".[$i].mac")  # Get MAC address
    #     ip=$(get_ip_from_mac "$mac" "$show_ip")  # Retrieve IP only if -withIP is set

    #     # Update the JSON with the IP address if it exists
    #     if [ -n "$ip" ]; then
    #         unique_clients=$(echo "$unique_clients" | jq ".[$i].ip = \"$ip\"")
    #     fi
    # done

	# Loop over all clients and retrieve the IP only if -withIP is set
	for i in $(echo "$unique_clients" | jq -r '. | keys_unsorted | .[]'); do
		# Hole die MAC-Adresse sicher mit --argjson
		mac=$(echo "$unique_clients" | jq -r --argjson i "$i" '.[$i].mac')
		
		# Get the IP-Address based on the MAC-Address
		ip=$(get_ip_from_mac "$mac" "$show_ip")

		# Update the JSON with the IP address if it exists with --arg
		if [ -n "$ip" ]; then
			unique_clients=$(echo "$unique_clients" | jq --argjson i "$i" --arg ip "$ip" '.[$i].ip = $ip')
		fi
	done

	unique_clients=$(echo "$unique_clients" | jq 'sort_by(.type)')

    # Count the filtered devices (only unique)
    local num_clients=$(echo "$unique_clients" | jq length)

    # Count the ONLINE and OFFLINE devices
    local online_count=$(echo "$unique_clients" | jq '[.[] | select(.status == "ONLINE")] | length')
    local offline_count=$(echo "$unique_clients" | jq '[.[] | select(.status == "OFFLINE")] | length')

    # Output the total number and the online/offline count
    echo 
	echo "Found devices: $num_clients"
    echo "ONLINE: $online_count | OFFLINE: $offline_count"
    echo 

    # Create the header line, matching the data
    header="Type\tClient Name\tIP Address\tMAC Address\tStatus"

    # Output the devices in a format suitable for `column` (with header)
    (
        echo -e "$header"
        echo "$unique_clients" | jq -r '.[] | "\(.type)\t\(.name)\t\(.ip // "No IP")\t\(.mac)\t\(.status)"'
    ) | column -t -s $'\t'
}

### ----------------------------------------------------------------------------------------------------- ###
### ---------------------- FUNCTION ListAllDevices - Enhanced Device Information ----------------------- ###
### ----------------------------- Using TR-064 Protocol for comprehensive data ------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

ListAllDevices() {
    echo "Retrieving all known devices from Fritz!Box (optimized for speed)..."
    echo ""
    
    # Skip mesh API for now due to parsing issues - use reliable TR-064 method
    echo "Using parallel TR-064 approach for reliable device names..."
    
    # TR-064 service information
    SERVICE="urn:dslforum-org:service:Hosts:1"
    CONTROL_URL="/upnp/control/hosts"
    
    # Check if the service is available
    if ! verify_action_availability "$CONTROL_URL" "$SERVICE" "GetHostNumberOfEntries"; then
        echo "Error: Host service not available on this Fritz!Box"
        return 1
    fi
    
    # Get total number of known devices
    total_hosts=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$CONTROL_URL" \
        -H 'Content-Type: text/xml; charset="utf-8"' \
        -H "SoapAction:$SERVICE#GetHostNumberOfEntries" \
        -d "<?xml version='1.0' encoding='utf-8'?>
        <s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'>
        <s:Body>
            <u:GetHostNumberOfEntries xmlns:u='$SERVICE'></u:GetHostNumberOfEntries>
        </s:Body>
        </s:Envelope>" | grep NewHostNumberOfEntries | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
    
    if [[ ! "$total_hosts" =~ ^[0-9]+$ ]] || [ "$total_hosts" -eq 0 ]; then
        echo "No devices found or error retrieving device count"
        return 1
    fi
    
    echo "Found $total_hosts known devices (processing in parallel for speed)..."
    echo ""
    
    # Create temporary directory for parallel processing
    temp_dir="/tmp/fritzbox_devices_$$"
    mkdir -p "$temp_dir"
    
    # Get SID for profile information (once, not per device)
    getSID 2>/dev/null
    
    # Get device data once if SID is available
    device_data=""
    if [ -n "$SID" ]; then
        device_data=$(wget -q -O - --post-data "xhr=1&sid=$SID&page=netDev&xhrId=all" "http://$BoxIP/data.lua" 2>/dev/null)
    fi
    
    # Function to process a single device (will be run in parallel)
    process_device() {
        local i=$1
        local temp_dir=$2
        local device_data=$3
        
        # Get detailed information for this device
        device_info=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$CONTROL_URL" \
            -H "Content-Type: text/xml; charset=\"utf-8\"" \
            -H "SoapAction:$SERVICE#GetGenericHostEntry" \
            -d "<?xml version=\"1.0\" encoding=\"utf-8\"?>
            <s:Envelope s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\">
                <s:Body>
                    <u:GetGenericHostEntry xmlns:u=\"$SERVICE\"><NewIndex>$i</NewIndex></u:GetGenericHostEntry>
                </s:Body>
            </s:Envelope>")
        
        # Extract individual fields
        device_name=$(echo "$device_info" | grep NewHostName | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
        mac_address=$(echo "$device_info" | grep NewMACAddress | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
        ip_address=$(echo "$device_info" | grep NewIPAddress | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
        interface_type=$(echo "$device_info" | grep NewInterfaceType | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
        active=$(echo "$device_info" | grep NewActive | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
        
        # Try to get device ID and profile from the pre-fetched data
        device_id="N/A"
        profile_id="N/A"
        
        if [ -n "$device_data" ] && [ -n "$mac_address" ] && command -v jq &> /dev/null; then
            device_entry=$(echo "$device_data" | jq -r ".data.active[]? | select(.mac == \"$mac_address\") | {id: .id, profile: .profile}" 2>/dev/null)
            if [ -n "$device_entry" ] && [ "$device_entry" != "null" ]; then
                device_id=$(echo "$device_entry" | jq -r '.id // "N/A"' 2>/dev/null)
                profile_id=$(echo "$device_entry" | jq -r '.profile // "N/A"' 2>/dev/null)
            fi
        fi
        
        # Clean up empty values
        [ -z "$device_name" ] && device_name="Unknown"
        [ -z "$mac_address" ] && mac_address="N/A"
        [ -z "$ip_address" ] && ip_address="N/A"
        [ -z "$interface_type" ] && interface_type="N/A"
        [ -z "$active" ] && active="N/A"
        
        # Convert active status to readable format
        case "$active" in
            "1") active="Yes" ;;
            "0") active="No" ;;
            *) active="N/A" ;;
        esac
        
        # Truncate long names for better formatting
        if [ ${#device_name} -gt 20 ]; then
            device_name="${device_name:0:17}..."
        fi
        
        # Write result to temporary file (with device index for sorting)
        printf "%d|%-20s|%-17s|%-15s|%-10s|%-8s|%-12s|%-10s\n" \
            "$i" "$device_name" "$mac_address" "$ip_address" "$interface_type" "$active" "$device_id" "$profile_id" \
            > "$temp_dir/device_$i.txt"
    }
    
    # Export function and variables for parallel execution
    export -f process_device
    export BoxUSER BoxPW BoxIP CONTROL_URL SERVICE
    
    # Create header
    printf "%-3s %-20s %-17s %-15s %-10s %-8s %-12s %-10s\n" \
        "ID" "Device Name" "MAC Address" "IP Address" "Interface" "Active" "LAN-Dev-ID" "Profile"
    echo "----------------------------------------------------------------------------------------------------"
    
    # Process devices in parallel (limit concurrent jobs to avoid overwhelming the Fritz!Box)
    max_parallel=10
    
    # Launch parallel jobs in batches
    for ((i=0; i<total_hosts; i++)); do
        # Launch background job
        process_device "$i" "$temp_dir" "$device_data" &
        
        # Limit number of parallel jobs
        if (( (i + 1) % max_parallel == 0 )); then
            wait  # Wait for current batch to complete
        fi
    done
    
    # Wait for any remaining jobs
    wait
    
    # Collect and display results in order
    for ((i=0; i<total_hosts; i++)); do
        if [ -f "$temp_dir/device_$i.txt" ]; then
            # Read the result and format it properly with consistent ID alignment
            result=$(cat "$temp_dir/device_$i.txt")
            # Parse the fields and reformat with proper alignment
            IFS='|' read -r id name mac ip interface active dev_id profile <<< "$result"
            printf "%-3s %-20s %-17s %-15s %-10s %-8s %-12s %-10s\n" \
                "$id" "$name" "$mac" "$ip" "$interface" "$active" "$dev_id" "$profile"
        fi
    done
    
    echo ""
    echo "Total devices: $total_hosts"
    echo "Processing completed using parallel execution!"
    
    # Cleanup
    rm -rf "$temp_dir"
    
    # Logout the SID if it was used
    if [ -n "$SID" ]; then
        wget -O /dev/null "http://$BoxIP/home/home.lua?sid=$SID&logout=1" &>/dev/null
    fi
}

### ----------------------------------------------------------------------------------------------------- ###
### ---------------------- FUNCTION ListAllDevicesUltraFast - Using Mesh API -------------------------- ###
### ----------------------------- Leverages existing optimized mesh functionality ---------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

ListAllDevicesUltraFast() {
    # Use the existing optimized mesh API which gets all devices in one call
    
    # Get SID for profile information
    getSID 2>/dev/null
    
    # Get all devices using the mesh API (much faster)
    SERVICE="urn:dslforum-org:service:Hosts:1"
    CONTROL_URL="/upnp/control/hosts"
    
    # Get mesh list path
    SOAP_BODY='<?xml version="1.0" encoding="utf-8"?>
    <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" 
                s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
        <s:Body>
            <u:GetMeshListPath xmlns:u="urn:dslforum-org:service:Hosts:1" />
        </s:Body>
    </s:Envelope>'

    mesh_list_xml=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$CONTROL_URL" \
        -H 'Content-Type: text/xml; charset="utf-8"' \
        -H "SoapAction:urn:dslforum-org:service:Hosts:1#X_AVM-DE_GetMeshListPath" \
        -d "$SOAP_BODY" 2>/dev/null)
    
    mesh_list_path=$(echo "$mesh_list_xml" | xmlstarlet sel -t -v "//NewX_AVM-DE_MeshListPath" 2>/dev/null)

    if [[ -z "$mesh_list_path" ]]; then
        return 1  # Mesh API not available
    fi

    # Get security port
    location="/upnp/control/deviceinfo"
    uri="urn:dslforum-org:service:DeviceInfo:1"
    action="GetSecurityPort"
    securityPort=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" \
        -H 'Content-Type: text/xml; charset="utf-8"' \
        -H "SoapAction:$uri#$action" \
        -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewSecurityPort | awk -F">" '{print $2}' | awk -F"<" '{print $1}' 2>/dev/null)
    
    # Get mesh list
    sid=$(echo "$mesh_list_path" | grep -o 'sid=[^&]*' | cut -d'=' -f2)
    mesh_url="https://$BoxIP:$securityPort/meshlist.lua?sid=$sid"
    
    mesh_list_json=$(curl -s -k -m 30 --anyauth -u "$BoxUSER:$BoxPW" "$mesh_url" 2>/dev/null)
    
    if ! echo "$mesh_list_json" | jq empty 2>/dev/null; then
        return 1  # Mesh data not available
    fi
    
    # Get device profile data if SID available
    device_profile_data=""
    if [ -n "$SID" ]; then
        device_profile_data=$(wget -q -O - --post-data "xhr=1&sid=$SID&page=netDev&xhrId=all" "http://$BoxIP/data.lua" 2>/dev/null)
    fi
    
    echo "Found devices using ultra-fast mesh API:"
    echo ""
    
    # Create header
    printf "%-3s %-20s %-17s %-15s %-10s %-8s %-12s %-10s\n" \
        "ID" "Device Name" "MAC Address" "IP Address" "Interface" "Active" "LAN-Dev-ID" "Profile"
    echo "----------------------------------------------------------------------------------------------------"
    
    # Process all devices from mesh data
    device_count=0
    echo "$mesh_list_json" | jq -r '.nodes[] | select(.device_name != "fritz.repeater" and .device_name != "fritz.box") | .node_interfaces[] | "\(.mac_address)|\(.ip_address // "N/A")|\(.type)|\(if (.node_links | length) > 0 then "Yes" else "No" end)|\(.device_name // "Unknown")"' 2>/dev/null | \
    while IFS='|' read -r mac_address ip_address interface_type active device_name; do
        
        # Get device ID and profile from profile data if available
        device_id="N/A"
        profile_id="N/A"
        
        if [ -n "$device_profile_data" ] && [ -n "$mac_address" ] && command -v jq &> /dev/null; then
            device_entry=$(echo "$device_profile_data" | jq -r ".data.active[]? | select(.mac == \"$mac_address\") | {id: .id, profile: .profile}" 2>/dev/null)
            if [ -n "$device_entry" ] && [ "$device_entry" != "null" ]; then
                device_id=$(echo "$device_entry" | jq -r '.id // "N/A"' 2>/dev/null)
                profile_id=$(echo "$device_entry" | jq -r '.profile // "N/A"' 2>/dev/null)
            fi
        fi
        
        # Clean up values
        [ -z "$device_name" ] && device_name="Unknown"
        [ -z "$mac_address" ] && mac_address="N/A"
        [ -z "$ip_address" ] && ip_address="N/A"
        [ -z "$interface_type" ] && interface_type="N/A"
        [ -z "$active" ] && active="N/A"
        
        # Map interface types
        case "$interface_type" in
            "WLAN") interface_type="802.11" ;;
            "LAN") interface_type="Ethernet" ;;
        esac
        
        # Truncate long names
        if [ ${#device_name} -gt 20 ]; then
            device_name="${device_name:0:17}..."
        fi
        
        # Print device information
        printf "%-3s %-20s %-17s %-15s %-10s %-8s %-12s %-10s\n" \
            "$device_count" "$device_name" "$mac_address" "$ip_address" "$interface_type" "$active" "$device_id" "$profile_id"
        
        device_count=$((device_count + 1))
    done
    
    echo ""
    echo "Total devices: $device_count"
    echo "Ultra-fast processing completed using mesh API!"
    
    # Logout the SID if it was used
    if [ -n "$SID" ]; then
        wget -O /dev/null "http://$BoxIP/home/home.lua?sid=$SID&logout=1" &>/dev/null
    fi
    
    return 0
}

### ----------------------------------------------------------------------------------------------------- ###
### ---------------------- FUNCTION ListProfiles - List Available Filter Profiles -------------------- ###
### ----------------------------- Using AHA-HTTP-Interface for profile data ---------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

ListProfiles() {
    echo "Retrieving available filter profiles from Fritz!Box..."
    echo ""
    
    # Get a valid SID for AHA interface
    getSID
    
    if [ -z "$SID" ]; then
        echo "Error: Could not obtain session ID. Please check credentials."
        return 1
    fi
    
    # Get profile information from data.lua
    profile_data=$(wget -q -O - --post-data "xhr=1&sid=$SID&page=kidPro&xhrId=all" "http://$BoxIP/data.lua" 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$profile_data" ]; then
        echo "Trying alternative method to retrieve profile data..."
        
        # Alternative: Try to get profiles from device management page
        profile_data=$(wget -q -O - --post-data "xhr=1&sid=$SID&page=netDev&xhrId=all" "http://$BoxIP/data.lua" 2>/dev/null)
    fi
    
    if [ $? -ne 0 ] || [ -z "$profile_data" ]; then
        echo "Error: Could not retrieve profile information from Fritz!Box"
        echo "This might be due to:"
        echo "  - Insufficient user permissions"
        echo "  - Parental controls not configured"
        echo "  - Fritz!Box firmware version compatibility"
        
        # Logout the SID
        wget -O /dev/null "http://$BoxIP/home/home.lua?sid=$SID&logout=1" &>/dev/null
        return 1
    fi
    
    # Check if jq is available for JSON parsing
    if ! command -v jq &> /dev/null; then
        echo "Warning: jq is not installed - showing basic profile information"
        echo ""
        echo "Available Filter Profiles:"
        echo "=========================="
        echo "Default profiles that are typically available:"
        echo "  ID: 0 or 1 - Standard (unrestricted access)"
        echo "  ID: 2      - Blocked (no internet access)"
        echo "  ID: 3+     - Custom profiles (if configured)"
        echo ""
        echo "To see detailed profiles, install jq: sudo apt-get install jq"
    else
        # Parse profiles from JSON data
        echo "Available Filter Profiles:"
        echo "=========================="
        
        # Try to extract profiles from the data
        profiles=$(echo "$profile_data" | jq -r '.data.profiles[]? | "\(.id)|\(.name)|\(.description // "No description")"' 2>/dev/null)
        
        if [ -z "$profiles" ]; then
            # Try alternative JSON structure
            profiles=$(echo "$profile_data" | jq -r '.data.kidProfiles[]? | "\(.id)|\(.name)|\(.desc // "No description")"' 2>/dev/null)
        fi
        
        if [ -z "$profiles" ]; then
            # Try yet another structure for newer firmware
            profiles=$(echo "$profile_data" | jq -r 'try (.data[] | select(.profiles) | .profiles[] | "\(.id)|\(.name)|\(.description // "No description")")' 2>/dev/null)
        fi
        
        if [ -n "$profiles" ]; then
            printf "%-5s %-25s %-50s\n" "ID" "Profile Name" "Description"
            echo "--------------------------------------------------------------------------------"
            
            echo "$profiles" | while IFS='|' read -r id name desc; do
                [ -z "$name" ] && name="Unnamed Profile"
                [ -z "$desc" ] && desc="No description"
                
                # Truncate long descriptions
                if [ ${#desc} -gt 50 ]; then
                    desc="${desc:0:47}..."
                fi
                
                printf "%-5s %-25s %-50s\n" "$id" "$name" "$desc"
            done
        else
            echo "No custom profiles found. Default profiles available:"
            echo ""
            printf "%-5s %-25s %-50s\n" "ID" "Profile Name" "Description"
            echo "--------------------------------------------------------------------------------"
            printf "%-5s %-25s %-50s\n" "0/1" "Standard" "Unrestricted internet access"
            printf "%-5s %-25s %-50s\n" "2" "Blocked" "No internet access"
            echo ""
            echo "Configure custom profiles in Fritz!Box web interface under:"
            echo "Internet > Filters > Parental Controls"
        fi
    fi
    
    echo ""
    echo "Usage with SETPROFILE:"
    echo "  ./fritzBoxShell.sh SETPROFILE <device_name> <device_id> <profile_id>"
    echo "  Example: ./fritzBoxShell.sh SETPROFILE \"Johns Phone\" \"12345\" \"2\""
    echo ""
    echo "To get device IDs, use: ./fritzBoxShell.sh LISTDEVICES"
    
    # Logout the SID
    wget -O /dev/null "http://$BoxIP/home/home.lua?sid=$SID&logout=1" &>/dev/null
}

### ----------------------------------------------------------------------------------------------------- ###
### ---------------------- FUNCTION ListDevicesWithProfiles - Combined Information ------------------- ###
### ----------------------------- Shows devices with their current profile assignments ----------------- ###
### ----------------------------------------------------------------------------------------------------- ###

ListDevicesWithProfiles() {
    echo "Retrieving devices with profile assignments..."
    echo ""
    
    # Get a valid SID
    getSID
    
    if [ -z "$SID" ]; then
        echo "Error: Could not obtain session ID for profile information"
        echo "Falling back to basic device listing..."
        ListAllDevices
        return
    fi
    
    # Get device and profile data
    device_data=$(wget -q -O - --post-data "xhr=1&sid=$SID&page=netDev&xhrId=all" "http://$BoxIP/data.lua" 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$device_data" ]; then
        echo "Warning: Could not retrieve profile assignments"
        echo "Showing basic device information..."
        ListAllDevices
        return
    fi
    
    echo "Devices with Profile Assignments:"
    echo "================================="
    printf "%-20s %-17s %-15s %-12s %-15s %-10s\n" \
        "Device Name" "MAC Address" "IP Address" "Device ID" "Profile Name" "Status"
    echo "--------------------------------------------------------------------------------------------"
    
    # Parse device data with jq if available
    if command -v jq &> /dev/null; then
        device_count=0
        echo "$device_data" | jq -r '.data.active[]? | "\(.name // "Unknown")|\(.mac)|\(.ip // "N/A")|\(.id // "N/A")|\(.profile_name // "Default")|\(.state // "Unknown")"' 2>/dev/null | \
        while IFS='|' read -r name mac ip dev_id profile status; do
            # Truncate long names
            if [ ${#name} -gt 20 ]; then
                name="${name:0:17}..."
            fi
            if [ ${#profile} -gt 15 ]; then
                profile="${profile:0:12}..."
            fi
            
            printf "%-20s %-17s %-15s %-12s %-15s %-10s\n" \
                "$name" "$mac" "$ip" "$dev_id" "$profile" "$status"
            device_count=$((device_count + 1))
        done
        
        if [ $device_count -eq 0 ]; then
            echo "No active devices found with profile information."
            echo "This might indicate that parental controls are not configured."
        fi
    else
        echo "jq not available - showing basic device list instead"
        echo "Install jq for enhanced profile information: sudo apt-get install jq"
        echo ""
        ListAllDevices
    fi
    
    # Logout the SID
    wget -O /dev/null "http://$BoxIP/home/home.lua?sid=$SID&logout=1" &>/dev/null
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
### --------------------------- FUNCTION to readout event log from query.lua ---------------------------- ###
### ----------------------------- Here the TR-064 protocol cannot be used. ------------------------------ ###
### ----------------------------------------------------------------------------------------------------- ###
### ---------------------------------------- AHA-HTTP-Interface ----------------------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

LUAmisc_Log(){
	
	# Get the a valid SID
	getSID

	# This could be extended in the future to also get other information
	if [ "$option2" == "ReadLog" ]; then
		# Readout the event log of the Fritz!Box
		
		log=$(curl -k -s -G "http://$BoxIP/query.lua" \
			-d "mq_log=logger:status/log" \
			-d "sid=$SID" | \
			jq -r '.mq_log[] | .[0]' | \
			tail -r)
		
		echo "Event Log of FritzBox:"
		echo "$log"

	elif [ "$option2" == "ResetLog" ]; then
		reset=$(curl -s "http://$BoxIP/data.lua" --compressed --data "xhr=1&sid=$SID&lang=de&page=log&xhrId=del&del=1&useajax=1&no_sidrenew=")
		
		if [[ "$reset" == *"Ereignisse wurden gelöscht"* ]]; then
			echo "The event log was successfully resetted."
		else
			echo "The event log was not resetted."
		fi
	fi

	# Logout the "used" SID
	wget -O - "http://$BoxIP/home/home.lua?sid=$SID&logout=1" &>/dev/null
}


### ----------------------------------------------------------------------------------------------------- ###
### -------------------------------- FUNCTION readout - TR-064 Protocol --------------------------------- ###
### -- General function for sending the SOAP request via TR-064 Protocol - called from other functions -- ###
### ----------------------------------------------------------------------------------------------------- ###

readout() {

		# Before performing the readout, check if the action is available
		if verify_action_availability "$location" "$uri" "$action"; then
			curlOutput1=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep "<New" | awk -F"</" '{print $1}' |sed -En "s/<(.*)>(.*)/\1 \2/p")
			echo "$curlOutput1"
		else
			echo "Action '$action' canot be executed, because it seems to be not available."
			echo "You can try with "fritzBoxShell.sh ACTIONS" to get a list of available services and actions."
		fi
}

### ----------------------------------------------------------------------------------------------------- ###
### ------------------------ FUNCTION check if action available - TR-064 Protocol ----------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

# Function to verify if an action is available
verify_action_availability() {
    local location=$1
    local uri=$2
    local action=$3

    # Retrieve tr64desc.xml
    tr64desc=$(curl -s "http://$BoxIP:49000/tr64desc.xml")
    if [ -z "$tr64desc" ]; then
        echo "Error: Could not retrieve tr64desc.xml."
        return 1
    fi

    # Temporary file for the XML data
    temp_file=$(mktemp)
    echo "$tr64desc" > "$temp_file"

    # Find the SCPD URL
    scpd_url=$(xmlstarlet sel -t -m "//*[local-name()='service']" \
        -if "./*[local-name()='controlURL'][text()='$location']" \
        -v "./*[local-name()='SCPDURL']" -n "$temp_file" | head -n 1)

    rm "$temp_file"

    if [ -z "$scpd_url" ]; then
        echo "Error: No SCPD URL found for the provided controlURL ($location)."
        return 1
    fi

    # Retrieve SCPD data
    scpd_data=$(curl -s "http://$BoxIP:49000$scpd_url")
    if [ -z "$scpd_data" ]; then
        echo "Error: SCPD data could not be retrieved for the URL ($scpd_url)."
        return 1
    fi

    # Temporary file for the SCPD data
    scpd_file=$(mktemp)
    echo "$scpd_data" > "$scpd_file"

    # Check if the action is available
    available_action=$(xmlstarlet sel -t -m "//*[local-name()='action']" \
        -if "./*[local-name()='name'][text()='$action']" \
        -v "./*[local-name()='name']" -n "$scpd_file" | head -n 1)

    rm "$scpd_file"

    if [ -n "$available_action" ]; then
        # echo "Action '$action' is available for the service '$uri'."
        return 0
    else
        echo "Error: Action '$action' is not available for the service '$uri'."
        return 1
    fi
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

		# Check availability of the defined action
		if verify_action_availability "$location" "$uri" "$action"; then
			echo "Starte readout..."
			# Hier die tatsächliche Funktion aufrufen, wenn die Aktion verfügbar ist
			wlanType=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewX_AVM-DE_APType | awk -F">" '{print $2}' | awk -F"<" '{print $1}')

			if [ "$wlanType" = "guest" ]; then
				echo $wlanNum
				break
			fi
		else
			echo "Action '$action' canot be executed, because it seems to be not available."
			echo "You can try with "fritzBoxShell.sh ACTIONS" to get a list of available services and actions."
		fi
    done
}

### ----------------------------------------------------------------------------------------------------- ###
### ---------------------- FUNCTION get_channel_width_for_wlan - Enhancement for Issue #54 -------------- ###
### ----------------------------- Gets WiFi channel width via AHA interface ----------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

get_channel_width_for_wlan() {
    local wlan_config=$1  # 1, 2, or 3
    
    # Get SID for AHA interface
    local temp_sid=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000/upnp/control/deviceconfig" \
        -H 'Content-Type: text/xml; charset="utf-8"' \
        -H "SoapAction:urn:dslforum-org:service:DeviceConfig:1#X_AVM-DE_CreateUrlSID" \
        -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:X_AVM-DE_CreateUrlSID xmlns:u='urn:dslforum-org:service:DeviceConfig:1'></u:X_AVM-DE_CreateUrlSID></s:Body></s:Envelope>" | \
        grep "NewX_AVM-DE_UrlSID" | awk -F">" '{print $2}' | awk -F"<" '{print $1}' | awk -F"=" '{print $2}')
    
    if [ -n "$temp_sid" ]; then
        # Get channel data from AHA interface
        local chan_data=$(wget -q -O - --post-data "xhr=1&sid=$temp_sid&page=chan&xhrId=all" "http://$BoxIP/data.lua" 2>/dev/null)
        
        if [ -n "$chan_data" ] && command -v jq &> /dev/null; then
            # Extract channel width for the specific WLAN configuration
            local channel_width=$(echo "$chan_data" | jq -r ".data.channelInfo[$((wlan_config-1))].channelwidth // \"N/A\"" 2>/dev/null)
            
            if [ "$channel_width" != "N/A" ] && [ "$channel_width" != "null" ] && [ -n "$channel_width" ]; then
                echo "NewChannelWidth $channel_width"
                echo "NewChannelWidthMHz $channel_width"
            else
                # Fallback: try to get any channel width from the data
                local fallback_width=$(echo "$chan_data" | jq -r '.data | .. | .channelwidth? // empty' 2>/dev/null | head -1)
                if [ -n "$fallback_width" ]; then
                    echo "NewChannelWidth $fallback_width"
                    echo "NewChannelWidthMHz $fallback_width"
                fi
            fi
        fi
        
        # Logout SID
        wget -O /dev/null "http://$BoxIP/home/home.lua?sid=$temp_sid&logout=1" &>/dev/null 2>&1
    fi
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
		
		# Get channel width (Enhancement for Issue #54)
		get_channel_width_for_wlan 1
		
		echo "NewGHz 2.4"
}

### ----------------------------------------------------------------------------------------------------- ###
### ------------------ FUNCTION WLANstatistics for 5 Ghz - Channel 1 - TR-064 Protocol ------------------ ###
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
		
		# Get channel width (Enhancement for Issue #54)
		get_channel_width_for_wlan 2
		
		echo "NewGHz 5"
}

### ----------------------------------------------------------------------------------------------------- ###
### ------------------ FUNCTION WLANstatistics for 5 Ghz - Channel 2 - TR-064 Protocol ------------------ ###
### ----------------------------------------------------------------------------------------------------- ###

WLAN5statistics_ch2() {
		location="/upnp/control/wlanconfig3"
		uri="urn:dslforum-org:service:WLANConfiguration:3"
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
### -------------------------------- FUNCTION LANcount - TR-064 Protocol -------------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###


LANcount() {
	# TR-064 service information
	SERVICE="urn:dslforum-org:service:Hosts:1"
	CONTROL_URL="/upnp/control/hosts"

	if verify_action_availability "$CONTROL_URL" "$SERVICE" "GetHostNumberOfEntries"; then
		# Do nothing but continue script execution
		:
	else
		echo "Action '$action' cannot be executed, because it seems to be not available."
		echo "You can try with 'fritzBoxShell.sh ACTIONS' to get a list of available services and actions."
		return
	fi

	total_hosts=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$CONTROL_URL" \
		-H 'Content-Type: text/xml; charset="utf-8"' \
		-H "SoapAction:$SERVICE#GetHostNumberOfEntries" \
		-d "<?xml version='1.0' encoding='utf-8'?>
		<s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'>
		<s:Body>
			<u:GetHostNumberOfEntries xmlns:u='$SERVICE'></u:GetHostNumberOfEntries>
		</s:Body>
		</s:Envelope>" | grep NewHostNumberOfEntries | awk -F">" '{print $2}' | awk -F"<" '{print $1}')

	# Check if total_hosts has a valid numerical value
	if [[ "$total_hosts" =~ ^[0-9]+$ ]]; then
		if [ "$total_hosts" -gt 0 ]; then
			# Maximal parallel processes
			max_parallel=10
			pids=()  # Array for process IDs

			# Loop through all hosts and query them in parallel
			for ((i=0; i<total_hosts; i++)); do
				# Query the interface for each device
				(
					interface_type=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$CONTROL_URL" \
						-H "Content-Type: text/xml; charset=\"utf-8\"" \
						-H "SoapAction:$SERVICE#GetGenericHostEntry" \
						-d "<?xml version=\"1.0\" encoding=\"utf-8\"?>
						<s:Envelope s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\">
							<s:Body>
								<u:GetGenericHostEntry xmlns:u=\"$SERVICE\"><NewIndex>$i</NewIndex></u:GetGenericHostEntry>
							</s:Body>
						</s:Envelope>" | grep NewInterfaceType | awk -F">" '{print $2}' | awk -F"<" '{print $1}')

					if [[ "$interface_type" == "Ethernet" ]]; then
						# Count Ethernet connections
						echo 1 >> /tmp/ethernet_count.tmp
					fi
				) &

				# Store process IDs
				pids+=($!)

				# If the number of background processes reaches the limit, we wait for the first process
				if (( ${#pids[@]} >= max_parallel )); then
					# Wait for one of the running processes
					wait "${pids[0]}"
					# Remove the first process from the array
					pids=("${pids[@]:1}")
				fi
			done

			wait

			# Sum of Ethernet connections
			if [[ -s /tmp/ethernet_count.tmp ]]; then
				ethernet_count=$(wc -l < /tmp/ethernet_count.tmp | awk '{print $1}')
			else
				ethernet_count=0
			fi

			# Print result
			echo "NumberOfEthernetConnections: $ethernet_count"

			# Delete temporary file if it exists
			if [[ -e /tmp/ethernet_count.tmp ]]; then
				rm /tmp/ethernet_count.tmp
			fi
		else
			echo "NumberOfEthernetConnections: 0"
		fi
	else
		echo "Error: Unable to determine the total number of hosts. Check your connection or credentials."
		return
	fi
}


### ----------------------------------------------------------------------------------------------------- ###
### ----------------------------- FUNCTION TR064_actions - TR-064 Protocol ------------------------------ ###
### ---- This function allows to go through all available services and actions on your Fritz device ----- ###
### ---------- After selecting the service and action you can launch teh according SOAP call ------------ ###
### ----------------------------------------------------------------------------------------------------- ###


TR064_actions() {
    # URL to the XML document
    XML_URL="http://$BoxIP:49000/tr64desc.xml"

    # Retrieve XML data with curl
    xml_data=$(curl -s "$XML_URL")

    # Save the XML data to a temporary file
    temp_file=$(mktemp)
    echo "$xml_data" > "$temp_file"

    echo "Extracting serviceType, controlURL, and SCPDURL from each service..."

    # Use XMLStarlet to extract the service data
    services=$(xmlstarlet sel -t -m "//*[local-name()='service']" \
        -v "concat(./*[local-name()='SCPDURL'], ' | ', ./*[local-name()='serviceType'], ' | ', ./*[local-name()='controlURL'])" -n "$temp_file")

    rm "$temp_file"

    if [ -z "$services" ]; then
        echo "No services found!"
        return
    fi

    echo
    echo "Available services:"
    echo "--------------------"
    echo "$services" | nl -w 2 -s '. '

    echo
    echo "Please enter the number of the desired service or type 'exit' to quit:"
    read -r service_number

    # Exit if the user types "exit"
    if [ "$service_number" == "exit" ]; then
        echo "Exiting..."
        return
    fi

    selected_service=$(echo "$services" | sed -n "${service_number}p")
    if [ -z "$selected_service" ]; then
        echo "Invalid selection!"
        return
    fi

    # Debugging: Print the selected service data
    echo
    echo "Selected service: $selected_service"

    # Extract individual fields
    scpd_url=$(echo "$selected_service" | cut -d '|' -f 1 | xargs)
    service_type=$(echo "$selected_service" | cut -d '|' -f 2 | xargs)
    control_url=$(echo "$selected_service" | cut -d '|' -f 3 | xargs)

    echo "controlURL: $control_url"
    echo "serviceType: $service_type"

    # Retrieve SCPD data
    scpd_data=$(curl -s "http://$BoxIP:49000$scpd_url")
    if [ -z "$scpd_data" ]; then
        echo "Error retrieving SCPD data!"
        return
    fi

    scpd_file=$(mktemp)
    echo "$scpd_data" > "$scpd_file"

    echo "----------------------------------------------------------"
    echo "Available actions for the service:"
    actions=$(xmlstarlet sel -t -m "//*[local-name()='action']" -v "concat(./*[local-name()='name'], '')" -n "$scpd_file")
    echo "$actions" | nl -w 2 -s '. '

    echo
    echo "Please enter the number of the desired action or type 'exit' to quit:"
    read -r action_number

    # Exit if the user types "exit"
    if [ "$action_number" == "exit" ]; then
        echo "Exiting..."
        return
    fi

    selected_action=$(echo "$actions" | sed -n "${action_number}p")
    if [ -z "$selected_action" ]; then
        echo "Invalid selection!"
        return
    fi

	# Retrieve and display all arguments (both 'in' and 'out' directions)
    all_arguments=$(xmlstarlet sel -t -m "//*[local-name()='action']/*[local-name()='name' and text()='$selected_action']/../*[local-name()='argumentList']/*[local-name()='argument']" \
        -v "concat(./*[local-name()='name'], ' (', ./*[local-name()='direction'], ')')" -n "$scpd_file")

    echo
    echo "Available arguments for action '$selected_action':"
    echo "$all_arguments"

    # Retrieve arguments with Direction=in
    in_arguments=$(xmlstarlet sel -t -m "//*[local-name()='action']/*[local-name()='name' and text()='$selected_action']/../*[local-name()='argumentList']/*[local-name()='argument']" \
        -v "concat(./*[local-name()='name'], ' (', ./*[local-name()='direction'], ')')" -n "$scpd_file" | grep "(in)")

    # Verwende normale Arrays statt assoziativen Arrays
    inputs=()

    if [ -n "$in_arguments" ]; then
        echo "The action requires input values for the following arguments:"

        # Extract only the names of arguments with direction 'in'
        in_argument_names=$(xmlstarlet sel -t \
            -m "//*[local-name()='action']/*[local-name()='name' and text()='$selected_action']/../*[local-name()='argumentList']/*[local-name()='argument'][./*[local-name()='direction']='in']" \
            -v "./*[local-name()='name']" -n "$scpd_file")

        if [ -z "$in_argument_names" ]; then
            echo "Error: No input arguments could be extracted. Please check the SCPD data."
            return 1
        fi

        in_argument_names=$(echo "$in_argument_names" | xargs)  # Trim whitespace

        # Debugging: Print argument names to see their format
        echo "Extracted input argument names:"
        echo "$in_argument_names"

        # Prompt user for input values for each argument
        for arg_name in $in_argument_names; do
            if [ -n "$arg_name" ]; then
                echo -n "Please enter a value for $arg_name: "
                read -r value
                inputs+=("$arg_name=$value")  # Store the value in the array
            fi
        done
    else
        echo "No input arguments are required for this action."
    fi

    echo "Starting SOAP call..."
    echo
    echo "controlURL: $control_url"
    echo "serviceType: $service_type"
    echo "selectedAction: $selected_action"
    echo

    # Build the SOAP body
    soap_body="<s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'>"
    soap_body+="<s:Body><u:$selected_action xmlns:u='$service_type'>"

    # Iteriere über alle Argumente und füge sie korrekt hinzu
    for input in "${inputs[@]}"; do
        # Extrahiere den Argumentnamen und den Wert
        arg_name=$(echo "$input" | cut -d '=' -f 1)
        value=$(echo "$input" | cut -d '=' -f 2)

        soap_body+="<$arg_name>$value</$arg_name>"
    done

    soap_body+="</u:$selected_action></s:Body></s:Envelope>"

    # Perform the SOAP call
    curl_output=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$control_url" \
        -H 'Content-Type: text/xml; charset="utf-8"' \
        -H "SoapAction:$service_type#$selected_action" \
        -d "$soap_body")

    # Output SOAP response
    echo
    echo "SOAP Response:"
    echo "$curl_output"

	rm "$scpd_file"
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
    action='GetExternalIPAddress'

    readout

    location="/igdupnp/control/WANIPConn1"
	uri="urn:schemas-upnp-org:service:WANIPConnection:1"
	action='ForceTermination'

	if verify_action_availability "$location" "$uri" "$action"; then
		# Do nothing but continue script execution
		:
	else
		echo "Action '$action' canot be executed, because it seems to be not available."
		echo "You can try with "fritzBoxShell.sh ACTIONS" to get a list of available services and actions."
		return
	fi

    echo ""
    echo "WAN RECONNECT initiated - Waiting for new IP... (30 seconds)"

    curl -k -m 25 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?> <s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'> <s:Body> <u:$action xmlns:u='$uri' /> </s:Body> </s:Envelope>" &>/dev/null

    sleep 30

    echo ""
    echo "FINISHED. Find new IP Address below:"

    #Display IP Address after reconnect
    location="/igdupnp/control/WANIPConn1"
    uri="urn:schemas-upnp-org:service:WANIPConnection:1"
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

			if verify_action_availability "$location" "$uri" "$action"; then
				# Do nothing but continue script execution
				:
			else
				echo "Action '$action' canot be executed, because it seems to be not available."
				echo "You can try with "fritzBoxShell.sh ACTIONS" to get a list of available services and actions."
				return
			fi
			
			curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" \
			-H 'Content-Type: text/xml; charset="utf-8"' \
			-H "SoapAction:$uri#$action" \
			-d "<?xml version='1.0' encoding='utf-8'?>
				<s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'>
					<s:Body>
						<u:$action xmlns:u='$uri'>
							<NewIndex>$option2</NewIndex>
						</u:$action>
					</s:Body>
				</s:Envelope>" | grep "<New" | awk -F"</" '{print $1}' |sed -En "s/<(.*)>(.*)/\1 \2/p"

		# Switch ON the TAM
	elif [ "$option3" = "ON" ]; then
			action='SetEnable'

			if verify_action_availability "$location" "$uri" "$action"; then
				# Do nothing but continue script execution
				:
			else
				echo "Action '$action' canot be executed, because it seems to be not available."
				echo "You can try with "fritzBoxShell.sh ACTIONS" to get a list of available services and actions."
				return
			fi

			curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" \
			-H 'Content-Type: text/xml; charset="utf-8"' \
			-H "SoapAction:$uri#$action" \
			-d "<?xml version='1.0' encoding='utf-8'?>
				<s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'>
					<s:Body>
						<u:$action xmlns:u='$uri'>
							<NewIndex>$option2</NewIndex>
							<NewEnable>1</NewEnable>
						</u:$action>
					</s:Body>
				</s:Envelope>" | grep "<New" | awk -F"</" '{print $1}' |sed -En "s/<(.*)>(.*)/\1 \2/p"
			echo "Answering machine is switched ON"

		# Switch OFF the TAM
	elif [ "$option3" = "OFF" ]; then
			action='SetEnable'

			if verify_action_availability "$location" "$uri" "$action"; then
				# Do nothing but continue script execution
				:
			else
				echo "Action '$action' canot be executed, because it seems to be not available."
				echo "You can try with "fritzBoxShell.sh ACTIONS" to get a list of available services and actions."
				return
			fi

			curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" \
			-H 'Content-Type: text/xml; charset="utf-8"' \
			-H "SoapAction:$uri#$action" \
			-d "<?xml version='1.0' encoding='utf-8'?>
					<s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'>
						<s:Body>
							<u:$action xmlns:u='$uri'>
								<NewIndex>$option2</NewIndex>
								<NewEnable>0</NewEnable>
							</u:$action>
						</s:Body>
					</s:Envelope>" | grep "<New" | awk -F"</" '{print $1}' |sed -En "s/<(.*)>(.*)/\1 \2/p"
			echo "Answering machine is switched OFF"

		# Get CallList from TAM
	elif [ "$option3" = "GetMsgs" ]; then
			action='GetMessageList'

			if verify_action_availability "$location" "$uri" "$action"; then
				# Do nothing but continue script execution
				:
			else
				echo "Action '$action' canot be executed, because it seems to be not available."
				echo "You can try with "fritzBoxShell.sh ACTIONS" to get a list of available services and actions."
				return
			fi

			curlOutput1=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" \
			-H 'Content-Type: text/xml; charset="utf-8"' \
			-H "SoapAction:$uri#$action" \
			-d "<?xml version='1.0' encoding='utf-8'?>
				<s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'>
					<s:Body>
						<u:$action xmlns:u='$uri'>
							<NewIndex>$option2</NewIndex>
						</u:$action>
					</s:Body>
				</s:Envelope>" | grep "<New" | awk -F"</" '{print $1}' |sed -En "s/<(.*)>(.*)/\1 \2/p")

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

			if verify_action_availability "$location" "$uri" "$action"; then
				# Do nothing but continue script execution
				:
			else
				echo "Action '$action' canot be executed, because it seems to be not available."
				echo "You can try with "fritzBoxShell.sh ACTIONS" to get a list of available services and actions."
				return
			fi

			listurl=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" \
			-H 'Content-Type: text/xml; charset="utf-8"' \
			-H "SoapAction:$uri#$action" \
			-d "<?xml version='1.0' encoding='utf-8'?>
				<s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'>
					<s:Body>
						<u:$action xmlns:u='$uri'>
						</u:$action>
					</s:Body>
				</s:Envelope>" | grep "<New" | awk -F"</" '{print $1}' | sed -En "s/<(.*)>(.*)/\1 \2/p" | awk '{print $2}')

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
		
		if verify_action_availability "$location" "$uri" "$action"; then
				# Do nothing but continue script execution
				:
		else
			echo "Action '$action' canot be executed, because it seems to be not available."
			echo "You can try with "fritzBoxShell.sh ACTIONS" to get a list of available services and actions."
			return
		fi

		if [ "$option2" = "0" ] || [ "$option2" = "1" ]; then echo "Sending WLAN_2G $1"; curl -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'><NewEnable>$option2</NewEnable></u:$action></s:Body></s:Envelope>" -s > /dev/null; fi # Changing the state of the WIFI

		action='GetInfo'
		
		if verify_action_availability "$location" "$uri" "$action"; then
				# Do nothing but continue script execution
				:
		else
			echo "Action '$action' canot be executed, because it seems to be not available."
			echo "You can try with "fritzBoxShell.sh ACTIONS" to get a list of available services and actions."
			return
		fi

		if [ "$option2" = "STATE" ]; then
			curlOutput1=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewEnable | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
			curlOutput2=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewSSID | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
			echo "2,4 Ghz Network $curlOutput2 is $curlOutput1"
		fi

		action='SetChannel'
		
		if verify_action_availability "$location" "$uri" "$action"; then
				# Do nothing but continue script execution
				:
		else
			echo "Action '$action' canot be executed, because it seems to be not available."
			echo "You can try with "fritzBoxShell.sh ACTIONS" to get a list of available services and actions."
			return
		fi
		
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
		
		if verify_action_availability "$location" "$uri" "$action"; then
				# Do nothing but continue script execution
				:
		else
			echo "Action '$action' canot be executed, because it seems to be not available."
			echo "You can try with "fritzBoxShell.sh ACTIONS" to get a list of available services and actions."
			return
		fi

		if [ "$option2" =  "QRCODE" ]; then
			ssid=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewSSID | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
			action='GetSecurityKeys'
			keyPassphrase=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewKeyPassphrase | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
			echo "QR Code for 2,4 Ghz:"
			qrencode -t ansiutf8 "WIFI:S:$ssid;T:WPA;P:$keyPassphrase;;"
			echo ""
		fi
	fi

	if [ "$option1" = "WLAN_5G" ] || [ "$option1" = "WLAN" ] || [ "$option1" = "WLAN_5G_CH2" ]; then
		location="/upnp/control/wlanconfig2"
		uri="urn:dslforum-org:service:WLANConfiguration:2"
		action='SetEnable'

		if [ "$option1" = "WLAN_5G_CH2" ]; then
			location="/upnp/control/wlanconfig3"
			uri="urn:dslforum-org:service:WLANConfiguration:3"
			action='SetEnable'
		fi
		
		if verify_action_availability "$location" "$uri" "$action"; then
				# Do nothing but continue script execution
				:
		else
			echo "Action '$action' canot be executed, because it seems to be not available."
			echo "You can try with "fritzBoxShell.sh ACTIONS" to get a list of available services and actions."
			return
		fi

		if [ "$option2" = "0" ] || [ "$option2" = "1" ]; then echo "Sending WLAN_5G $1"; curl -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'><NewEnable>$option2</NewEnable></u:$action></s:Body></s:Envelope>" -s > /dev/null; fi # Changing the state of the WIFI

		action='GetInfo'
		if [ "$option2" = "STATE" ]; then
			curlOutput1=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewEnable | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
			curlOutput2=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewSSID | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
			echo "  5 Ghz Network $curlOutput2 is $curlOutput1"
		fi

		action='SetChannel'
		
		if verify_action_availability "$location" "$uri" "$action"; then
				# Do nothing but continue script execution
				:
		else
			echo "Action '$action' canot be executed, because it seems to be not available."
			echo "You can try with "fritzBoxShell.sh ACTIONS" to get a list of available services and actions."
			return
		fi

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
		
		if verify_action_availability "$location" "$uri" "$action"; then
				# Do nothing but continue script execution
				:
		else
			echo "Action '$action' canot be executed, because it seems to be not available."
			echo "You can try with "fritzBoxShell.sh ACTIONS" to get a list of available services and actions."
			return
		fi

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
		
			if verify_action_availability "$location" "$uri" "$action"; then
					# Do nothing but continue script execution
					:
			else
				echo "Action '$action' canot be executed, because it seems to be not available."
				echo "You can try with "fritzBoxShell.sh ACTIONS" to get a list of available services and actions."
				return
			fi

			if [ "$option2" = "0" ] || [ "$option2" = "1" ]; then echo "Sending WLAN_GUEST $1"; curl -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'><NewEnable>$option2</NewEnable></u:$action></s:Body></s:Envelope>" -s > /dev/null; fi # Changing the state of the WIFI

			action='GetInfo'
		
			if verify_action_availability "$location" "$uri" "$action"; then
					# Do nothing but continue script execution
					:
			else
				echo "Action '$action' canot be executed, because it seems to be not available."
				echo "You can try with "fritzBoxShell.sh ACTIONS" to get a list of available services and actions."
				return
			fi

			if [ "$option2" = "STATE" ]; then
				curlOutput1=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewEnable | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
				curlOutput2=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewSSID | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
				echo "  Guest Network $curlOutput2 is $curlOutput1"
			fi

			action='GetSSID'
		
			if verify_action_availability "$location" "$uri" "$action"; then
					# Do nothing but continue script execution
					:
			else
				echo "Action '$action' canot be executed, because it seems to be not available."
				echo "You can try with "fritzBoxShell.sh ACTIONS" to get a list of available services and actions."
				return
			fi

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
		
	if verify_action_availability "$location" "$uri" "$action"; then
			# Do nothing but continue script execution
			:
	else
		echo "Action '$action' canot be executed, because it seems to be not available."
		echo "You can try with "fritzBoxShell.sh ACTIONS" to get a list of available services and actions."
		return
	fi

	echo "Sending Repeater WLAN $1"; curl -k -m 5 --anyauth -u "$RepeaterUSER:$RepeaterPW" "http://$RepeaterIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'><NewEnable>$option2</NewEnable></u:$action></s:Body></s:Envelope>" -s > /dev/null

}

### ----------------------------------------------------------------------------------------------------- ###
### ------------------------------- FUNCTION WakeOnLAN - TR-064 Protocol -------------------------------- ###
### ------------------------------- Function to switch on devices via LAN ------------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

WakeOnLAN() {


	# Building the inputs for the SOAP Action
	DEVICE_MAC=$option2

	# TR-064 service information
	SERVICE="urn:dslforum-org:service:Hosts:1"
	CONTROL_URL="/upnp/control/hosts"
	ACTION='X_AVM-DE_WakeOnLANByMACAddress'

	if verify_action_availability "$CONTROL_URL" "$SERVICE" "$ACTION"; then
			# Do nothing but continue script execution
			:
	else
		echo "Action '$action' canot be executed, because it seems to be not available."
		echo "You can try with "fritzBoxShell.sh ACTIONS" to get a list of available services and actions."
		return
	fi

	# Send the SOAP request
	RESPONSE=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$CONTROL_URL" \
		-H 'Content-Type: text/xml; charset="utf-8"' \
		-H "SoapAction: $SERVICE#$ACTION" \
		-d "<?xml version='1.0' encoding='utf-8'?>
		<s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'>
		<s:Body>
			<u:$ACTION xmlns:u='$SERVICE'>
				<NewMACAddress>${DEVICE_MAC}</NewMACAddress>
			</u:$ACTION>
		</s:Body>
		</s:Envelope>")

	# Check the response and print the result
	if echo "$RESPONSE" | grep -q '<u:X_AVM-DE_WakeOnLANByMACAddressResponse xmlns:u="urn:dslforum-org:service:Hosts:1"></u:X_AVM-DE_WakeOnLANByMACAddressResponse>'; then
		echo "Wake-on-LAN request was successful sent to MAC-Address: $option2."
	else
		echo "Wake-on-LAN request failed or no response received (used MAC-Address: $option2)."
	fi


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
		
	if verify_action_availability "$location" "$uri" "$action"; then
			# Do nothing but continue script execution
			:
	else
		echo "Action '$action' canot be executed, because it seems to be not available."
		echo "You can try with "fritzBoxShell.sh ACTIONS" to get a list of available services and actions."
		return
	fi

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
		
		if verify_action_availability "$location" "$uri" "$action"; then
				# Do nothing but continue script execution
				:
		else
			echo "Action '$action' canot be executed, because it seems to be not available."
			echo "You can try with "fritzBoxShell.sh ACTIONS" to get a list of available services and actions."
			return
		fi

		securityPort=$(curl -s -k -m 5 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" | grep NewSecurityPort | awk -F">" '{print $2}' | awk -F"<" '{print $1}')
		
		#echo "$securityPort"

		location="/upnp/control/deviceconfig"
		uri="urn:dslforum-org:service:DeviceConfig:1"
		action='X_AVM-DE_GetConfigFile'
		option2='testing'
			
		if verify_action_availability "$location" "$uri" "$action"; then
				# Do nothing but continue script execution
				:
		else
			echo "Action '$action' canot be executed, because it seems to be not available."
			echo "You can try with "fritzBoxShell.sh ACTIONS" to get a list of available services and actions."
			return
		fi

		curlOutput1=$(curl -s --connect-timeout 60 -k -m 60 --anyauth -u "$BoxUSER:$BoxPW" "https://$BoxIP:$securityPort$location" -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'><NewX_AVM-DE_Password>$option2</NewX_AVM-DE_Password></u:$action></s:Body></s:Envelope>" | grep NewX_AVM-DE_ConfigFileUrl | awk -F">" '{print $2}' | awk -F"<" '{print $1}')

		# File Downlaod
		dt=$(date '+%Y%m%d_%H%M%S');
		
		$(curl -s -k "$curlOutput1" -o "$backupConfFolder${dt}_$backupConfFilename.export" --anyauth -u "$BoxUSER:$BoxPW")
		if [ -e "${backupConfFolder}${dt}_${backupConfFilename}.export" ]; then
    		echo "File successfully downloaded: ${backupConfFolder}${dt}_${backupConfFilename}.export"
		fi

}

### ----------------------------------------------------------------------------------------------------- ###
### --------------------------- FUNCTION FritzBox Send SMS - TR-064 Protocol ---------------------------- ###
### ----------------------------------------------------------------------------------------------------- ###

sendSMS() {
		location="/upnp/control/x_tam"
		uri="urn:dslforum-org:service:X_AVM-DE_TAM:1"
		action='X_AVM-DE_SendSMS'

		if verify_action_availability "$location" "$uri" "$action"; then
				# Do nothing but continue script execution
				:
		else
			echo "Action '$action' canot be executed, because it seems to be not available."
			echo "You can try with "fritzBoxShell.sh ACTIONS" to get a list of available services and actions."
			return
		fi

		PHONE_NUMBER=$option2
		MESSAGE=$option3

		echo "WARNING: This function was never tested. Please report any issues to the developer. Thanks. Refer to Issue https://github.com/jhubig/FritzBoxShell/issues/40."

		RESPONSE=$(curl -k -m 30 --anyauth -u "$BoxUSER:$BoxPW" "http://$BoxIP:49000$location" \
			-H 'Content-Type: text/xml; charset="utf-8"' \
			-H "SoapAction:$uri#$action" \
			-d "<?xml version='1.0' encoding='utf-8'?>
				<s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'>
					<s:Body>
						<u:$action xmlns:u='$uri'>
							<NewPhoneNumber>$PHONE_NUMBER</NewPhoneNumber>
                        	<NewMessage>$MESSAGE</NewMessage>
						</u:$action>
					</s:Body>
				</s:Envelope>")
		
		echo "Reponse from FritzBox: $RESPONSE"

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
	echo "| WLAN_5G_CH2     | STATISTICS                | Statistics for the 2nd Ch of the 5 Ghz WiFi easily digestible by telegraf   |"
	echo "| WLAN_GUEST      | 0 or 1 or STATE           | Switching ON, OFF or checking the state of the Guest WiFi                   |"
	echo "| WLAN_GUEST      | STATISTICS                | Statistics for the Guest WiFi easily digestible by telegraf                 |"
	echo "| WLAN_GUEST      | QRCODE                    | Show a qr code to connect to the Guest WiFi                                 |"
	echo "| WLAN            | 0 or 1 or STATE           | Switching ON, OFF or checking the state of the 2,4Ghz and 5 Ghz WiFi        |"
	echo "| WLAN            | QRCODE                    | Show a qr code to connect to the 2,4 and 5 Ghz WiFi                         |"
	echo "| WLAN            | CHANGECH and <channel>    | Change channel of the 2,4 and 5 Ghz WiFi to optional <channel>              |"
	echo "| COUNT           | <option> optional -withIP | Counts devices for <option> (2.4 , 5, ETH, all) + lists optionally the IPs  |"
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
	echo "| WIREGUARD_VPN   | <name> and 0 or 1         | Name of your connection in \"\" (e.g. \"Test 1\"). 0 (OFF) and 1 (ON)           |"
	echo "|-----------------|---------------------------|-----------------------------------------------------------------------------|"
	echo "| MISC_LUA        | totalConnectionsWLAN      | Number of total connected WLAN clients (incl. full Mesh)                    |"
	echo "| MISC_LUA        | totalConnectionsWLAN2G    | Number of total connected 2,4 Ghz WLAN clients (incl. full Mesh)            |"
	echo "| MISC_LUA        | totalConnectionsWLAN5G    | Number of total connected 5 Ghz WLAN clients (incl. full Mesh)              |"
	echo "| MISC_LUA        | totalConnectionsWLANguest | Number of total connected Guest WLAN clients (incl. full Mesh)              |"
	echo "| MISC_LUA        | totalConnectionsLAN       | Number of total connected LAN clients (incl. full Mesh)                     |"
	echo "| MISC_LUA        | ReadLog                   | Readout of the event log on the console                                     |"
	echo "| MISC_LUA        | ResetLog                  | Reset the event log                                                         |"
	echo "|-----------------|---------------------------|-----------------------------------------------------------------------------|"
    echo "| LAN             | STATE                     | Statistics for the LAN easily digestible by telegraf                        |"
    echo "| LAN             | COUNT                     | Total number of connected devices through ethernet                          |"
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
	echo "| BACKUP          | <password>                | Parameter <password> to define a password for your conf file                |"
	echo "| SENDSMS         | <NUMBER> and <MESSAGE>    | ALPHA - NOT TESTED YET                                                      |"
	echo "| KIDS            | userid and true|false     | Block / unblock internet access for certain machine                         |"
	echo "| SETPROFILE      | dev devname profile       | Put a device (name and id) into a profile                                   |"
	echo "| WOL             | <MAC-ADDRESS>             | Send a Wake-On-LAN request to a ethernet device                             |"
	echo "| LISTDEVICES     |                           | List all known devices with name, MAC, IP, device ID and profile info       |"
	echo "| LISTPROFILES    |                           | List available filter profiles for use with SETPROFILE                      |"
	echo "| DEVICEPROFILES  |                           | Show devices with their current profile assignments                         |"
	echo "|-----------------|---------------------------|-----------------------------------------------------------------------------|"
	echo "| VERSION         |                           | Version of the fritzBoxShell.sh                                             |"
	echo "| ACTIONS         |                           | Loop through all services and actions and make SOAP CALL                    |"
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
		elif [ "$option1" = "ACTIONS" ]; then
			TR064_actions
		elif [ "$option1" = "LISTDEVICES" ]; then
			ListAllDevices
		elif [ "$option1" = "LISTPROFILES" ]; then
			ListProfiles
		elif [ "$option1" = "DEVICEPROFILES" ]; then
			ListDevicesWithProfiles
        else DisplayArguments
        fi
else
	#If argument was provided, check which function to be called
	if [ "$option1" = "WLAN_2G" ] || [ "$option1" = "WLAN_5G" ] || [ "$option1" = "WLAN_5G_CH2" ] || [ "$option1" = "WLAN_GUEST" ] || [ "$option1" = "WLAN" ]; then
		if [ "$option2" = "1" ]; then WLANstate "ON";
		elif [ "$option2" = "0" ]; then WLANstate "OFF";
		elif [ "$option2" = "STATE" ]; then WLANstate "STATE";
		elif [ "$option2" = "CHANGECH" ]; then WLANstate "CHANGECH";
		elif [ "$option2" = "QRCODE" ]; then
			if ! command -v qrencode &> /dev/null; then
				echo "Error: qrencode is request to show the qr code. Not installed on this machine"
				exit 1
			fi
			WLANstate "QRCODE";
		elif [ "$option2" = "STATISTICS" ]; then
			if [ "$option1" = "WLAN_2G" ]; then WLANstatistics;
			elif [ "$option1" = "WLAN_5G" ]; then WLAN5statistics;
			elif [ "$option1" = "WLAN_5G_CH2" ]; then WLAN5statistics_ch2;
			elif [ "$option1" = "WLAN_GUEST" ]; then WLANGUESTstatistics;
			else DisplayArguments
			fi
		else DisplayArguments
		fi
	elif [ "$option1" = "LAN" ]; then
		if [ "$option2" = "STATE" ]; then LANstate "$option2";
		elif [ "$option2" = "COUNT" ]; then LANcount "$option2";
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
		if [ "$option2" = "ReadLog" ] || [ "$option2" = "ResetLog" ]; then LUAmisc_Log
		else LUAmisc "$option2";
		fi
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
    elif [ "$option1" = "SETPROFILE" ]; then
    	SetProfile "$option2" "$option3";
	elif [ "$option1" = "BACKUP" ]; then
        confBackup "$option2";
	elif [ "$option1" = "SENDSMS" ]; then
        sendSMS "$option2" "$option3";
	elif [ "$option1" = "WOL" ]; then
        WakeOnLAN "$option2";
	elif [ "$option1" = "COUNT" ]; then
		get_filtered_clients "$option2" "$option3";
	else DisplayArguments
	fi
fi