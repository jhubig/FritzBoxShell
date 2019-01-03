<!---
[![start with why](https://img.shields.io/badge/start%20with-why%3F-brightgreen.svg?style=flat)](http://www.ted.com/talks/simon_sinek_how_great_leaders_inspire_action)
--->
[![GitHub release](https://img.shields.io/github/release/elbosso/FritzBoxShell/all.svg?maxAge=1)](https://GitHub.com/elbosso/FritzBoxShell/releases/)
[![GitHub tag](https://img.shields.io/github/tag/elbosso/FritzBoxShell.svg)](https://GitHub.com/Naereen/StrapDown.js/tags/)
[![made-with-bash](https://img.shields.io/badge/Made%20with-Bash-1f425f.svg)](https://www.gnu.org/software/bash/)
[![GitHub license](https://img.shields.io/github/license/elbosso/FritzBoxShell.svg)](https://github.com/elbosso/FritzBoxShell/blob/master/LICENSE)
[![GitHub issues](https://img.shields.io/github/issues/elbosso/FritzBoxShell.svg)](https://GitHub.com/elbosso/FritzBoxShell/issues/)
[![GitHub issues-closed](https://img.shields.io/github/issues-closed/elbosso/FritzBoxShell.svg)](https://GitHub.com/elbosso/FritzBoxShell/issues?q=is%3Aissue+is%3Aclosed)
[![contributions welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat)](https://github.com/elbosso/FritzBoxShell/issues)
[![GitHub contributors](https://img.shields.io/github/contributors/elbosso/FritzBoxShell.svg)](https://GitHub.com/elbosso/FritzBoxShell/graphs/contributors/)
[![Github All Releases](https://img.shields.io/github/downloads/elbosso/FritzBoxShell/total.svg)](https://github.com/elbosso/FritzBoxShell)



# FritzBoxShell

![AVM_FRITZ_Labor_FRITZBox_7490-min.jpg](img/AVM_FRITZ_Labor_FRITZBox_7490-min.jpg?raw=true "AVM_FRITZ_Labor_FRITZBox_7490-min.jpg")

(Image credit: https://avm.de/presse/pressefotos/?q=7490)

## Introduction

The script allows you to control/check your FritzBox from the terminal with a shell script. It is planned to add more functions in the future.
The shell script uses cURL to create an SOAP request based on the TR-064 protocol to talk to the AVM Fritz!Box and AVM Fritz!Repeater.

Please raise an issue with your function you would like to add.

This package (before the fork) was tested on
* OK: Fritz!Box 7490, with firmware version `6.93`
* NOK: Fritz!Box 7490, with firmware version `06.98-53696 BETA`
  * Status check not working anymore. NewStatus field not updated. Stays "Disabled".
* OK: Fritz!Repeater 310, with firmware version `6.92`

After the fork, it has solely been tested on
* FRITZ!Box 6490 Cable (kdg) with firmware version `06.87`
  * DSL not working
  * WAN partly working (rates are always 0)
  * WANDSLLINK not working

## External Links

Here you can find more information on TR-064 protocol and the available actions in your Fritz!Box or Fritz!Repeater.

* http://fritz.box:49000/tr64desc.xml
* http://fritz.repeater:49000/tr64desc.xml
* https://wiki.fhem.de/wiki/FRITZBOX#TR-064
* https://avm.de/service/schnittstellen/

## Installing

cURL needs to be installed on your machine.

```
sudo apt-get install curl
```
Copy the fritzBoxShell.sh to your desired location (In my personal use case, I put it on a Raspberry Pi) and apply following permissions for the file:

```
chmod 755 fritzBoxShell.sh
```
## Configuration

The file fritzBoxShellConfig.sh contains all Information pertaining to endpoints and credentials. You can
choose to adjust it or you can choose to give this information as environment variables at the start of the script.
If you choose to use environment variables, you need not comment or delete anything in fritzBoxShellConfig.sh - 
environment variables alway take precedence over the contents of fritzBoxShellConfig.sh.

Calling fritzBoxShell.sh using environment variables could look like this:

```
BoxUSER=YourUser BoxPW=YourPassword ./fritzBoxShell.sh <ACTION> <PARAMETER>
```

## Usage

Just start the script and add the action and parameters:

```
./fritzBoxShell.sh <ACTION> <PARAMETER>
```

Example (Deactivates the 5Ghz on your FritzBox):

```
./fritzBoxShell.sh WLAN_5G 0
```

| Action | Parameter | Description |
| --- | --- | --- |
| WLAN_2G | 0 or 1 or STATE | Switching ON, OFF or checking the state of the 2,4 Ghz WiFi |
| WLAN_2G  | STATISTICS      | Statistics for the 2,4 Ghz WiFi easily digestible by telegraf        |
| WLAN_5G | 0 or 1 or STATE | Switching ON, OFF or checking the state of the 5 Ghz WiFi |
| WLAN_5G  | STATISTICS      | Statistics for the 5 Ghz WiFi easily digestible by telegraf          |
| WLAN | 0 or 1 or STATE | Switching ON, OFF or checking the state of the 2,4Ghz and 5 Ghz WiFi |
| LAN | STATE | Statistics for the LAN easily digestible by telegraf |
| DSL | STATE | Statistics for the DSL easily digestible by telegraf |
| WAN | STATE | Statistics for the WAN easily digestible by telegraf |
| LINK | STATE | Statistics for the WAN DSL LINK easily digestible by telegraf |
| IGDWAN | STATE | Statistics for the WAN LINK easily digestible by telegraf |
| IGDDSL | STATE | Statistics for the DSL LINK easily digestible by telegraf |
| IGDIP | STATE | Statistics for the DSL IP easily digestible by telegraf |
| REPEATER | 0 | Switching OFF the WiFi of the Repeater |
| REBOOT | Box or Repeater | Rebooting your Fritz!Box or Fritz!Repeater |

### Notes:

* Script will only work if device from where the script is called is in the same network (same WiFi, LAN or VPN connection)
* Not possible to switch ON the Fritz!Repeater after it has been switched OFF. This only works on Fritz!Box if still 2,4Ghz or 5Ghz is active or VPN connection to Fritz!Box is established

### Example Use case

Currently I'm using the script (located on my RaspberryPi which is always connected to my router via ethernet) combined with Workflow (https://itunes.apple.com/de/app/workflow/id915249334?mt=8) on my iPhone/iPad. Workflow offers the possibility to send SSH commands directly to your raspberry or to any other SSH capable device. After creating the workflow itself, I have added them to the Today Widget view for faster access.

![iOS_Workflow_SSH.png](img/iOS_Workflow_SSH.png?raw=true "iOS_Workflow_SSH.png")

### Example Use with Telegraf
Suppose, you want to visualize the overall Download Rate of your FritzBox: The way to go here is to use the Action IGDWAN with parameter STATE. It gives (for example) this output:
 
```
NewByteSendRate 265
NewByteReceiveRate 17
NewPacketSendRate 0
NewPacketReceiveRate 0
NewTotalBytesSent 0
NewTotalBytesReceived 0
NewAutoDisconnectTime 0
NewIdleDisconnectTime 0
NewDNSServer1 83.169.186.33
NewDNSServer2 83.169.186.97
NewVoipDNSServer1 83.169.186.33
NewVoipDNSServer2 83.169.186.97
NewUpnpControlEnabled 0
NewRoutedBridgedModeBoth 1

```

The important line here is the one with `NewByteReceiveRate` in it. If we augment the script execution with some pipe magic, we get exactly
the Download Rate value:

```
BoxUSER=YourUser BoxPW=YourPassword /opt/telegraf/FritzBoxShell/fritzBoxShell.sh IGDWAN STATE|grep NewByteReceiveRate|cut -d ' ' -f 2
```

Now - how to get this measurement into Telegraf? Well, Telegraf has an `exec` input that allows us to inject one measurement with a specific value. It looks like [this](https://github.com/influxdata/telegraf/tree/master/plugins/inputs/exec):
```
[[inputs.exec]]
  commands = ["<some command>"]
  name_override = "fritzbox_byte_receive_rate"
  data_format = "value"
  data_type = "integer"
```

Now for the ugly truth: we can not use the command shown earlier for where it says `some command` - we must instead use some simple bash logic:
```
[[inputs.exec]]
  commands = ["/bin/bash -c \"BoxUSER=YourUser BoxPW=YourPassword /opt/telegraf/FritzBoxShell/fritzBoxShell.sh IGDWAN STATE|grep NewByteReceiveRate|cut -d ' ' -f 2\"" ]
  name_override = "fritzbox_byte_receive_rate"
  data_format = "value"
  data_type = "integer"
```

#### Note
Data with huge absolute values probably dont fit into type `integer` - in this case, `long` is the way to go...

