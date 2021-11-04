#!/bin/bash

mkfifo /var/run/nafder/code
exec 1>>/var/run/nafder/code
exec 2>>/var/run/nafder/code

cleanup () {
    pkill /usr/lib/code-server/lib/node
}
trap cleanup SIGINT SIGTERM

unset PORT
unset PASSWORD
exec /usr/bin/code-server --verbose --bind-addr 127.0.0.1:8055 --disable-telemetry $CODE_OPTS
