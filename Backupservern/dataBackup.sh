#!/bin/bash

# /home/axel/dataBacup.sh
# Axels inkrementella backupscript
# Anslutningen sker via ssh med hjälp en "private ssh-key"
# och flera "public ssh-keys" som finns på serversidan.
# Dessa publika nycklar bör begränsas till att endast utföra 
# dessa specifika rsync-kommandon. Använd t.ex:
# command="rsync --server --sender -logDtpre.iLs --append . /media/data/public/",from="192.168.0.179",no-pty,no-agent-forwarding,no-port-forwarding 
# Av: Axel Larsson

# Currently the script expects this type of file structure:
# ├── 2015-06-15_11:34
# │   ├── private
# │   └── public
# ├── 2015-06-15_23:44
# │   ├── private
# │   └── public
# ├── 2015-07_14_13:22
# │   ├── private
# │   └── public
# └── 2015-07-15_21:13
#     ├── private
#     └── public

#---------------------------------------- Making space ----------------------------------------------
# Stores the disk usage in $usage, given file path as $1
# Note: $1 should be a real folder path where a disk is mounted
# such as /media/backup and NOT /dev/sda3
disk_usage() {
	local free_blocks=$(stat -f --format="%a" $1)
	local total_blocks=$(stat -f --format="%b" $1)
	usage=$(bc -l <<< "1 - $free_blocks / $total_blocks")
}

# Deletes the oldest dir, or rather the oldest according to the name of the dirs
# in the dir as hardcoded here in the find expression
delete_oldest_dir() {
	# modified from http://unix.stackexchange.com/questions/28939/how-to-delete-the-oldest-directory-in-a-given-directory
	IFS= read -r -d $'\0' file < <(find /media/backup -maxdepth 1 ! -path /media/backup  -type d -printf '%p\0' | sort -z)
	echo "Deleting $file"
	rm -rf "$file"
}

target=0.86
disk_usage "/media/backup"
while [ $(echo $usage'>'$target | bc -l) == 1 ]; do
	echo "Disk usage $usage > $target =>"
	delete_oldest_dir
	disk_usage "/media/backup"
done
echo "Disk usage $usage < $target => OK"

#---------------------------------------- Doing the backup ------------------------------------------
dest="/media/backup"
datum=`date +%Y-%m-%d_%H:%M`
host="192.168.0.199"	# Ubuntuservern
privateKey="/home/axel/.ssh/id_rsa"
privateKeyForPublic="/home/axel/.ssh/public_id"


# Returnerar rad med alla föregående backupmappar som --link-dest argument, med $1 som suffix
prevBackupDirs() {
	echo `find $dest -maxdepth 1 -type d | awk '{if(/20/){print "--link-dest=" $0 "'$1'"}}'`
}

# Does backup of Ubuntuserver with:
# $1: user
# $2: path (ie /private/Axel/)
# $3: ssh key
backup() {
	local user=$1
	local path=$2
	local key=$3
	mkdir -p $dest/"$datum"/$path
	echo "Backing up $path..."
	prevDirs=$(prevBackupDirs $path)
	rsync -a --delete --append $prevDirs --rsh="ssh -i $key -q -p512 -l $user" $host:/media/data/$path $dest/"$datum"/$path
}

backup axel /private/Axel $privateKey
backup anna /private/Anna $privateKey
backup ulf /private/Ulf $privateKey
backup staffan /private/Staffan $privateKey
backup carina /private/Carina $privateKey
backup axel /public $privateKeyForPublic

exit 0
