# nixpi

## Preparing SD card

Easiest is to start off from a manual installation, downloading latest successful build from Hydra at https://hydra.nixos.org/job/nixos/trunk-combined/nixos.sd_image.aarch64-linux and then dd it to the sd card:

```
diskutil list
dd if=nixos-sd-image-24.05pre570828.cdcd061e7f31-aarch64-linux.img of=/dev/disk4 bs=4096 conv=fsync status=progress
disktuil unmount[Disk] /dev/disk4
```

Then follow https://nix.dev/tutorials/installing-nixos-on-a-raspberry-pi

Alternatively: use https://github.com/AxelTLarsson/nixos-rpi-sd-image to bootstrap the system.

## Configuration

Install SSH keys:

```
mkdir -p .ssh
curl https://github.com/axeltlarsson.keys > .ssh/authorized_keys
```

Clone this repo on the nixpi, and apply the configuration.nix (symlinking to /etc/nixos/configuration.nix for starters).


## Update FW

I haven't actually gotten this to successfully apply the fw update via NixOS, (flashed Raspbian and used rpi-eeprom-update from there instead).

```sh
# as root
nix-shell -p raspberrypi-eeprom
mount /dev/disk/by-label/FIRMWARE /mnt
BOOTFS=/mnt FIRMWARE_RELEASE_STATUS=stable rpi-eeprom-update -d -a
```

