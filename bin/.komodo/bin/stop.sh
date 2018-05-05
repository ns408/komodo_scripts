#!/usr/bin/env bash
set -e

# source profile and setup variables using "${HOME}/.common/config"
source /etc/profile
[[ -f "${HOME}/.common/config" ]] && source "${HOME}/.common/config"

echo -e "## Stop komodo daemon ##\n"
sudo -H -u <VAR_USERNAME> /bin/bash -c \
  "<VAR_SRC_DIR>/src/komodo-cli -conf=<VAR_CONF_FILE> stop"

while inotifywait -e modify -t 60 <VAR_CONF_DIR>/debug.log; do
  if tail -n10 <VAR_CONF_DIR>/debug.log | grep 'Shutdown: done'; then
    echo -e "## komodo daemon has been shutdown ##\n"
    break
  fi
done
