#!/usr/bin/env bash
# Setup global configuration for notary node setup
# Should only be called from userdata.sh
set -e

COMMON_ROOT="${HOME}/.common"
COMMON_CONFIG="${COMMON_ROOT}/config"

[[ -d ${COMMON_ROOT} ]] || mkdir ${COMMON_ROOT}
[[ -f ${COMMON_CONFIG} ]] || touch ${COMMON_CONFIG}

function verifyvalue() {
  VARNAME=${1}
  VARVALUE=${2}
  if [[ ! -z ${VARVALUE+x} ]]; then
    if grep -q "${VARVALUE}" ${COMMON_CONFIG}; then
      if [[ ! -z ${OVERWRITE_COMMON_CONFIG+x} ]]; then
        sed -i "s|^${VARNAME}=.*$|${VARNAME}=${VARVALUE}|" ${COMMON_CONFIG}
      fi
    else
      echo "${VARNAME}=${VARVALUE}" >> ${COMMON_CONFIG}
    fi
  fi
}

verifyvalue USERNAME ${USER}
verifyvalue EXTERNALIP ${EXTERNALIP}
# verifyvalue SLACK_CHANNEL xxxxxxxxx
# verifyvalue SLACK_USERNAME 'jalim-chucha'
# verifyvalue SLACK_URL xxxxxxxxx
# verifyvalue SLACK_EMOJI ':chicken:'

# verifyvalue BTC_NOTARISATION_ADDRESS xxxxxxxxx
# verifyvalue KMD_NOTARISATION_ADDRESS xxxxxxxxx

verifyvalue KOMODO_BRANCH ${KOMODO_BRANCH}
verifyvalue KOMODO_REPOSITORY ${KOMODO_REPOSITORY}
verifyvalue KOMODO_SRC_DIR ${KOMODO_SRC_DIR}
verifyvalue KOMODO_RPCPORT 7771

verifyvalue BITCOIND_BRANCH ${BITCOIND_BRANCH}
verifyvalue BITCOIND_REPOSITORY ${BITCOIND_REPOSITORY}
verifyvalue BITCOIND_SRC_DIR ${BITCOIND_SRC_DIR}
verifyvalue BITCOIND_RPCPORT 8332

verifyvalue IGUANA_BRANCH ${IGUANA_BRANCH}
verifyvalue IGUANA_REPOSITORY ${IGUANA_REPOSITORY}
verifyvalue IGUANA_SRC_DIR ${IGUANA_SRC_DIR}
verifyvalue IGUANA_RPCPORT 7778

verifyvalue CHIPS_BRANCH ${CHIPS_BRANCH}
verifyvalue CHIPS_REPOSITORY ${CHIPS_REPOSITORY}
verifyvalue CHIPS_SRC_DIR ${CHIPS_SRC_DIR}