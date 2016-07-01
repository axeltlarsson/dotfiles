== Ubuntuserver backup scripts ==

Detta är ett repo för att hålla koll på scripts på Ubuntuservern.

Jag tänkte mig att jag lägger scripten i sina tilltänkta hemmahörande mappar så att säga.
Så att repots filstruktur representerar den tilltänkta på servern.


=== lex_integrity ===
Systemet kan grovt delas in i två delar, dels sjävla VPN-tunneln som kan sättas upp med pptpsetup enligt nedan och dels sjävla routingen.

==== VPN-tunneln ====
Använd pptpsetup för att sätta up tunneln första gången:
`pptpsetup --create lex_integrity --server lexvpn.integrity.st --username alice --password foo --encrypt`.
Man kan även sätta upp detta manuellt och diverse konfigurationsfiler som är intressanta är /etc/ppp/chap-secrets och /etc/ppp/peers/lex_integrity.

När VPN-tunneln är uppsatt kommer den troligtvis att få enhetsnamnet ppp0 och när man anslutit bör den visa sig i outputen av `ifconfig`.

För att sätta på tunneln: "pon lex_integrity" som root, 
för att stänga av den "poff lex_integrity".
För att kolla senaste status för tunneln, använd `plog`.

för att kolla att tunneln skapas, kolla efter "ppp0" i ifconfig:s output.
För att debuga att lex_integrity verkligen ansluter: kör "pon lex_integrity debug dump logfd 2 nodetach"

Källa: https://wiki.archlinux.org/index.php/PPTP_VPN_client_setup_with_pptpclient#Configure_using_pptpsetup

===== Automatisk återanslutning =====
Lägg till dessa två rader i /etc/ppp/peers/lex_integrity:
`
persist
maxfail 0
`

==== Routing med iptables, ip rule, ip route =====
`iptables` används för att märka paket som vi vill ska gå igenom VPN-tunneln senare. Detta görs genom att lägga till en regel i tabellen `mangle` som märker
paket från användaren debian-transmission med `fwmark`. Man märker alltså då alla paket som härrör en viss användare med ett tal, exempelvis 0x1.
Använd skriptet `lex_integrity_iptables.sh` för att automatiskt sätta upp iptables-regler, detta behöver bara köras en gång. 
Detta skript gör lite mer än att bara märka paket och kanske eventuellt så bör man
fixa det så att det gör lite mindre grejor, kanske dessutom så kan man fixa så att transmission blir tillgängligt utan för nätverket genom lite smartare regler här?
Källa för skriptet är: http://www.niftiestsoftware.com/2011/08/28/making-all-network-traffic-for-a-linux-user-use-a-specific-network-interface/

MEN iptables kommer att glömma reglerna om man startar om datorn. Därför behöver man spara iptables-inställningarna innan man startar om och återställa de vid varje omstart.
Kör (som root): 
`iptables-save > /etc/iptables_rules`
och se till att scriptet /etc/network/if-up.d/iptables-restore finns (kolla i detta repo) och har rättigheter korrekt satta:
'chmod 755 /etc/network/if-up.d/firewall'

Nu kommer systemet att återställa dessa inställningarna när nätverket initierats dirr så trafiken bör routas via tunneln dirr när servern startas.

Sedan kan man använda `ip rule` för att skapa en regel som matchar paket märkta med 0x1 och då skickar dem till en speciell routing-tabell, definierad av `ip route`.
`ip rule show` ger alla regler och här bör det då finnas en regel liknande: "32763:	from all fwmark 0x1 lookup 200" där allt efter kolonet är sjävla regeln och siffran innan
är nummerordningen på regeln. Regeln säger alltså att alla paket med märket 0x1 skall behandlas av tabell 200.

Denna tabell identifieras antingen via ett namn, typ "lex_integrity" eller ett nummer, exempelvis "200". Mappningen dem emellan sker i filen /etc/iproute2/rt_tables.
Med `ip route` kan man då alltså skapa en rutt som gör att paketen använder VPN-tunneln, eller närmare bestämt använder enheten ppp0. I tabellen ska man alltså se till att VPN-tunneln
används korrekt och eftersom VPN-tunnelns default gateway etc kan ändras så kan man lägga ett script, /etc/ppp/ip-up.d/lex_integrity_ip_route som tillkallas varje gång tunneln ansluts.
Detta skripts uppgift är att lägga till korrekta rutter för den nuvarande VPN-uppkopplingen, specifikt så förändras ju GATEWAYIP vilket ges av $5 nedan i listan och detta måste alltså
uppdateras varje gång man ansluter till VPN-tunneln i fall den har förändrats.

Alla script i /etc/ppp/ip-up.d/ tillkallas alltså när VPN-tunneln kopplas upp med parametrarna:
	
	$1 Interface name
	$2 The tty
	$3 The link speed
	$4 Local IP number
	$5 Peer IP number
	$6 Optional ``ipparam'' value foo

