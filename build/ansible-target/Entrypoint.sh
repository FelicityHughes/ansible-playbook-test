#!/usr/bin/env bash

set -eo pipefail

for file in $(echo "${CREATE_FILES}" | tr "," "\n"); do
  touch "${file}"
done

# Enable rsyslog daemon so that SSHD log file is created
rsyslogd

# Start SSH daemon
/usr/sbin/sshd -D

