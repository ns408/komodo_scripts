#!/usr/bin/env bash
# Tested on Ubuntu 16.04 LTS
set -e

if [[ $EUID -eq 0 ]]; then
   echo -e "This script needs to run as a non-root user with sudo privileges\n"
   exit 1
fi

# source profile and setup variables using "${HOME}/.common/config"
source /etc/profile
[[ -f "${HOME}/.common/config" ]] && source "${HOME}/.common/config"

# Functions
# Capture real time taken
function time_taken() {
  /usr/bin/time -f "## Time taken=%e\n" "$@"
}

# Variables
SCRIPTNAME=$(realpath $0)
SCRIPTPATH=$(dirname $SCRIPTNAME)
VAR_THING=komodo

[[ -z ${VAR_NPROC+x} ]] && VAR_NPROC="$(cat /proc/cpuinfo | grep processor | wc -l)"
[[ -z ${VAR_USERNAME+x} ]] && VAR_USERNAME="${USER}"
[[ -z ${VAR_BRANCH+x} ]] && VAR_BRANCH='dev'
[[ -z ${VAR_REPO+x} ]] && VAR_REPO='https://github.com/jl777/komodo.git'
[[ -z ${VAR_SRC_DIR+x} ]] && VAR_SRC_DIR="${HOME}/${VAR_THING}"
[[ -z ${VAR_CONF_DIR+x} ]] && VAR_CONF_DIR="${HOME}/.${VAR_THING}"
[[ -z ${VAR_CONF_FILE+x} ]] && VAR_CONF_FILE="${VAR_CONF_DIR}/conf/${VAR_THING}.conf"
[[ -z ${VAR_RPCPORT+x} ]] && VAR_RPCPORT="7771"
[[ -z ${VAR_BLOCKCHAIN_ARCHIVE+x} ]] && VAR_BLOCKCHAIN_ARCHIVE="komodo_blockchain_backup.tar.gz"

# Create random password for conf if needed
if [[ ! -f ${VAR_CONF_FILE} ]]; then
  RPCUSER=$(date +%s | sha256sum | base64 | head -c 32 ; echo)
  RPCPASSWORD=$(date +%s | sha256sum | base64 | head -c 32 ; echo)
else
  RPCUSER=$(grep 'rpcuser' ${VAR_CONF_FILE} | cut -d'=' -f2)
  RPCPASSWORD=$(grep 'rpcpassword' ${VAR_CONF_FILE} | cut -d'=' -f2)
fi

echo -e "## ${VAR_THING} setup starting ##\n"

# Install requisites:
sudo -s bash <<EOF
export DEBIAN_FRONTEND=noninteractive;
apt-get -y -qq update
apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -qq \
  install build-essential pkg-config libc6-dev m4 g++-multilib autoconf libtool \
  ncurses-dev zlib1g-dev bsdmainutils automake libboost-all-dev libssl-dev \
  libprotobuf-dev protobuf-compiler libqt4-dev libqrencode-dev libdb++-dev \
  software-properties-common libcurl4-gnutls-dev cmake clang libgmp3-dev \
  libsodium-dev
EOF

# Create directories
[[ -d ${VAR_CONF_DIR} ]] || mkdir ${VAR_CONF_DIR}
[[ -d ${VAR_CONF_DIR}/conf ]] || mkdir ${VAR_CONF_DIR}/conf
[[ -d ${VAR_CONF_DIR}/log ]] || mkdir ${VAR_CONF_DIR}/log
[[ -d ${VAR_CONF_DIR}/bin ]] || mkdir ${VAR_CONF_DIR}/bin
[[ -d ${HOME}/.build_source ]] || mkdir ${HOME}/.build_source

#### Create conf only if it doesn't exist before
[[ -f "${VAR_CONF_FILE}" ]] || \
  cat > "${VAR_CONF_FILE}" << EOF
rpcuser=${RPCUSER}
rpcpassword=${RPCPASSWORD}
rpcport=${VAR_RPCPORT}
txindex=1
#bind=127.0.0.1
rpcbind=127.0.0.1
rpcallowip=127.0.0.1
addnode=78.47.196.146

maxconnections=16
EOF
echo -e "Created configuration file\n"

# Create a hard-link for conf file for backward compatibility
[[ -f ${VAR_CONF_DIR}/${VAR_THING}.conf ]] || ln ${VAR_CONF_FILE} ${VAR_CONF_DIR}/

#### Use blockchain backup from somewhere
if [[ ! -z ${VAR_BLOCKCHAIN_DOWNLOAD+x} ]]; then
  echo -e "## Downloading ${VAR_BLOCKCHAIN_ARCHIVE} in the background ##\n"
  cd ${VAR_CONF_DIR}
  wget -c ${VAR_BLOCKCHAIN_DOWNLOAD} \
    -O ${VAR_BLOCKCHAIN_ARCHIVE}

  if ! [[ -d blocks && -d chainstate ]]; then
    pigz -dc ${VAR_BLOCKCHAIN_ARCHIVE} | tar xf -
  fi
