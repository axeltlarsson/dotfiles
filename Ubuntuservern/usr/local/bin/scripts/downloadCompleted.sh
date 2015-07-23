#!/bin/bash
# Detta skript anropas av debian-transmission när transmission har laddat ner en ny torrent.
# Skriptet är bara en wrapper som i sin tur anropar torrent_extracter och notifyAxel.sh med rätt argument.

usage()
{
cat << EOF
usage: $0 [<path to the torrent downloaded>]

Takes either an argument as the path to the torrent downloaded or uses
the environment variables "\$TR_TORRENT_DIR" and "\$TR_TORRENT_NAME" to
build the path from that instead. If no argument is provided and either
"\$TR_TORRENT_DIR" or "\$TR_TORRENT_NAME" is not set, the script will exit.

EOF
}

while getopts "h" OPTION
do
	case $OPTION in
		h)
			usage
			exit 1
			;;

	esac
done

if  [[ -z $1 ]] && ([[ -z $TR_TORRENT_DIR ]] || [[ -z $TR_TORRENT_NAME ]])
then
	usage
	exit 1
fi

if [[ -z $1 ]]
then
	torrent="$TR_TORRENT_DIR/$TR_TORRENT_NAME"
else
	torrent=$1
fi
/usr/local/bin/scripts/notifyAxel.sh
/usr/local/bin/torrent_extracter -l /var/log/torrent_extracter/torrent_extracter.log -f /media/data/public/Filmer/ -t /media/data/public/Serier/ "$torrent" 2>> /var/log/torrent_extracter/torrent_extracter.log
