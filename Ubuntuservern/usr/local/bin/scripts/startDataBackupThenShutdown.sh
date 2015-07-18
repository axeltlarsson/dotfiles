#!/bin/bash
# Detta script startar dataBackup.sh på Backupservern, när det är klart stänger den av Backupservern
# Initiering av kommandona på Backupservern sker via ssh med hjälp av restrictade nyklar

# Privat nyckelfil
key="/etc/ssh/axel/id_rsa"

# Starta backupen
ssh -i $key root@192.168.0.180 '/home/axel/dataBackup.sh 2> /home/axel/error_log'

# Stäng av Backupservern
echo "Backup klar. Stänger av Backupservern."
ssh -i $key root@192.168.0.180 'shutdown -P now'

exit 0
