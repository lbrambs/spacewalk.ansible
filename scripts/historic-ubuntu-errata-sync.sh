#!/bin/bash

# Import all historic Ubuntu errata's

YEAR=2004 # Set starting year
MONTH=10 # Set starting month

CURR_YEAR=`date +"%Y"`
CURR_MONTH=`date +"%-m"`

echo "Parsing historic Errata's"

until [[ ( ${YEAR} -eq ${CURR_YEAR} && ${MONTH} -eq ${CURR_MONTH} ) ]]
do

  DATE=$(date --date="$(printf '%s-%s-20' ${YEAR} ${MONTH})" +"%Y-%B")


  #make sure we have english locale
  export LC_TIME="en_US.utf8"
  # Obtains the current date and year.

  # Test if the latest monthly errata is there
  STATUS_CODE=$(curl -I -s -w '%{http_code}\n' https://lists.ubuntu.com/archives/ubuntu-security-announce/$DATE.txt.gz | tail -n1)
  if [ ${STATUS_CODE} -ne 200 ]; then
        echo "No errata available for ${DATE}.."
  else

	echo " - for ${DATE}"

	echo "   - Preparing environment"
  	mkdir -p /opt/spacewalk-ubuntu-errata/errata
  	rm -rf /opt/spacewalk-ubuntu-errata/errata/$DATE.txt
  	rm -rf /opt/spacewalk-ubuntu-errata/errata/ubuntu-errata.xml

	echo "   - Downloading errata file"
  	curl -s https://lists.ubuntu.com/archives/ubuntu-security-announce/$DATE.txt.gz > /opt/spacewalk-ubuntu-errata/errata/$DATE.txt.gz

	echo "   - Extracting errata file"
  	gunzip -f /opt/spacewalk-ubuntu-errata/errata/$DATE.txt.gz

	echo "   - Parsing errata file"
  	cd /opt/spacewalk-ubuntu-errata/
  	/usr/sbin/parseUbuntu.py errata/$DATE.txt

	echo "   - Importing errata file"
  	/usr/sbin/errata-import.py 2>&1 | tee -a /var/log/ubuntu-errata.log

	echo "   - Cleaning up"
	cd /tmp
	rm -rf /opt/spacewalk-ubuntu-errata

	echo -e "   - Completed\n"
	
  fi

  if [ $MONTH -eq 12 ]; then
	MONTH=1
  	YEAR=$((YEAR + 1))
  else
	MONTH=$((MONTH + 1))
  fi

done
