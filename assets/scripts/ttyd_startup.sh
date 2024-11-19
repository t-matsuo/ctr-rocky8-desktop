#!/bin/bash

mkfifo /var/run/nafder/ttyd
exec 1>>/var/run/nafder/ttyd
exec 2>>/var/run/nafder/ttyd

exec /usr/local/bin/ttyd $TTYD_OPTS -W -p 57575 -i lo -b /term/ -t 'theme={"background": "black", "foreground": "#b3b3b3"}' -- /bin/bash --login
