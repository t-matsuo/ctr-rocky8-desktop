#!/usr/bin/env bash

mkfifo /var/run/nafder/wm
exec 1>>/var/run/nafder/wm
exec 2>>/var/run/nafder/wm

set -e
echo -e "\n------------------ startup of Xfce4 window manager ------------------"

### disable screensaver and power management
xset -dpms &
xset s noblank &
xset s off &

### disable ssh-agnet
xfconf-query -c xfce4-session -p /startup/ssh-agent/enabled -n -t bool -s false

/usr/bin/startxfce4 --replace &
