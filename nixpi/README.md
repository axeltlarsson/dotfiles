# nixpi

Use https://github.com/AxelTLarsson/nixos-rpi-sd-image to bootstrap the system.

## Update FW

```sh
# as root
nix-shell -p raspberrypi-eeprom
mount /dev/disk/by-label/FIRMWARE /mnt
BOOTFS=/mnt FIRMWARE_RELEASE_STATUS=stable rpi-eeprom-update -d -a
```

https://nix.dev/tutorials/installing-nixos-on-a-raspberry-pi#updating-firmware
