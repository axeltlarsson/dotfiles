#!/bin/sh
# Detta skript flyttar alla .NEF-filer i mappen som angavs som parameter till en mapp RAW
# i denna mapp. RAW-mappen skapas om den inte redan existerar.
#
# @date 2014-03-02
# @author mail@axellarsson.nu

# Check that we have the correct number of arguments
die () {
    echo >&2 "$@"
    exit 1
}

[ "$#" -eq 1 ] || die "This script takes one argument, a file path, you provied  $# arguments..."

DIR=$1
DIR_ABSOLUTE=$(readlink -f "$DIR")
cd "$DIR_ABSOLUTE"

# Exit if failed to cd to directory
if [ "$PWD" != "$DIR_ABSOLUTE" ]; then
	echo "Exiting because we could not cd to where we wanted."
	exit
fi

# Make a new dir RAW
mkdir -p RAW

# Move the .NEF files into the new RAW directory
find ./ -maxdepth 1 -iname "*.NEF"  -not -path "./RAW/*" -exec mv -v '{}' RAW/ \;

# If we created a new RAW directory, but no files were moved into it; delete it
if [ "$(ls -A "$DIR_ABSOLUTE/RAW")" ]; then
	echo "" > /dev/null
else
	rmdir "$DIR_ABSOLUTE/RAW"
fi
