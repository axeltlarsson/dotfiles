## Miscellaneous configuration files
This directory contains miscellaneous configuration files that are useful to have symlinked to this repo. When setting up
a new machine, just run
```
sudo ./setup.sh -m
```
to do the symlinking. The files will be symlinked to their respective directory as defined by their parent folders in
this directory. For instance <code>usr/local/bin/magnet</code> will be symlinked to <code>/usr/local/bin/magnet</code>.

## The files

* <code>usr/local/bin/magnet</code> -  a script to instantly upload torrent files/magnet links to the transmission 
daemon on the server

* <code>etc/fancontrol</code> - configuration file for fancontrol
