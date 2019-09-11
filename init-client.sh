#!/bin/sh

# Only run if root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

if [ "$1" = "-v" ]; then
  ANSIBLE_VERSION="${2}"
fi

yum_makecache_retry() {
  tries=0
  until [ $tries -ge 5 ]
  do
    yum makecache && break
    let tries++
    sleep 1
  done
}

wait_for_cloud_init() {
  while pgrep -f "/usr/bin/python /usr/bin/cloud-init" >/dev/null 2>&1; do
    echo "Waiting for cloud-init to complete"
    sleep 1
  done
}

dpkg_check_lock() {
  while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
    echo "Waiting for dpkg lock release"
    sleep 1
  done
}

apt_install() {
  dpkg_check_lock && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    -o DPkg::Options::=--force-confold -o DPkg::Options::=--force-confdef "$@"
}

if [ "x$KITCHEN_LOG" = "xDEBUG" ] || [ "x$OMNIBUS_ANSIBLE_LOG" = "xDEBUG" ]; then
  export PS4='(${BASH_SOURCE}:${LINENO}): - [${SHLVL},${BASH_SUBSHELL},$?] $ '
  set -x
fi

if [ ! "$(which ansible-playbook)" ]; then
  if [ -f /etc/centos-release ] || [ -f /etc/redhat-release ]; then

    # Install required Python libs and pip
    # Fix EPEL Metalink SSL error
    # - workaround: https://community.hpcloud.com/article/centos-63-instance-giving-cannot-retrieve-metalink-repository-epel-error
    # - SSL secure solution: Update ca-certs!!
    #   - http://stackoverflow.com/q/26734777/645491#27667111
    #   - http://serverfault.com/q/637549/77156
    #   - http://unix.stackexchange.com/a/163368/7688
    yum -y install ca-certificates nss
    yum clean all
    rm -rf /var/cache/yum
    yum_makecache_retry
    yum -y install epel-release
    # One more time with EPEL to avoid failures
    yum_makecache_retry

    yum -y install python-pip PyYAML python-jinja2 python-httplib2 python-keyczar python-paramiko git
    # If python-pip install failed and setuptools exists, try that
    if [ -z "$(which pip)" ] && [ -z "$(which easy_install)" ]; then
      yum -y install python-setuptools
      easy_install pip
    elif [ -z "$(which pip)" ] && [ -n "$(which easy_install)" ]; then
      easy_install pip
    fi

    # Upgrade pip
    pip install --upgrade pip

    # Install passlib for encrypt
    yum -y groupinstall "Development tools"
    yum -y install python-devel MySQL-python sshpass libffi-devel openssl-devel && pip install pyrax pysphere boto passlib dnspython

    # Install Ansible module dependencies
    yum -y install bzip2 file findutils git gzip hg svn sudo tar which unzip xz zip libselinux-python
    [ -n "$(yum search procps-ng)" ] && yum -y install procps-ng || yum -y install procps

  elif [ -f /etc/fedora-release ]; then
    echo
    echo "!! Warning !!"
    echo "For this spacewalk server installation fedora is expiremental and untested!"
    echo "!! Warning !!"
    echo

    # Install required Python libs and pip
    dnf -y install gcc libffi-devel openssl-devel python-devel

    # If python-pip install failed and setuptools exists, try that
    if [ -z "$(which pip)" ] && [ -z "$(which easy_install)" ]; then
      dng -y install python-setuptools
      easy_install pip
    elif [ -z "$(which pip)" ] && [ -n "$(which easy_install)" ]; then
      easy_install pip
    fi

  else
    echo 'FATAL: Distro unsupported!'
    exit 1;
  fi

  pip install -q six --upgrade
  mkdir -p /etc/ansible/
  if [ -z "$ANSIBLE_VERSION" ]; then
    pip install -q ansible
  else
    pip install -q ansible=="$ANSIBLE_VERSION"
  fi
  if [ -f /etc/centos-release ] || [ -f /etc/redhat-release ]; then
    # Fix for pycrypto pip / yum issue
    # https://github.com/ansible/ansible/issues/276
    if  ansible --version 2>&1  | grep -q "AttributeError: 'module' object has no attribute 'HAVE_DECL_MPZ_POWM_SEC'" ; then
      echo 'WARN: Re-installing python-crypto package to workaround ansible/ansible#276'
      echo 'WARN: https://github.com/ansible/ansible/issues/276'
      pip uninstall -y pycrypto
      yum erase -y python-crypto
      yum install -y python-crypto python-paramiko
    fi
    # Fix for urllib3 issue
    pip uninstall -y urllib3 requests
    yum erase -y python-urllib3
    pip install -y urllib3 requests
  fi

fi

# Install ansible local run file
printf "[spacewalk-client]\nlocalhost ansible_connection=local" > /etc/ansible/hosts

# Run ansible
ANSIBLE=$(which ansible-pull)
REPO="https://github.com/rhessing/spacewalk.ansible.git"
ANSIBLE_OPTS="--clean --full spacewalk-client.yml"
${ANSIBLE} -U ${REPO} ${ANSIBLE_OPTS}
