#!/bin/bash
# Detta script startar dataBackup.sh på Backupservern
# Initiering av kommandot på Backupservern sker via ssh med hjälp av restrictade nyklar

# Privat nyckelfil
key="/etc/ssh/axel/id_rsa"

# Starta backupen
ssh -i $key axel@192.168.0.179 '/home/axel/dataBackup.sh 2> /home/axel/error_log'

if [ $1 ] && [ $1 -eq "shutdown" ]; then
	echo "Backup klar. Stänger av Backupservern."
	ssh -i $key root@192.168.0.179 'shutdown -P now'
fi
exit 0
