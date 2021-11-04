#!/bin/bash

mkfifo /var/run/nafder/nginx
exec 1>>/var/run/nafder/nginx
exec 2>>/var/run/nafder/nginx

exec /usr/sbin/nginx -g "daemon off;" 
