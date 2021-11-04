#!/bin/bash

mkfifo /var/run/nafder/xrdp
exec 1>>/var/run/nafder/xrdp
exec 2>>/var/run/nafder/xrdp

exec /usr/sbin/xrdp --nodaemon
