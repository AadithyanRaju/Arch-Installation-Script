#!/bin/bash

# set timezone
while true; do
    read -p "Select timezone (default: Asia/Kolkata ) [for listing all enter 'view']:" timezone
    if [ $timezone == "view" ]; then
        timedatectl list-timezones
    else if [ $timezone == "" ]; then
        timezone="Asia/Kolkata"
        break
    else if [ $timezone != $(timedatectl list-timezones | grep $timezone) ]; then
        echo "Invalid timezone"
    else
        break
    fi
done
timedatectl set-timezone $timezone

# set time
timedatectl set-ntp true

# set locale
while true; do
    read -p "Select locale (default: en_US.UTF-8 UTF-8) [for listing all enter 'view']:" locale
    if [ $locale == "view" ]; then
        cat /etc/locale.gen | more
    else if [ $locale == "" ]; then
        locale="en_US.UTF-8 UTF-8"
        break
    else if [ $locale != $(cat /etc/locale.gen | grep $locale) ]; then
        echo "Invalid locale"
    else
        break
    fi
done

# generate locale
echo $locale >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
export LANG=en_US.UTF-8

# set hostname
while true; do
    read -p "Enter hostname (default: archlinux):" hostname
    if [ $hostname == "" ]; then
        hostname="archlinux"
        break
    fi
    # check if hostname is valid
    if [ $hostname != $(echo $hostname | grep -E "^[a-zA-Z0-9-]*$") ]; then
        echo "Invalid hostname"
    else
        break
    fi
done
echo $hostname > /etc/hostname

# set hosts
echo "127.0.0.1 localhost" > /etc/hosts
echo "::1 localhost" >> /etc/hosts
echo "127.0.1.1 $hostname" >> /etc/hosts

# set root password
while true; do
    read -p "Enter root password:" root_password
    if [ $root_password == "" ]; then
        echo "Invalid password"
    else
        break
    fi
done
echo "root:$root_password" | chpasswd

disk=$(cat ./disk)
# install bootloader
pacman -S grub efibootmgr --noconfirm
if [ $(ls /sys/firmware/efi/efivars) != "" ]; then
    mkdir /boot/efi
    mount ${disk}1 /boot/efi
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
else
    grub-install --target=i386-pc $disk
fi
grub-mkconfig -o /boot/grub/grub.cfg

# create user
pacman -S sudo --noconfirm
while true; do
    read -p "Enter username (default: arch):" username
    if [ $username == "" ]; then
        username="arch"
        break
    fi
    # check if username is valid
    if [ $username != $(echo $username | grep -E "^[a-z_][a-z0-9_-]*[$]") ]; then
        echo "Invalid username"
    else
        break
    fi
done
adduser $username
while true; do
    read -p "Enter password for $username:" user_password
    if [ $user_password == "" ]; then
        echo "Invalid password"
    else
        break
    fi
done
echo "$username:$user_password" | chpasswd
usermod -aG wheel,audio,video,storage $username

# edit visudo
sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g' /etc/sudoers

# install gnome
read -p "Install gnome? (y/n):" install_gnome
if [ $install_gnome == "y" ]; then
    pacman -S xorg networkmanager --noconfirm
    pacman -S gnome gnome-tweaks --noconfirm
    systemctl enable gdm
    systemctl enable NetworkManager
fi
