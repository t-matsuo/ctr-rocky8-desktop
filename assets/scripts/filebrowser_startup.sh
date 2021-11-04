#!/bin/bash

mkfifo /var/run/nafder/filebrowser
exec 1>>/var/run/nafder/filebrowser
exec 2>>/var/run/nafder/filebrowser

exec filebrowser -r /root -a 127.0.0.1 -p 57576 -d /var/lib/filebrowser/filebrowser.db -b /file --noauth
