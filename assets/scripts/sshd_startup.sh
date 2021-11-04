#!/bin/bash

mkfifo /var/run/nafder/ssh
exec 1>>/var/run/nafder/ssh
exec 2>>/var/run/nafder/ssh

[ -f /etc/sysconfig/sshd ] && . /etc/sysconfig/sshd
prog="sshd"
SSHD=/usr/sbin/sshd
[ -x $SSHD ] || exit 5
[ -f /etc/ssh/sshd_config ] || exit 6
/usr/bin/ssh-keygen -A
echo -n $"Starting $prog: "
exec $SSHD -e -D $OPTIONS

