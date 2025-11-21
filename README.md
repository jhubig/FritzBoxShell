<!---
[![start with why](https://img.shields.io/badge/start%20with-why%3F-brightgreen.svg?style=flat)](http://www.ted.com/talks/simon_sinek_how_great_leaders_inspire_action)
--->
[![GitHub release](https://img.shields.io/github/release/jhubig/FritzBoxShell/all.svg?maxAge=1)](https://GitHub.com/jhubig/FritzBoxShell/releases/)
[![GitHub tag](https://img.shields.io/github/tag/jhubig/FritzBoxShell.svg)](https://GitHub.com/jhubig/FritzBoxShell/tags/)
[![made-with-bash](https://img.shields.io/badge/Made%20with-Bash-1f425f.svg)](https://www.gnu.org/software/bash/)
[![GitHub license](https://img.shields.io/github/license/jhubig/FritzBoxShell.svg)](https://github.com/jhubig/FritzBoxShell/blob/master/LICENSE)
[![GitHub issues](https://img.shields.io/github/issues/jhubig/FritzBoxShell.svg)](https://GitHub.com/jhubig/FritzBoxShell/issues/)
[![GitHub issues-closed](https://img.shields.io/github/issues-closed/jhubig/FritzBoxShell.svg)](https://GitHub.com/jhubig/FritzBoxShell/issues?q=is%3Aissue+is%3Aclosed)
[![contributions welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat)](https://github.com/jhubig/FritzBoxShell/issues)
[![GitHub contributors](https://img.shields.io/github/contributors/jhubig/FritzBoxShell.svg)](https://GitHub.com/jhubig/FritzBoxShell/graphs/contributors/)
[![Github All Releases](https://img.shields.io/github/downloads/jhubig/FritzBoxShell/total.svg)](https://github.com/jhubig/FritzBoxShell)
[![Github All Releases](https://img.shields.io/github/watchers/jhubig/FritzBoxShell?style=social)](https://github.com/jhubig/FritzBoxShell)

# FritzBoxShell

![AVM_FRITZ_Labor_FRITZBox_7490-min.jpg](img/AVM_FRITZ_Labor_FRITZBox_7490-min.jpg?raw=true "AVM_FRITZ_Labor_FRITZBox_7490-min.jpg")

(Image credit: https://avm.de/presse/pressefotos/?q=7490)

## Introduction

The script allows you to control/check your FritzBox from the terminal with a shell script. It is planned to add more functions in the future.
The shell script uses cURL to create an SOAP request based on the TR-064 protocol to talk to the AVM Fritz!Box and AVM Fritz!Repeater.

To change state of the LEDs in front of the Fritz!Box or activate the keylock (buttons on the can be activated or deactivated) the TR-064 protocol does not offer the possibility. Therefore the AHA-HTTP-Interface is used. This only works from firmware version `7.10` and upwards.

Please raise an issue with your function you would like to add.

### Become a part of it!

If you want to check out if your AVM device actually works with this script, you can do so by executing `fritzBoxShellTest.sh`. It prints for (almost) every Service/Action pair if they delivered data when called.

Authentication is handled exactly as described for `fritzBoxShell.sh`.

The result is a list written to the console containing the names of the checked service and actions followed by the result of the check. Finally, the device type and firmware version are printed (of course only if this functionality was accessible!).

As an example - the result for my Fritz!Box:

```
WLAN_2G STATISTICS43	is working!
WLAN_2G STATE6	is working!
WLAN_5G STATISTICS43	is working!
WLAN_2G STATE6	is working!
WLAN STATE12	is working!
LAN STATE8	is working!
DSL STATE0	is not working!
WAN STATE16	is working!
LINK STATE0	is not working!
IGDWAN STATE28	is working!
IGDDSL STATE15	is working!
IGDIP STATE48	is working!
NewModelName FRITZ!Box 6490 Cable (kdg)
NewSoftwareVersion 141.06.87
```

## Installing, configuring and first script execution

Head over to the Wiki pages to get all the information: https://github.com/jhubig/FritzBoxShell/wiki/Installation,-Configuration-&-First-test

Short summary also here - Following packages need to be installed on your machine:

```
sudo apt-get install curl
sudo apt-get install wget
sudo apt-get install jq
sudo apt-get install xmlstarlet
```

## Arguments/Enviroments

You can use variables or arguments. However, arguments are visible in the process list and are therefore not recommended for passwords.

If these arguments or environment variables are not set, then the values from the fritzBoxShellConfig.sh are used.

Here an example (This will enable the 2.4 Ghz network on the box with the following IP):

`./fritzBoxShell.sh --boxip 192.168.178.1 --boxuser foo --boxpw baa WLAN_2G 1`

| Enviroment | Argument | Description |
|---|---|---|
| BoxIP | --boxip | IP or DNS of FritzBox |
| BoxUSER | --boxuser | Username |
| BoxPW | --boxpw | Login password for user. |
| RepeaterIP | --repeaterip | IP or DNS of FritzRepeater |
| RepeaterUSER | --repeateruser | Usually on Fritz!Repeater no User is existing. Can be left empty. |
| RepeaterPW | --repeaterpw | Password for user. |
| backupConfFolder | --backupconffolder | Folder in which the backup is stored in case you create a backup of the FritzBox conf (see BACKUP param). |
| backupConfFilename | --backupconffilename | Filename for the backup of the FritzBox conf (see BACKUP param). |


## Usage

After the successful installation and setup following functions should be available.

| Action | Parameter | Description |
| --- | --- | --- |
| DEVICEINFO | STATE | Show information about your Fritz!Box like ModelName, SN, etc. |
| WLAN_2G | 0 or 1 or STATE | Switching ON, OFF or checking the state of the 2,4 Ghz WiFi |
| WLAN_2G  | STATISTICS | Statistics for the 2,4 Ghz WiFi with channel width info (20/40/80/160/320 MHz) |
| WLAN_2G | QRCODE | Show a qr code to connect to the 2,4 Ghz WiFi |
| WLAN_2G | CHANGECH and \<channel> | Change channel of the 2,4 Ghz WiFi to optional \<channel> (random if absent) |
| WLAN_5G | 0 or 1 or STATE | Switching ON, OFF or checking the state of the 5 Ghz WiFi |
| WLAN_5G  | STATISTICS | Statistics for the 5 Ghz WiFi with channel width info (20/40/80/160/320 MHz) |
| WLAN_5G | QRCODE | Show a qr code to connect to the 5 Ghz WiFi |
| WLAN_5G | CHANGECH and \<channel> | Change channel of the 5 Ghz WiFi to optional \<channel> (random if absent) |
| WLAN_GUEST | 0 or 1 or STATE | Switching ON, OFF or checking the state of the Guest WiFi |
| WLAN_GUEST | STATISTICS | Statistics for the Guest WiFi easily digestible by telegraf |
| WLAN_GUEST | QRCODE | Show a qr code to connect to the Guest WiFi |
| WLAN | 0 or 1 or STATE | Switching ON, OFF or checking the state of the 2,4Ghz and 5 Ghz WiFi |
| WLAN | QRCODE | Show a qr code to connect to the 2,4 and 5 Ghz and Guest WiFi |
| WLAN | CHANGECH and \<channel> | Change channel of the 2,4 and 5 Ghz WiFi to optional \<channel> |
| COUNT | \<option> optional -withIP | Counts devices for \<option> (2.4 , 5, ETH, all) + lists optionally the IPs |
| TAM | \<index> and GetInfo | e.g. TAM 0 GetInfo (gives info about answering machine) |
| TAM | \<index> and ON or OFF | e.g. TAM 0 ON (switches ON the answering machine) |
| TAM | \<index> and GetMsgs | e.g. TAM 0 GetMsgs (gives XML formatted list of messages) |
| LED | 0 or 1 | Switching ON (1) or OFF (0) the LEDs in front of the Fritz!Box |
| LED_BRIGHTNESS | 1 or 2 or 3 | Setting the brightness of the LEDs in front of the Fritz!Box |
| KEYLOCK | 0 or 1 | Activate (1) or deactivate (0) the Keylock (buttons de- or activated) |
| SIGNAL_STRENGTH | 100,50,25,12 or 6 % | Set your signal strength (channel settings will then be set to manual) |
| WIREGUARD_VPN | \<name> and 0 or 1 | Name of your connection in "" (e.g. "Test 1"). 0 (OFF) and 1 (ON) |
| MISC_LUA | totalConnectionsWLAN | Number of total connected WLAN clients (incl. full Mesh) |
| MISC_LUA | totalConnectionsWLAN2G | Number of total connected 2,4 Ghz WLAN clients (incl. full Mesh) |
| MISC_LUA | totalConnectionsWLAN5G | Number of total connected 5 Ghz WLAN clients (incl. full Mesh) |
| MISC_LUA | totalConnectionsWLANguest | Number of total connected Guest WLAN clients (incl. full Mesh) |
| MISC_LUA | totalConnectionsLAN | Number of total connected LAN clients (incl. full Mesh) |
| MISC_LUA | ReadLog | Readout of the event log on the console |
| MISC_LUA | ResetLog | Reset the event log	|
| LAN | STATE | Statistics for the LAN easily digestible by telegraf |
| LAN | COUNT | Total number of connected devices through ethernet |
| DSL | STATE | Statistics for the DSL easily digestible by telegraf |
| WAN | STATE | Statistics for the WAN easily digestible by telegraf |
| WAN | RECONNECT | Ask for a new IP Address from your provider |
| LINK | STATE | Statistics for the WAN DSL LINK easily digestible by telegraf |
| IGDWAN | STATE | Statistics for the WAN LINK easily digestible by telegraf |
| IGDDSL | STATE | Statistics for the DSL LINK easily digestible by telegraf |
| IGDIP | STATE | Statistics for the DSL IP easily digestible by telegraf |
| REPEATER | 0 | Switching OFF the WiFi of the Repeater |
| REBOOT | Box or Repeater | Rebooting your Fritz!Box or Fritz!Repeater |
| UPNPMetaData | STATE or \<filename> | Full unformatted output of tr64desc.xml to console or file |
| IGDMetaData | STATE or \<filename> | Full unformatted output of igddesc.xml to console or file |
| BACKUP | <password_for_backup> | Parameter <password> to define a password for your conf file |
| KIDS | userid and true|false | Block / unblock internet access for certain machine |
| SETPROFILE | dev devname profile | Put a device (name and id) into a profile |
| LISTDEVICES | | List all known devices with name, MAC, IP, device ID and profile info |
| LISTPROFILES | | List available filter profiles for use with SETPROFILE |
| DEVICEPROFILES | | Show devices with their current profile assignments |
| DEVICEBLOCK | \<device_name_or_IP> | Block internet access for a device using TR-064 HostFilter service |
| DEVICEUNBLOCK | \<device_name_or_IP> | Unblock internet access for a device using TR-064 HostFilter service |
| VERSION | \<N/A> | Version of the fritzBoxShell.sh |
| ACTIONS | \<N/A> | Loop through all services and actions and make SOAP CALL|

## WiFi Channel Width Support

The script now includes **WiFi channel width information** in WLAN statistics, supporting modern WiFi standards including **WiFi 6 (802.11ax)** and **WiFi 7 (802.11be)** with channel widths up to **320 MHz**.

### Channel Width Features

| Command | Enhanced Output | Supported Widths |
|---------|----------------|------------------|
| `WLAN_2G STATISTICS` | Includes channel width for 2.4 GHz | 20, 40, 80, 160, 320 MHz |
| `WLAN_5G STATISTICS` | Includes channel width for 5 GHz | 20, 40, 80, 160, 320 MHz |
| `WLAN_5G_CH2 STATISTICS` | Includes channel width for 5 GHz (2nd channel) | 20, 40, 80, 160, 320 MHz |

### Sample Output with Channel Width

```bash
# Enhanced WLAN statistics now include channel width
./fritzBoxShell.sh WLAN_5G STATISTICS

# Example output:
NewTotalPacketsSent 2310897349
NewTotalPacketsReceived 3406343562
NewTotalAssociations 5
NewChannel 40
NewChannelWidth 320          # NEW: Channel width in MHz
NewChannelWidthMHz 320       # NEW: Explicit MHz unit
NewGHz 5
```

### WiFi Standards Supported

- **WiFi 4 (802.11n)**: Up to 40 MHz channel width
- **WiFi 5 (802.11ac)**: Up to 160 MHz channel width  
- **WiFi 6 (802.11ax)**: Up to 160 MHz channel width
- **WiFi 7 (802.11be)**: Up to 320 MHz channel width

## Device Management and Profile Features

The script includes enhanced device management capabilities for comprehensive network device discovery and parental control profile management.

### Device Listing Commands

| Command | Description | Example Output |
|---------|-------------|----------------|
| `LISTDEVICES` | Lists all known devices with comprehensive information | Shows device ID, name, MAC, IP, interface type, status, and profile |
| `LISTPROFILES` | Lists available filter profiles for parental controls | Shows profile ID, name, and description for use with SETPROFILE |
| `DEVICEPROFILES` | Shows devices with their current profile assignments | Combined view of devices and their assigned profiles |

### Usage Examples

```bash
# List all devices with detailed information
./fritzBoxShell.sh LISTDEVICES

# List available profiles for parental controls
./fritzBoxShell.sh LISTPROFILES

# Show devices with their current profile assignments
./fritzBoxShell.sh DEVICEPROFILES

# Use device and profile information with SETPROFILE
./fritzBoxShell.sh SETPROFILE "iPhone-15-Pro" "12345" "3"
```

### Sample Output

**LISTDEVICES:**
```
ID  Device Name          MAC Address       IP Address      Interface  Active   LAN-Dev-ID   Profile
----------------------------------------------------------------------------------------------------
0   iPhone-15-Pro        AA:BB:CC:DD:EE:01 192.168.1.100   802.11     Yes      12345        Standard
1   MacMiniM2Pro         AA:BB:CC:DD:EE:02 192.168.1.101   Ethernet   Yes      12346        Unrestricted
2   Smart-TV             AA:BB:CC:DD:EE:03 192.168.1.102   Ethernet   Yes      12347        Kids-Safe
```

**LISTPROFILES:**
```
ID    Profile Name             Description
--------------------------------------------------------------------------------
0     Standard                 Unrestricted internet access
2     Blocked                  No internet access
3     Kids-Safe                Filtered content for children
4     Gaming                   Optimized for gaming with time restrictions
```

### Performance Optimization

The device listing commands use parallel processing for optimal performance:
- **Fast execution**: Processes multiple devices simultaneously
- **Reliable data**: Uses proven TR-064 protocol for accurate device information
- **Comprehensive coverage**: Shows all known devices, including inactive ones

### Notes:

* Script will only work if device from where the script is called is in the same network (same WiFi, LAN or VPN connection)
* Not possible to switch ON the Fritz!Repeater after it has been switched OFF. This only works on Fritz!Box if still 2,4Ghz or 5Ghz is active or VPN connection to Fritz!Box is established
* IMPORTANT for the backup script: It is mandatory to have 2FA deactivated for your FritzBox. To deactivate you need to once save the backup manually in your FritzBox Webinterface. Then store the SID after you did the export and got promted with the 2FA. Then take this SID and execute the following on your terminal (afterwards the 2FA should have been disabled):

`curl -d "xhr=1&page=support&twofactor=1&sid=YOUR_SID" http://fritz.box/data.lua`

## External Links

Here you can find more information on TR-064 protocol and the available actions in your Fritz!Box or Fritz!Repeater.

* http://fritz.box:49000/tr64desc.xml
* http://fritz.repeater:49000/tr64desc.xml
* https://wiki.fhem.de/wiki/FRITZBOX#TR-064
* https://avm.de/service/schnittstellen/

AVM, FRITZ!, Fritz!Box and the FRITZ! logo are registered trademarks of AVM GmbH - https://avm.de/

## donate
<a href="https://paypal.me/jhubig/"><img src="https://github.com/andreostrovsky/donate-with-paypal/blob/master/blue.svg" height="30"></a>  
If you like this project — or just feeling generous, consider buying me a beer. Cheers! :beers:
