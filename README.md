# ISP Flasher

## High Speed ISP flasher using the SPI of a Raspberry Pi

### Used Hardware

- Raspberry Pi3b+ (any pi with the new header layout and SPI will do)
- this [case](https://www.prusaprinters.org/prints/15876-raspberry-pi-3-sleeve-case/files)
- Sparkfun Raspberry Pi Shield: [DEV-14747](https://www.sparkfun.com/products/14747)
- ISP adapters in this repo

### Setup

- install OS to SD or USB: I used [DietPI](https://dietpi.com/) but you can use anything you like.
- Enable SPI: `nano /boot/config.txt` add / edit `dtparam=spi=on` and `reboot`
- install avrdude with SPI enabled following this [guide](http://kevincuzner.com/2013/05/27/raspberry-pi-as-an-avr-programmer/)
- place flash.sh in /root/ and `chmod +x /root/flash.sh`
- add service `nano /etc/systemd/system/flasherdasher.service` and paste in the content of flasherdasher.service in this repo. `systemctl enable --now flasherdasher`
- format a USB stick in FAT32 and get the UUID with `blkid` 
- place the config on the USB stick and edit the UUID 
- add your hex to the USB and edit the fuse bits, firmware name, lock bit and flashing speeds to your liking

## Happy flashing!