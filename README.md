# FritzBoxShell

[![GitHub release](https://img.shields.io/github/release/jhubig/FritzBoxShell.sh.svg?maxAge=1)]()

## Getting Started

This package was tested on Fritz!Box 7490, with firmware version `6.93`.

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

| Action | Parameter | Description |
| --- | --- |
| WLAN_2G | 0 or 1 | Switching ON or OFF the 2,4 Ghz WiFi |
| WLAN_5G | 0 or 1 | Switching ON or OFF the 5 Ghz WiFi |
| WLAN | 0 or 1 | Switching ON or OFF the 2,4Ghz and 5 Ghz WiFi |

## License
TBD
