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

## Usage

After the successful installation and setup following functions should be available.

| Action | Parameter | Description |
| --- | --- | --- |
| WLAN_2G | 0 or 1 or STATE | Switching ON, OFF or checking the state of the 2,4 Ghz WiFi |
| WLAN_2G  | STATISTICS      | Statistics for the 2,4 Ghz WiFi easily digestible by telegraf        |
| WLAN_5G | 0 or 1 or STATE | Switching ON, OFF or checking the state of the 5 Ghz WiFi |
| WLAN_5G  | STATISTICS      | Statistics for the 5 Ghz WiFi easily digestible by telegraf          |
| WLAN | 0 or 1 or STATE | Switching ON, OFF or checking the state of the 2,4Ghz and 5 Ghz WiFi |
| TAM | <index> and GetInfo | e.g. TAM 0 GetInfo (gives info about answering machine) |
| TAM | <index> and ON or OFF | e.g. TAM 0 ON (switches ON the answering machine) |
| TAM | <index> and GetMsgs | e.g. TAM 0 GetMsgs (gives XML formatted list of messages) |
| LED | 0 or 1 | Switching ON (1) or OFF (0) the LEDs in front of the Fritz!Box |
| LED | 0 or 1 | Switching ON (1) or OFF (0) the LEDs in front of the Fritz!Box |
| KEYLOCK | 0 or 1 | Activate (1) or deactivate (0) the Keylock (buttons de- or activated) |
| LAN | STATE | Statistics for the LAN easily digestible by telegraf |
| DSL | STATE | Statistics for the DSL easily digestible by telegraf |
| WAN | STATE | Statistics for the WAN easily digestible by telegraf |
| LINK | STATE | Statistics for the WAN DSL LINK easily digestible by telegraf |
| IGDWAN | STATE | Statistics for the WAN LINK easily digestible by telegraf |
| IGDDSL | STATE | Statistics for the DSL LINK easily digestible by telegraf |
| IGDIP | STATE | Statistics for the DSL IP easily digestible by telegraf |
| REPEATER | 0 | Switching OFF the WiFi of the Repeater |
| REBOOT | Box or Repeater | Rebooting your Fritz!Box or Fritz!Repeater |
| UPNPMetaData | STATE or <filename> | Full unformatted output of tr64desc.xml to console or file |
| IGDMetaData | STATE or <filename> | Full unformatted output of igddesc.xml to console or file |
| VERSION | <N/A> | Version of the fritzBoxShell.sh |

### Notes:

* Script will only work if device from where the script is called is in the same network (same WiFi, LAN or VPN connection)
* Not possible to switch ON the Fritz!Repeater after it has been switched OFF. This only works on Fritz!Box if still 2,4Ghz or 5Ghz is active or VPN connection to Fritz!Box is established

## External Links

Here you can find more information on TR-064 protocol and the available actions in your Fritz!Box or Fritz!Repeater.

* http://fritz.box:49000/tr64desc.xml
* http://fritz.repeater:49000/tr64desc.xml
* https://wiki.fhem.de/wiki/FRITZBOX#TR-064
* https://avm.de/service/schnittstellen/

AVM, FRITZ!, Fritz!Box and the FRITZ! logo are registered trademarks of AVM GmbH - https://avm.de/
