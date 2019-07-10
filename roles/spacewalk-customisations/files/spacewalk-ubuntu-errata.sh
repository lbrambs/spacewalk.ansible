#!/bin/bash

# Processes Ubuntu Errata and imports them to Spacewalk

#make sure we have english locale
export LC_TIME="en_US.utf8"
# Obtains the current date and year.
DATE=`date +"%Y-%B"`

mkdir -p /opt/spacewalk-ubuntu-errata/errata

# Fetches the errata data from ubuntu.com.
rm -rf /opt/spacewalk-ubuntu-errata/errata/$DATE.txt
rm -rf /opt/spacewalk-ubuntu-errata/errata/ubuntu-errata.xml
curl https://lists.ubuntu.com/archives/ubuntu-security-announce/$DATE.txt.gz > /opt/spacewalk-ubuntu-errata/errata/$DATE.txt.gz
gunzip -f /opt/spacewalk-ubuntu-errata/errata/$DATE.txt.gz
# Processes and imports the errata.
cd /opt/spacewalk-ubuntu-errata/ && \
/usr/sbin/parseUbuntu.py errata/$DATE.txt
/usr/sbin/errata-import.py 2>&1 | tee -a /var/log/ubuntu-errata.log

rm -rf /opt/spacewalk-ubuntu-errata