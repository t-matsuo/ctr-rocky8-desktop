#!/bin/bash

mkfifo /var/run/nafder/ttyd
exec 1>>/var/run/nafder/ttyd
exec 2>>/var/run/nafder/ttyd

exec /usr/local/bin/ttyd $TTYD_OPTS -p 57575 -i lo -b /term/ /bin/bash
