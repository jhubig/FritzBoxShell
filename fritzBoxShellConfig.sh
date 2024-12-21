#!/bin/bash

#******************************************************#
#*********************** CONFIG ***********************#
#******************************************************#

# Fritz!Box Config
[[ -z "$BoxIP" ]] && BoxIP="fritz.box"
[[ -z "$BoxUSER" ]] && BoxUSER="YourUser"
[[ -z "$BoxPW" ]] && BoxPW="YourPassword"

# Fritz!Repeater Config
[[ -z "$RepeaterIP" ]] && RepeaterIP="fritz.repeater"
[[ -z "$RepeaterUSER" ]] && RepeaterUSER="" #Usually on Fritz!Repeater no User is existing. Can be left empty.
[[ -z "$RepeaterPW" ]] && RepeaterPW="YourPassword"


##### Backup of FritzBox COnfiguration parameters
# This path is used to download the backup - keep empty if you want to use the same directory than the script
[[ -z "$backupConfFolder" ]] && backupConfFolder="" # Dont forget the "/" at the end!!!

# Here you can configure the 2nd part of your filename with free text
# e.g. 20241212_1212_ThisPartCanBeConfiguredBelow
[[ -z "$backupConfFilename" ]] && backupConfFilename="SicherungEinstellungen"