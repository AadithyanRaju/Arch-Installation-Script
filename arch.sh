#!/bin/bash

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use root to install Arch Linux"
    exit 1
fi

# Check if hostname is archiso
if [ $(cat /etc/hostname) != "archiso" ]; then
    echo "Error: You must use archiso to run this script, please use archiso to install Arch Linux"
    exit 1
fi

echo "Requirements: "
echo "1. 64-bit CPU (x86_64/AMD64)"
echo "2. Ram >= 512MB"
echo "3. Disk >= 10GB"
read -p "Does your computer meet the requirements? [y/n]: " answer
if [ [ $answer == "y" ] || [ $answer == "Y" ] ]; then
    echo "Error: Your computer does not meet the requirements, please upgrade your computer"
    exit 1
fi

# keyboard layout
while true; do
    read -p "Select keyboard layout (default: us) [for listing all enter 'view']:" layout
    if [ $layout == "view" ]; then
        ls /usr/share/kbd/keymaps/**/*.map.gz | more
    else if [ $layout == "" ]; then
        loadkeys us
        break
    else
        loadkeys $layout
        break
    fi
done

# disk partition
if [ ! -f ./disk ]; then
    while true; do
        read -p "Select disk to install Arch Linux (default: /dev/sda) [for listing all enter 'view']:" disk
        if [ $disk == "view" ]; then
            fdisk -l | more
        else if [ $disk == "" ]; then
            disk="/dev/sda"
            break
        else
            break
        fi
    done
    echo $disk > ./disk
else
    disk=$(cat ./disk)
fi

# disk partition
echo "Disk partition"
UEFI=$(ls /sys/firmware/efi/efivars)
if [ $UEFI -ne "" ]; then
    echo "UEFI"
    echo "1. ${disk}1 1M to 512M EFI System"
    echo "2. ${disk}2 512M to 100% Linux filesystem"
    # partition without confirmation
    parted -s $disk mklabel gpt
    parted -s $disk mkpart primary fat32 1M 512M
    parted -s $disk mkpart primary ext4 512M 100%
    parted -s $disk set 1 boot on
    # format
    mkfs.fat -F32 ${disk}1
    mkfs.ext4 ${disk}2
else
    echo "BIOS"
    echo "1. ${disk}1 1M to 100% Linux filesystem"
    # partition without confirmation
    parted -s $disk mklabel msdos
    parted -s $disk mkpart primary ext4 1M 100%
    parted -s $disk set 1 boot on
    # format
    mkfs.ext4 ${disk}1
fi

# Connect to the Internet
echo "Connect to the Internet"
echo "1. Ethernet"
echo "2. Wireless"
read -p "Select network type (default: Ethernet): " network
if [ $network == "2" ]; then
    wifi-menu
fi

# check network
while true; do
    ping -c 3 www.google.com
    if [ $? -eq 0 ]; then
        break
    fi
    echo "Network error, please check your network"
done

# select mirror
pacman -Syy --noconfirm
pacman -S reflector --noconfirm
echo "Selecting the fastest mirror"
echo " creating a backup of the original mirrorlist file"
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
echo " using the backup file to generate a new mirrorlist"
reflector --verbose --latest 5 --sort rate --save /etc/pacman.d/mirrorlist
echo "Mirrorlist generated"

# install base system
echo "Install base system"
if [ $UEFI -ne "" ]; then
    mount ${disk}2 /mnt
else
    mount ${disk}1 /mnt
fi
pacstrap /mnt base linux linux-firmware vim nano
genfstab -U /mnt >> /mnt/etc/fstab

# chroot
echo "Chroot"
cp ./disk /mnt/disk
cp ./chroot.sh /mnt/chroot.sh
arch-chroot /mnt ./chroot.sh
rm /mnt/disk
rm /mnt/chroot.sh

# reboot
echo "Reboot"
umount -R /mnt
reboot