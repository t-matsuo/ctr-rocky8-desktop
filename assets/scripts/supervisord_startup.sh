#!/bin/bash

#mkfifo /var/run/nafder/supervisord
#exec 1>>/var/run/nafder/supervisord
#exec 2>>/var/run/nafder/supervisord

exec /usr/bin/supervisord
