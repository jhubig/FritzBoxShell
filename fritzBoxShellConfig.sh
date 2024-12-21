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

# In case you are using the Fritz!Box Backup export this path is used to download the backup - kepp empty if you want to use the same directory than the script
[[ -z "$backupConfFolder" ]] && backupConfFolder="" # Dont forget the "/" at the end!!!