#!/bin/bash
# Script för att backa upp viktiga filer och mappar på min desktop som ej passar
# sig att ha i ett git-repo
#
# Axel Larsson 2014-08-10
#
# Changelog:
# * 2016-01-04 Remove unnecessary backup targets that are symlinked anyway
#
#

# Set up
DATE=`date +"%Y-%m-%d %H.%M.%S"`
backupDir="/media/axel/Backup/Backup_$DATE"
mkdir -p "$backupDir"
arguments="-az --perms --delete --relative"

# Text color
NORMAL=$(tput sgr0)
GREEN=$(tput setaf 2)

#	This function overwrites last output line if the previous command was succesfull with "$1 [OK]"
#	@parameter $1 - paramenter to display if previous command is succesfull
function resultMessage {
	if [ $? -eq 0 ]; then
		#echo -en "\e[1A"; echo -e "\e[0K\r$1 $GREEN [OK] $NORMAL"
		printf '%s%*s%s' "$GREEN" 80 "[OK]" "$NORMAL"
	fi
}


echo "Backar upp till \"$backupDir\""

echo "Backar upp fstab..."
rsync $arguments /etc/fstab "$backupDir"
resultMessage "Backar upp fstab..."

echo "Backar upp /home/axel/.ssh..."
rsync $arguments /home/axel/.ssh "$backupDir"
resultMessage "Backar upp /home/axel/.ssh..."

echo "Backar upp /etc/ssh..."
rsync $arguments /etc/ssh "$backupDir"
resultMessage "Backar upp /etc/ssh..."


echo "Backup klar!"
