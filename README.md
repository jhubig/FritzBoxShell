[![GitHub release](https://img.shields.io/github/release/jhubig/FritzBoxShell.svg?maxAge=1)]()
[![GitHub downloads](https://img.shields.io/github/downloads/jhubig/FritzBoxShell/total.svg)]()

# FritzBoxShell

![AVM_FRITZ_Labor_FRITZBox_7490-min.jpg](AVM_FRITZ_Labor_FRITZBox_7490-min.jpg?raw=true "AVM_FRITZ_Labor_FRITZBox_7490-min.jpg")

(Image credit: https://avm.de/presse/pressefotos/?q=7490)

## Introduction

The script allows you to control/check your FritzBox from the terminal with a shell script. It is planned to add more functions in the future.
The shell script uses cURL to create an SOAP request based on the TR-064 protocol to talk to the AVM Fritz!Box and AVM Fritz!Repeater.

Please raise an issue with your function you would like to add.

This package was tested on
* Fritz!Box 7490, with firmware version `6.93`
* Fritz!Repeater 310, with firmware version `6.92`

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
| WLAN_2G | 0 or 1 | Switching ON or OFF the 2,4 Ghz WiFi |
| WLAN_5G | 0 or 1 | Switching ON or OFF the 5 Ghz WiFi |
| WLAN | 0 or 1 | Switching ON or OFF the 2,4Ghz and 5 Ghz WiFi |
| REPEATER | 0 | Switching OFF the WiFi of the Repeater |

### Notes:

* Script will only work if device from where the script is called is in the same network (same WiFi, LAN or VPN connection)
* Not possible to switch ON the Fritz!Repeater after it has been switched OFF. This only works on Fritz!Box if still 2,4Ghz or 5Ghz is active or VPN connection to Fritz!Box is established

## License
TBD
