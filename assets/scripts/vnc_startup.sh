#!/bin/bash

mkfifo /var/run/nafder/vnc
exec 1>>/var/run/nafder/vnc
exec 2>>/var/run/nafder/vnc

export DISPLAY=":1"

function cleanup {
    pkill Xvnc
    pkill -f "python -m websockify"
    pkill dbus-daemon
    pkill ssh-agent
    pkill gpg-agent
    if [ -f /etc/supervisord.d/xrdp.ini ]; then
        pkill xrdp-chansrv
    fi
    if [ "$1" != "noexit" ]; then
        kill -s SIGTERM $!
        exit 0
    fi
}
trap cleanup SIGINT SIGTERM
cleanup noexit

echo -e "\n------------------ start noVNC  ----------------------------"
echo "$NO_VNC_HOME/utils/launch.sh --vnc localhost:5901 --listen localhost:6901"
$NO_VNC_HOME/utils/launch.sh --vnc localhost:5901 --listen localhost:6901 &
PID_SUB=$!

echo -e "\n------------------ start VNC server ------------------------"
echo "remove old vnc locks to be a reattachable container"
vncserver -kill $DISPLAY \
    || rm -rfv /tmp/.X*-lock /tmp/.X11-unix \
    || echo "vncserver has no locks"

echo "vncserver $DISPLAY -localhost -nolisten tcp -SecurityTypes=None"
vncserver $DISPLAY -localhost -nolisten tcp -SecurityTypes=None

echo -e "start window manager\n..."
$CTR_SCRIPTS/wm_startup.sh

## log connect options
echo -e "------------------ VNC environment started ------------------"
echo -e "VNCSERVER started on DISPLAY=$DISPLAY"

echo -e "\n------------------ start fcitx ------------------------"
while true; do
    ps -ef | grep -q -w [/]usr/bin/fcitx-dbus-watcher
    if [ $? -eq 0 ]; then
        break
    fi
    echo "waiting /usr/bin/fcitx-dbus-watcher up"
    sleep 1
done
export GTK_TM_MODULE=fcitx
export QT_TM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
fcitx &

echo -e "\n------------------ start chansrv for xrdp copy and paste ------------------------"
if [ -f /etc/supervisord.d/xrdp.ini ]; then
    xrdp-chansrv &
fi

wait $PID_SUB

