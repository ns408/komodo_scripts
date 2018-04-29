#!/usr/bin/env bash
set -e

if ! $( lsof -Pi :<VAR_RPCPORT> -sTCP:LISTEN -t > /dev/null); then
  while [[ $# -gt 0 ]]; do
  	key="$1"
  	case $key in
  		-h|--help)
  		cat >&2 <<HELP
Usage: start.sh [OPTIONS]
Start komodod
-h --help                         Show this help
--notary-node                     Start as notary node
-gen                              Mine coins
HELP
      exit 0
      ;;
      --notary-node)
        if [[ -f "<VAR_SRC_DIR>/src/pubkey.txt" ]]; then
          btcpubkey=$(cat "<VAR_SRC_DIR>/src/pubkey.txt" | cut -d'=' -f2)
          NOTARY_PARAMS="-notary -pubkey=${btcpubkey}"
        fi
      ;;
      -gen)
        GEN_PARAMS="-gen -genproclimit=<VAR_NPROC>"
      ;;
    esac
    shift
  done

  echo -e "Start komodod\n"
  sudo -H -u <VAR_USERNAME> /bin/bash -c \
    "<VAR_SRC_DIR>/src/komodod -conf=<VAR_CONF_FILE> \
    ${NOTARY_PARAMS} ${GEN_PARAMS} &>> <VAR_CONF_DIR>/log/komodod.log"
fi