fi &

if [[ ${DONT_BUILD} != true ]]; then

  #### Install nanomsg
  sudo chown $(whoami). /usr/local/src
  cd /usr/local/src
  if [[ -d nanomsg ]]; then
    cd nanomsg
    git reset --hard; git pull --rebase
  else
    git clone https://github.com/nanomsg/nanomsg
    cd nanomsg
  fi
  time_taken cmake . -DNN_TESTS=OFF -DNN_ENABLE_DOC=OFF
  time_taken make
  time_taken sudo make install
  time_taken sudo ldconfig

  ### Checkout the sourcecode
  if [[ -d ${VAR_SRC_DIR} ]]; then

    echo -e "## ${VAR_THING} source directory already exists, building in *.build/${VAR_THING}* ##\n"
    cd ${VAR_SRC_DIR}/.. >& /dev/null

    if [[ -d .build_source/${VAR_THING} ]]; then
      cd .build_source/${VAR_THING}
      git checkout ${VAR_BRANCH}
      git reset --hard
      git pull --rebase
    else
      cd .build_source
      git clone ${VAR_REPO} -b ${VAR_BRANCH} ${VAR_THING}
      cd ${VAR_THING}
    fi
    # Copy the pubkey from old source
    cp -vf ${VAR_SRC_DIR}/src/pubkey.txt ${HOME}/.build_source/${VAR_THING}/src/

  else
    cd ${HOME}
    git clone ${VAR_REPO} -b ${VAR_BRANCH}
    cd ${VAR_SRC_DIR}
  fi

  echo -e "===> Build ${VAR_THING}"
  time_taken ./zcutil/fetch-params.sh
  time_taken ./zcutil/build.sh -j${VAR_NPROC}
  echo -e "===> Finished building ${VAR_THING}"

fi

# Setup control scripts
sed -e "s|<VAR_RPCPORT>|${VAR_RPCPORT}|g" \
  -e "s|<VAR_SRC_DIR>|${VAR_SRC_DIR}|g" \
  -e "s|<VAR_NPROC>|${VAR_NPROC}|g" \
  -e "s|<VAR_USERNAME>|${VAR_USERNAME}|g" \
  -e "s|<VAR_CONF_FILE>|${VAR_CONF_FILE}|g" \
  -e "s|<VAR_CONF_DIR>|${VAR_CONF_DIR}|g" \
  "${SCRIPTPATH}/.${VAR_THING}/bin/start.sh" > "${VAR_CONF_DIR}/bin/start.sh"

sed -e "s|<VAR_USERNAME>|${VAR_USERNAME}|g" \
  -e "s|<VAR_SRC_DIR>|${VAR_SRC_DIR}|g" \
  -e "s|<VAR_CONF_FILE>|${VAR_CONF_FILE}|g" \
  -e "s|<VAR_CONF_DIR>|${VAR_CONF_DIR}|g" \
  -e "s|<VAR_THING>|${VAR_THING}|g" \
  "${SCRIPTPATH}/.${VAR_THING}/bin/stop.sh" > "${VAR_CONF_DIR}/bin/stop.sh"

sed -e "s|<VAR_CONF_FILE>|${VAR_CONF_FILE}|g" \
  "${SCRIPTPATH}/.${VAR_THING}/bin/healthcheck.sh" > "${VAR_CONF_DIR}/bin/healthcheck.sh"

sed -e "s|<VAR_SRC_DIR>|${VAR_SRC_DIR}|g" \
  "${SCRIPTPATH}/.${VAR_THING}/bin/status.sh" > "${VAR_CONF_DIR}/bin/status.sh"

# Symlink binaries
sudo ln -sf ${VAR_SRC_DIR}/src/${VAR_THING}-cli /usr/local/bin/
sudo ln -sf ${VAR_SRC_DIR}/src/${VAR_THING}d /usr/local/bin/
sudo chmod +x /usr/local/bin/${VAR_THING}-cli
sudo chmod +x /usr/local/bin/${VAR_THING}d

# Permissions and ownership
chmod +x ${VAR_CONF_DIR}/bin/*
chmod 660 ${VAR_CONF_DIR}/conf/*.conf

echo -e "## ${VAR_THING} has been configured ##\n"

# Create monit template
cat > ${HOME}/.${VAR_THING}/monitd_${VAR_THING}.template <<EOF
check program ${VAR_THING}d_healthcheck.sh with path "${HOME}/.${VAR_THING}/bin/healthcheck.sh"
  as uid ${USER} and gid ${USER}
  with timeout 60 seconds
if status != 0 then exec "/usr/local/bin/sudo_wrapper ${HOME}/.${VAR_THING}/bin/start.sh"
  as uid ${USER} and gid ${USER}
  repeat every 2 cycles
EOF

# Copy monit configuration
sudo mv ${HOME}/.${VAR_THING}/monitd_${VAR_THING}.template /etc/monit/conf.d/monitd_${VAR_THING}