KOM IHÅG ATT run-parts INTE KÖR FILER MED ÄNDELSEN .sh, VILKET EGENTLIGEN ÄR EN BUGG MEN EN FUCKING STÖRIG SÅDAN.
FÖR ATT TESTA OM run-parts KÖR EN FIL I EN VISS MAPP: `run-parts -v –test <mapp>`

Allmänt användbara kommandon är:
`ip route show` visa ip-rutter
`iptables -t mangle -L` lista (alltså inte printa ut själva reglerna) reglerna i tabellen "mangle"
`iptables -L` lista iptables för default
`iptables --list-rules` printa själva reglerna
`iptables -t nat --list-rules` printa sjävla reglerna för tabellen nat


=== Bortkoppling ===
För att koppla bort hela systemet, alltså tillåta debian-transmission att använda den vanliga anslutningen så gör man detta enklast genom att ta bort reglerna i tabellen "lex_integrity" (eller "200"):
`ip route del table 200`.
Reglerna återskapas av /etc/ppp/ip-up.d/lex_integrity_ip_route när VPN-tunneln startas igen nästa gång.
Alternativt kan man låta tabellen ligga kvar men ta bort bort regeln som säger att tabellen ens skall användas:
`ip rule delete fwmark 0x1`


=== Automatisk uppstart ===
För att VPN-tunneln skall startas automatiskt vid uppstart av servern, lägg till följande i /etc/network/interfaces:
`
auto tunnel
iface tunnel inet ppp
 provider lex_integrity`


=== Logga till /var/log/ppp ===
Istället för att logga till /var/log/syslog som inte är najs eftersom då fungerar inte `plog` annars än för händelser väldigt nära i tiden, så kan vi 
instruera ppp att logga till /var/log/ppp istället vilket är lätt att manuellt läsa ifrån och plog fungerar mycket mer förutsägbart.
Lägg till detta i slutet av /etc/rsyslog.conf
`local2.*       -/var/log/ppp.log
`


## vsftp
Sätta uppftp-serier och ftp-filmer att bli chroot:ade till /Serier resp. /Filmer.
With a bit of playing around I've managed to come up with a semi solution (not perfect but good enough)

using 2707974 answer and information I've gained else where I've been able to get what I need.

First you need vsftp and PAM installed

apt-get install vsftpd libpam-pwdfile
Edit /etc/vsftpd.conf

nano /etc/vsftpd.conf
then paste in the following

listen=YES
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
local_root=/var/www
chroot_local_user=YES
allow_writeable_chroot=YES
hide_ids=YES

#virutal user settings
user_config_dir=/etc/vsftpd_user_conf
guest_enable=YES
virtual_use_local_privs=YES
pam_service_name=vsftpd
nopriv_user=vsftpd
guest_username=vsftpd
Edit to your exact needs the most important bit for virtual users is everything after the virtual user settings comment

Creating User

You can either use a database or htpasswd I found htpasswd faster and easier to use.

make a directory to store your users

mkdir /etc/vsftpd
htpasswd -cd /etc/vsftpd/ftpd.passwd user1
adding additional users just omit the -c

htpasswd -d /etc/vsftpd/ftpd.passwd user2
I've only managed to get it to work using CRYPT which limits to 8 chars to use more than 8 chars use openssl to generate a compatible hash and pipe directly into htpasswd

htpasswd -c -p -b /etc/vsftpd/ftpd.passwd user1 $(openssl passwd -1 -noverify password)
Once your users are created you can now change your PAM config file

nano /etc/pam.d/vsftpd
and remove everything inside this file and replace with the following

auth required pam_pwdfile.so pwdfile /etc/vsftpd/ftpd.passwd
account required pam_permit.so
This will enable login for your virtual users defined in /etc/vsftpd/ftpd.passwd and will disable local users

Next we need to add a user for these virtual users to use. These users will not have access to the shell and will be called vsftpd

useradd --home /home/vsftpd --gid nogroup -m --shell /bin/false vsftpd
the user must match guest_username=vsftpd in the vsftpd conf file

Defining Directory Access

The important line here is the following

user_config_dir=/etc/vsftpd_user_conf
this means that when user1 logs in it will look for the following file

/etc/vsftpd_user_conf/user1
this file the same as the vsftpd.conf so you can define a new local_root

going back to the question we want user1 to only have access to var/www/website_name1/sub_folder1, so we need to create the vsftpd_user_conf folder:

mkdir /etc/vsftpd_user_conf
Now create the user file:

nano /etc/vsftpd_user_conf/user1
and enter the following line

local_root=/var/www/website_name1/sub_folder1
Now restart vsftp

service vsftpd restart
you should now be able to login as user1 who will only be able to see var/www/website_name1/sub_folder1 and any folder and file inside it.

That's it you can now add as many users as you want and limit their access to whatever folder you wish.

important to remember if you do not create a user conf file it will default to the var/www folder as root (in the example above)

If the subfolder is intended to be modifiable by the user, it might be necesary to change the owner of the shared subfolder:

chown vsftpd:nogroup /var/www/website_name1/sub_folder1

