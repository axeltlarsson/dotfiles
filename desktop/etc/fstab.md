## Example contents of `/etc/fstab`

```
//192.168.0.199/Axel /media/axel cifs credentials=/home/axel/.smbcredentials,noexec,uid=axel,gid=users,iocharset=utf8 0 0
//192.168.0.199/Public /media/public cifs credentials=/home/axel/.smbcredentials,noexec,uid=axel,gid=users,iocharset=utf8 0 0
```
Add to `.smbcredentials`:
```
username=samba_user
password=samba_user_password
```
`chmod 0400 ~/.smbcredentials`

`sudo chown root ~/.smbcredentials`

[https://help.ubuntu.com/community/Samba/SambaClientGuide](https://help.ubuntu.com/community/Samba/SambaClientGuide)