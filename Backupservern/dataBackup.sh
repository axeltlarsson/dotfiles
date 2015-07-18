#!/bin/bash

# /home/axel/dataBacup.sh
# Axels inkrementella backupscript
# Anslutningen sker via ssh med hjälp en "private ssh-key"
# och flera "public ssh-keys" som finns på serversidan.
# Dessa publika nycklar bör begränsas till att endast utföra 
# dessa specifika rsync-kommandon. Använd t.ex:
# command="rsync --server --sender -logDtpre.iLs --append . /media/data/public/",from="192.168.0.179",no-pty,no-agent-forwarding,no-port-forwarding 
# Av: Axel Larsson

./make_space.sh

# Variabler för destination, datum och prevBackupDir
dest="/media/backup"
datum=`date +%Y-%m-%d_%H:%M`
host="192.168.0.199"	# Ubuntuservern
privateKey="/home/axel/.ssh/id_rsa"
privateKeyForPublic="/home/axel/.ssh/public_id"
prevDirs=`find $dest -maxdepth 1 -type d | awk '{if(/20/){print "--link-dest=" $0 "'$1'"}}'`

# Does backup of Ubuntuserver with:
# $1: user
# $2: path (ie /private/Axel/)
# $3: ssh key
backup() {
	local user=$1
	local path=$2
	local key=$3
	mkdir -p $dest/"$datum"/$path
	local args="-a --delete --append"
	echo "Backing up $path"
	rsync -a --delete --append $prevDirs --rsh="ssh -i $key -q -p512 -l $user" $host:/media/data/$path $dest/"$datum"/$path
}


# Backup av Axels privata mapp
#user='axel'
#prevBackupDirs=$(prevBackupDirs '/private/Axel/')
#mkdir -p $dest/"$datum"/private/Axel
#rsync -a --delete --append $prevBackupDirs --rsh="ssh -i $privateKey -q -p512 -l $user" $host:/media/data/private/Axel/ $dest/"$datum"/private/Axel/

backup axel /private/axel $privateKey

exit 0

# Backup av Staffans privata mapp
user='staffan'
prevBackupDirs=$(prevBackupDirs '/private/Staffan/')
mkdir -p $dest/"$datum"/private/Staffan
rsync -a --delete --append $prevBackupDirs --rsh="ssh -i $privateKey -q -p512 -l $user" $host:/media/data/private/Staffan/ $dest/"$datum"/private/Staffan/

# Backup av Carinas privata mapp
user='carina'
prevBackupDirs=$(prevBackupDirs '/private/Carina/')
mkdir -p $dest/"$datum"/private/Carina
rsync -a --delete --append $prevBackupDirs --rsh="ssh -i $privateKey -q -p512 -l $user" $host:/media/data/private/Carina/ $dest/"$datum"/private/Carina/

# Backup av Annas privata mapp
user='anna'
prevBackupDirs=$(prevBackupDirs '/private/Anna/')
mkdir -p $dest/"$datum"/private/Anna
rsync -a --delete --append $prevBackupDirs --rsh="ssh -i $privateKey -q -p512 -l $user" $host:/media/data/private/Anna/ $dest/"$datum"/private/Anna/


# Backup av Ulfs privata mapp
user='ulf'
prevBackupDirs=$(prevBackupDirs '/private/Ulf/')
mkdir -p $dest/"$datum"/private/Ulf
rsync -a --delete --append $prevBackupDirs --rsh="ssh -i $privateKey -q -p512 -l $user" $host:/media/data/private/Ulf/ $dest/"$datum"/private/Ulf/

# Backup av Public
user="axel"
prevBackupDirs=$(prevBackupDirs '/public/')
mkdir -p $dest/"$datum"/public
rsync -a --delete --append $prevBackupDirs --rsh="ssh -i $privateKeyForPublic -q -p512 -l $user" $host:/media/data/public/ $dest/"$datum"/public/
exit

