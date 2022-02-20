#!/bin/bash
USB=/dev/disk/by-uuid/33E3-81B7 #USB fat32 part UUID
MNT=/media/flash #mountpoint path

#GPIO setup
pigs modes 4 w  #SCRIPT
pigs modes 22 w #FUSE_BITS_PASS
pigs modes 27 w #FUSE_BITS_FAIL
pigs modes 6 w  #FLASH_HEX_PASS
pigs modes 17 w #FLASH_HEX_FAIL
pigs modes 12 w #LOCK_BITS_PASS
pigs modes 25 w #LOCK_BITS_FAIL
pigs modes 23 w #SERIAL_UPLOAD_PASS
pigs modes 24 w #SERIAL_UPLOAD_FAIL
pigs modes 16 w #PGM_CTRL_T
pigs modes 13 r #CAPSENSE
pigs modes 5 r  #SHUTDOWN

#LEDs
1_ALL () {
    pigs w 22 1
    pigs w 27 1
    pigs w 6 1
    pigs w 17 1
    pigs w 12 1
    pigs w 25 1
    pigs w 23 1
    pigs w 24 1
}
0_ALL () {
    pigs w 22 0
    pigs w 27 0
    pigs w 6 0
    pigs w 17 0
    pigs w 12 0
    pigs w 25 0
    pigs w 23 0
    pigs w 24 0
}
1_SCRIPT () { pigs w 4 1; }
0_SCRIPT () { pigs w 4 0; }
1_FUSE_BITS_PASS () { pigs w 22 1; }
0_FUSE_BITS_PASS () { pigs w 22 0; }
1_FUSE_BITS_FAIL () { pigs w 27 1; }
0_FUSE_BITS_FAIL () { pigs w 27 0; }
1_FLASH_HEX_PASS () { pigs w 6 1; }
0_FLASH_HEX_PASS () { pigs w 6 0; }
1_FLASH_HEX_FAIL () { pigs w 17 1; }
0_FLASH_HEX_FAIL () { pigs w 17 0; }
1_LOCK_BITS_PASS () { pigs w 12 1; }
0_LOCK_BITS_PASS () { pigs w 12 0; }
1_LOCK_BITS_FAIL () { pigs w 25 1; }
0_LOCK_BITS_FAIL () { pigs w 25 0; }
1_SERIAL_UPLOAD_PASS () { pigs w 23 1; }
0_SERIAL_UPLOAD_PASS () { pigs w 23 0; }
1_SERIAL_UPLOAD_FAIL () { pigs w 24 1; }
0_SERIAL_UPLOAD_FAIL () { pigs w 24 0; }

#Switches
1_PGM_CTRL_T () { pigs w 16 1; }
0_PGM_CTRL_T () { pigs w 16 0; }
CAPSENSE () { pigs r 13; }
SHUTDOWN () { pigs r 5; }

onexit () {
  1_ALL
  echo
  echo "Killed FlasherDasher :/"
  sleep 0.5
  0_ALL
  0_SCRIPT
  exit
}
shtdwn () {
  1_ALL
  echo
  echo "Shutting down"
  sleep 0.5
  0_ALL
  0_SCRIPT
  shutdown now
  exit
}
lederror () {
  for i in {1..3}; do
    1_SERIAL_UPLOAD_FAIL
    sleep 0.1
    0_SERIAL_UPLOAD_FAIL
    sleep 0.1
  done
  1_SERIAL_UPLOAD_FAIL
}
ledsuccess () {
  for i in {1..3}; do
    1_SERIAL_UPLOAD_PASS
    sleep 0.1
    0_SERIAL_UPLOAD_PASS
    sleep 0.1
  done
  1_SERIAL_UPLOAD_PASS
}

trap onexit EXIT

echo "FlasherDasher ready!"
1_SCRIPT

while true; do
  if ! [ -f "/media/flash/config" ]; then
    if ! [ -d "/media/flash" ]; then
      mkdir $MNT
      echo "created mount dir"
    fi
    0_SCRIPT
    lederror
    echo "config not found"
    umount -l $MNT > /dev/null 2>&1
    sleep 0.5
    mount -o sync $USB $MNT > /dev/null 2>&1
  else
    1_SCRIPT
    source $MNT/config
    cd $MNT
    while [ "$(CAPSENSE)" == "1" ]; do
      if pidof -x "avrdude" >/dev/null; then
        echo "flash already running"
      else
        1_PGM_CTRL_T
        0_ALL
        echo "flashing fuses"
        1_FUSE_BITS_FAIL
        rm $MNT/flashlog_fuses.txt
        avrdude -p $DEVICE -c linuxspi -P /dev/spidev0.0 -b $fusebaud -e -u -U hfuse:w:$HIGH_FUSE:m -u -U lfuse:w:$LOW_FUSE:m -u -U efuse:w:$EXT_FUSE:m 2>$MNT/flashlog_fuses.txt
        if git grep --all-match --no-index -l -e 'avrdude: 1 bytes of hfuse verified' -e 'avrdude: 1 bytes of lfuse verified' -e 'avrdude: 1 bytes of efuse verified' ./flashlog_fuses.txt >/dev/null; then
          echo "flashing fuses successful"
          0_FUSE_BITS_FAIL
          1_FUSE_BITS_PASS
          echo "flashing firmware"
          1_FLASH_HEX_FAIL
          rm $MNT/flashlog_firmware.txt
          avrdude -p $DEVICE -c linuxspi -P /dev/spidev0.0 -b $firmbaud -u -U flash:w:$firmware:i 2>$MNT/flashlog_firmware.txt
          if git grep --all-match --no-index -l -e 'bytes of flash verified' ./flashlog_firmware.txt >/dev/null; then
            echo "flashing firmware successful"
            0_FLASH_HEX_FAIL
            1_FLASH_HEX_PASS
            echo "flashing lock"
            1_LOCK_BITS_FAIL
            rm $MNT/flashlog_lock.txt
            avrdude -p $DEVICE -c linuxspi -P /dev/spidev0.0 -b $lockbaud -u -U lock:w:$LOCK:m 2>$MNT/flashlog_lock.txt
            if git grep --all-match --no-index -l -e 'avrdude: 1 bytes of lock verified' ./flashlog_lock.txt >/dev/null; then
                echo "flashing lock successful"
                0_LOCK_BITS_FAIL
                1_LOCK_BITS_PASS
                ledsuccess
            else
                echo "lock flashing error"
                lederror
            fi
          else
            echo "firmware flashing error"
            lederror
          fi
        else
          echo "fuse flashing error"
          lederror
        fi
        0_PGM_CTRL_T
      fi
    done
  fi
  if [ "$(SHUTDOWN)" == "0" ]; then
    shtdwn
  fi
done