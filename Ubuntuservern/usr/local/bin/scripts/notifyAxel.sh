#!/bin/bash
# Kolla så att debian-transmission kör detta skript (andra användare blir nekade SSH-nyckeln som autentisering)
if (( EUID != 105 )); then
   echo "You must be debian-transmission to utilise the SSH key succesfully: the script will now exit." 1>&2
   exit 100
fi

# Privat nyckelfil
key="/etc/ssh/debian-transmission/id_rsa"
# Anslut till Axel-PC med privat rsa-nyckel och visa en desktop-notifikation
notifySendCommand='notify-send ""$TR_TORRENT_NAME" är klar" ""$TR_TORRENT_NAME" laddades ner till "$TR_TORRENT_DIR""'
# User-independent(typ): DISPLAY=:0; XAUTHORITY=~owner_of:0/.Xauthority; export DISPLAY XAUTHORITY
ssh -i $key axel@192.168.0.183 "DISPLAY=:0; XAUTHORITY=/home/axel/.Xauthority; export DISPLAY XAUTHORITY; notify-send '"$TR_TORRENT_NAME" är klar' '"$TR_TORRENT_NAME" laddades ner till "$TR_TORRENT_DIR"' -i /usr/local/bin/transgui.png"
ssh -i $key axel@192.168.0.185 "/Users/axel/scripts/Magnet/terminal-notifier_1.4.2/terminal-notifier.app/Contents/MacOS/terminal-notifier -message '"Torrent-nedladdning är klar"' -subtitle '"$TR_TORRENT_NAME" laddades ner till "$TR_TORRENT_DIR"' -group transmission -open '"http://axellarsson.nu:9091"'"

exit
