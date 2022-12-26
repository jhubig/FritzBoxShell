#!/bin/bash
# shellcheck disable=SC1090
#************************************************************#
#** Autor: Jürgen Key https://elbosso.github.io/index.html **#
#** Autor: Johannes Hubig <johannes.hubig@gmail.com>       **#
#************************************************************#

# The following script is supposed to test what actions are
# supported by what device with what version of the firmware

dir=$(dirname "$0")

DIRECTORY=$(cd "$dir" && pwd)
source "$DIRECTORY/fritzBoxShellConfig.sh"

## declare an array variable
declare -a services=("WLAN_2G"   "WLAN_2G" "WLAN_5G"    "WLAN_5G" "WLAN"  "LAN"   "DSL"   "WAN"   "LINK"  "IGDWAN" "IGDDSL" "IGDIP" "TAM" "OnTel")
declare -a actions=("STATISTICS" "STATE"   "STATISTICS" "STATE"   "STATE" "STATE" "STATE" "STATE" "STATE" "STATE"  "STATE"  "STATE" "0 GetInfo" "GetCallList 1")
declare -a minwords=(3           5         3            5         9       1       1       1       1       1        1        1       5      1)

## now loop through the above array
counter=0
for i in "${services[@]}"
do
	echo -n "$i" "${actions[$counter]}"
	words=$(/bin/bash "$DIRECTORY/fritzBoxShell.sh" "$i" "${actions[$counter]}"|wc -w)
	#echo -n $words
	[[ "$words" -ge ${minwords[$counter]} ]] && echo -e "\tis working!" || echo -e "\tis not working!"
	counter=$((counter+1))
done
/bin/bash "$DIRECTORY/fritzBoxShell.sh" DEVICEINFO 3 | grep NewModelName
/bin/bash "$DIRECTORY/fritzBoxShell.sh" DEVICEINFO 3 | grep NewSoftwareVersion
/bin/bash "$DIRECTORY/fritzBoxShell.sh" VERSION
