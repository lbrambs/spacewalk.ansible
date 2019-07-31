Spacewalk playbooks and roles
==============

License: when using this playbook you are required ro have read and accepted the oracle license agreement due to the usage of an oracle client RPM for the osa-dispatcher: https://github.com/rhessing/spacewalk.ansible/blob/master/roles/spacewalk/files/LICENSE

Changes:
- Updated to Spacewalk version 2.9
- Updated the iptables role
- Admin account is automatically created
- To enable a fully automated installation the password question has been removed.
- Default admin password is admin
- Default company name is Spacewalk
- The default information can be changed in this file: ./roles/spacewalk-customisations/defaults/main.yml
- Added support for Ubuntu 16 & 18
- CentOS 6/7 use the OSAD client
- Ubuntu 16/18 use the OSAD client
- APT repos are signed
- Major bugfixes for Ubuntu systems, OSAD database, etc
- rhn_check cron is used for checking in once every 4 hours (OSAD doesn't do this)
- rhn_check cron has a delay of 0-239 minutes to prevent the spacewalk server to become overloaded
- Removed support for Ubuntu 12 & 14, no one should be using these anymore.. if you are: upgrade to at least 16.04

Spacewalk Server Hardware / Virtual sizing advisement:
- 2 CPU, 4GB of ram minimum (8GB+ recommended), 300GB of disk 



For the lazy people: 
To install both ansible and the spacewalk server:
```
sh <(curl -s https://raw.githubusercontent.com/rhessing/spacewalk.ansible/master/init-server.sh)
```

To install both ansible and the spacewalk proxy:
```
sh <(curl -s https://raw.githubusercontent.com/rhessing/spacewalk.ansible/master/init-proxy.sh)
```

To install both ansible and the spacewalk client:
```
sh <(curl -s https://raw.githubusercontent.com/rhessing/spacewalk.ansible/master/init-client.sh)
```

Install a full Spacewalk server on CentOS 7 and also adds customizations:
- CentOS 6 base+extras+epel+updates repos, channel and activation key 
- CentOS 7 base+extras+epel+updates repos, channel and activation key
- Ubuntu 18.06 base+security repos, channel and activation key (and repo sync scripts)
- Ubuntu 16.06 base+security repos, channel and activation key (and repo sync scripts)

Thanks to geerlingguy's iptables role, which is included here to configure the firewall on the server.

#### To do:
- Fix IPTables role to add a blocking rule at the end




What my inventory (/etc/ansible/hosts) looks like:

```
[spacewalk-server]
spacewalk ansible_ssh_host=XXX.XXX.XXX.XXX

[spacewalk-clients]
Client01 ansible_ssh_host=XXX.XXX.XXX.XXX
Client02 ansible_ssh_host=XXX.XXX.XXX.XXX
```

### How to run:
#### Server:
```
ansible-playbook spacewalk.yml
```

The server initial setup will take a while to run - once this is done it will prompt you if you are ready.
At this point you should browse to the newly installed spacewalk instance in your browser and set up an admin username and password.
The prompt will ask for the password to continue.

#### Client:
```
ansible-playbook spacewalk-clients.yml
```

## Basic trouble shooting

### spacewalk-repo-sync error due to 100% disk usage
When the system has not been sized properly you will run into the error below:
```
rhn]# spacewalk-repo-sync --parent-channel ubuntu-1804 -t deb --verbose
06:55:46 ======================================
06:55:46 | Channel: Ubuntu_1804_security
06:55:46 ======================================
06:55:46 Sync of channel started.
Traceback (most recent call last):
   File "/usr/bin/spacewalk-repo-sync", line 257, in <module>
     sys.exit(abs(main() or 0))
   File "/usr/bin/spacewalk-repo-sync", line 237, in main
     force_all_errata=options.force_all_errata)
   File "/usr/lib/python2.7/site-packages/spacewalk/satellite_tools/reposync.py", line 396, in __init__
     self.checksum_cache = rhnCache.get(checksum_cache_filename)
   File "/usr/lib/python2.7/site-packages/spacewalk/common/rhnCache.py", line 76, in get
     return cache.get(name, modified)
   File "/usr/lib/python2.7/site-packages/spacewalk/common/rhnCache.py", line 403, in get
     return self.cache.get(name, modified)
   File "/usr/lib/python2.7/site-packages/spacewalk/common/rhnCache.py", line 374, in get
     return cPickle.loads(pickled)
EOFError
```

The resolution is to increase the disk size and delete this file before rerunning the spacewalk-repo-sync command again:
/var/cache/rhn/reposync/checksum_cache

### Client apt/yum returning errors
Please double check if the spacewalk-repo-sync command finishes without errors. Special note for debian/ubuntu clients: infinite updates are noticeble on the client command line. When using spacewalk to manage the system updates please do not manually update on the CLI as this will trigger updates which have already been done. This is a known bug with no proper fix available. The issue is within the apt spacewalk transport files and package architecture information which is normally supplied by the repo meta data but spacewalk does not include this. This bug is for all Debian based systems.

Is it an issue? Well no but it is confusing, spacewalk will correctly update the packages but for the client it looks like the packages aren't updated (if you check with apt). Verify with other means (logs, dpkg) to see that the packages are indeed updated. It seems that Ubuntu 18.04 isn't affected, 16.04 is.
