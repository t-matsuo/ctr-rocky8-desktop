#!/bin/bash

mkfifo /var/run/nafder/xrdp-sesman
exec 1>>/var/run/nafder/xrdp-sesman
exec 2>>/var/run/nafder/xrdp-sesman

exec /usr/sbin/xrdp-sesman --nodaemon
