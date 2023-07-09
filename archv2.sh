#!/bin/bash

# check number of arguments
# bash filename username hostname userpassword rootpassword disk keyborad_layout timezone locale
if [ $# -ne 9 ]; then
    echo "Error: Invalid number of arguments"
    echo "Usage: bash $0 username hostname userpassword rootpassword disk keyborad_layout timezone locale"
    exit 1
fi

# check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use root to install Arch Linux"
    exit 1
fi

# check if hostname is archiso
if [ $(cat /etc/hostname) != "archiso" ]; then
    echo "Error: You must use archiso to run this script, please use archiso to install Arch Linux"
    exit 1
fi

# check if disk is valid
if [ ! -b $6 ]; then
    echo "Error: Disk is not valid"
    echo "run 'fdisk -l' to see all disk"
    exit 1
fi

# check if keyboard layout is valid
if [ ! -f /usr/share/kbd/keymaps/**/*.map.gz ]; then
    echo "Error: Keyboard layout is not valid"
    echo "run 'ls /usr/share/kbd/keymaps/**/*.map.gz' to see all keyboard layout"
    exit 1
fi
loadkeys $7

# check username for user is valid
if [ $($1 | grep -E "^[a-z_][a-z0-9_-]*") ]; then
    echo "Error: Username is not valid"
    echo "Username must be lowercase, start with a letter or underscore, and contain only letters, numbers, underscores, and dashes"
    exit 1
fi

# check hostname is valid
if [ $($2 | grep -E "^[a-zA-Z0-9][a-zA-Z0-9-]*") ]; then
    echo "Error: Hostname is not valid"
    echo "Hostname must be lowercase, start with a letter or number, and contain only letters, numbers, and dashes"
    exit 1
fi

# check userpassword is valid
if [ ${#3} -lt 8 ]; then
    echo "Error: User password is not valid"
    echo "User password must be at least 8 characters"
    exit 1
fi

# check rootpassword is valid
if [ ${#4} -lt 8 ]; then
    echo "Error: Root password is not valid"
    echo "Root password must be at least 8 characters"
    exit 1
fi

# check timezone is valid
if [ ! -f /usr/share/zoneinfo/$8 ]; then
    echo "Error: Timezone is not valid"
    echo "run 'ls /usr/share/zoneinfo' to see all timezone"
    exit 1
fi

# check locale is valid
if [ $9 != $(cat /etc/locale.gen | grep $9 ]; then
    echo "Error: Locale is not valid"
    echo "run 'cat /etc/locale.gen' to see all locale"
    exit 1
fi

# check connection
echo "Check connection"
ping -c 3 google.com
if [ $? -ne 0 ]; then
    echo "Error: No internet connection"
    echo "Please connect to internet before install Arch Linux"
    echo "run 'wifi-menu' to connect to wifi"
    echo "run 'dhcpcd' to connect to ethernet"
    exit 1
fi

# disk partition
echo "Disk partition"
UEFI=$(ls /sys/firmware/efi/efivars)
if [ $UEFI -ne "" ]; then
    echo "UEFI"
    parted -s $6 mklabel gpt
    parted -s $6 mkpart primary fat32 1MiB 513MiB
    parted -s $6 set 1 esp on
    parted -s $6 mkpart primary ext4 513MiB 100%
    mkfs.fat -F32 ${6}1
    mkfs.ext4 ${6}2
    mount ${6}2 /mnt
    mkdir /mnt/boot
    mount ${6}1 /mnt/boot
else
    echo "BIOS"
    parted -s $6 mklabel msdos
    parted -s $6 mkpart primary ext4 1MiB 100%
    mkfs.ext4 ${6}1
    mount ${6}1 /mnt
fi
#check if disk partition success
if [ $? -ne 0 ]; then
    echo "Error: Disk partition failed"
    exit 1
fi

# update mirrorlist
echo "Update mirrorlist"
pacman -Syy
pacman -S reflector --noconfirm
reflector --verbose --latest 5 --sort rate --save /etc/pacman.d/mirrorlist

# install base system
echo "Install base system"
pacstrap /mnt base base-devel linux linux-firmware vim nano dhcpcd netctl dialog wpa_supplicant grub efibootmgr os-prober
#check if install base system success
if [ $? -ne 0 ]; then
    echo "Error: Install base system failed"
    exit 1
fi

# generate fstab
echo "Generate fstab"
genfstab -U /mnt >> /mnt/etc/fstab
#check if generate fstab success
if [ $? -ne 0 ]; then
    echo "Error: Generate fstab failed"
    exit 1
fi

# chroot
echo "Chroot"
#set timezone
arch-chroot /mnt ln -sf /usr/share/zoneinfo/$8 /etc/localtime
arch-chroot /mnt hwclock --systohc
#set locale
arch-chroot /mnt sed -i "s/#$9/$9/g" /etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=$9" > /mnt/etc/locale.conf
#set hostname
echo $2 > /mnt/etc/hostname
echo "127.0.0.1 localhost" >> /mnt/etc/hosts
echo "::1 localhost" >> /mnt/etc/hosts
echo "127.0.1.1 $2.localdomain $2" >> /mnt/etc/hosts
#set root password
arch-chroot /mnt echo "root:$4" | chpasswd
#set user
arch-chroot /mnt useradd -m -g users -G wheel -s /bin/bash $1
arch-chroot /mnt echo "$1:$3" | chpasswd
#set sudo
arch-chroot /mnt sed -i "s/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g" /etc/sudoers
#set grub
if [ $UEFI -ne "" ]; then
    echo "UEFI"
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
else
    echo "BIOS"
    arch-chroot /mnt grub-install --target=i386-pc $6
fi
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
#check if chroot success
if [ $? -ne 0 ]; then
    echo "Error: Chroot failed"
    exit 1
fi

# unmount
echo "Unmount"
umount -R /mnt
#check if unmount success
if [ $? -ne 0 ]; then
    echo "Error: Unmount failed"
    exit 1
fi

# finish
echo "Finish"
echo "Please reboot your system"


