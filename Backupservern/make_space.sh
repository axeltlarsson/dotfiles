#!/bin/bash
#
#Currently the script expects this type of file structure:
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
	echo "Disk usage $usage is above $target"
	delete_oldest_dir
	disk_usage "/media/backup"
done
echo "Disk usage $usage is above target $target, this script is done"
exit 0



