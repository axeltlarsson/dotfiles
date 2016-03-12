#!/bin/bash
# Script för att backa upp viktiga filer och mappar på servern.
#
# Changelog:
#	- 2015-07-18 -> tog bort backup av /home (dumt säkerhetsmässigt + klydd med perms)
#			refaktoriserade scriptet
#	- 2012-10-31 -> la till backup av /var/www, fixade perms
#
# Axel Larsson 2012-01-07


# Kolla att scriptet körs som root
if [[ $EUID -ne 0 ]]; then
   echo "Detta script måste köras som root" 1>&2
   exit 1
fi

backup_dir="/media/data/public/Backup/Ubuntuservern"

# $1: source
backup() {
  echo "Backar upp $1..."
  local args="-az --perms --delete --relative"
  rsync $args $1 $backup_dir
}

dirs=(/etc/samba/smb.conf /etc/fstab /etc/ssh/sshd_config /var/spool/cron/crontabs \
/etc/cron.hourly /var/www /etc/profile.d/axels_paths.sh /usr/local/src /usr/local/bin /etc/letsencrypt)

for dir in ${dirs[*]}
do
  backup $dir
done
chown -R axel $backup_dir
chgrp -R root $backup_dir
chmod -R o= $backup_dir

exit 0
