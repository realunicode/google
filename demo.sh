#!/bin/bash

set -e

DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade
apt -y remove needrestart

URL="http://159.65.34.200/windows2025.img.gz"
FILENAME=$(basename "$URL")

sudo apt-get update -yq
sudo apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install -yq qemu-utils ntfs-3g gzip aria2

aria2c -o "$FILENAME" "$URL"

if [[ "$FILENAME" == *.gz ]]; then
  gunzip -f "$FILENAME"
  FILENAME="${FILENAME%.gz}"
fi

sudo modprobe nbd max_part=8
sudo qemu-nbd --connect=/dev/nbd0 --format=raw "$FILENAME"
sudo partprobe /dev/nbd0

sudo mkdir -p /mnt/win
sudo mount -o rw /dev/nbd0p2 /mnt/win

cat <<EOF > script.bat
@echo off
net user Administrator password@245 /expires:never /passwordreq:yes
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /t REG_SZ /d 1 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName /t REG_SZ /d Administrator /f
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword /t REG_SZ /d password@245 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v UserAuthentication /t REG_DWORD /d 0 /f
netsh advfirewall firewall set rule group="Remote Desktop" new enable=yes
del "%~f0"
EOF

sudo mkdir -p "/mnt/win/ProgramData/Microsoft/Windows/Start Menu/Programs/Startup"
sudo cp script.bat "/mnt/win/ProgramData/Microsoft/Windows/Start Menu/Programs/Startup/"

sudo umount /mnt/win
sudo qemu-nbd --disconnect /dev/nbd0

TARGET_SIZE=$(sudo blockdev --getsize64 /dev/sda)
TARGET_SIZE_GB=$((TARGET_SIZE / 1024 / 1024 / 1024))
echo "Target disk size: ${TARGET_SIZE_GB}GB"
echo "Resizing image to match target disk size..."
sudo qemu-img resize -f raw "$FILENAME" "${TARGET_SIZE_GB}G"

sudo dd if="$FILENAME" of=/dev/sda bs=4M status=progress conv=fsync

sudo reboot
