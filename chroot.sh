#!/bin/sh
# Script to run inside chroot environment.

# Values are set by "install.sh". Do not edit yourself!
uuid_crypt=
drive=
pass_root=
username=
pass_user=
hostname=
keymap=

# Configure the system

# Time zone
ln -sf /usr/share/zoneinfo/Europe/Vienna /etc/localtime
hwclock --systohc

# Localization
sed -i -E 's/^#(en_US.UTF-8 UTF-8\s*$)/\1/' /etc/locale.gen
sed -i -E 's/^#(en_GB.UTF-8 UTF-8\s*$)/\1/' /etc/locale.gen
locale-gen
printf 'LANG=en_US.UTF-8\n' > /etc/locale.conf
printf 'KEYMAP=%s\n' "$keymap" > /etc/vconsole.conf

# Network configuration
printf '%s\n' "$hostname" > /etc/hostname
systemctl enable NetworkManager.service

# Initramfs
# See https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#Configuring_mkinitcpio
cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.old
sed -i '/^HOOKS/s/udev/systemd/' /etc/mkinitcpio.conf
sed -i '/^HOOKS/s/keymap/sd-vconsole/' /etc/mkinitcpio.conf
sed -i '/^HOOKS/s/block/& sd-encrypt/' /etc/mkinitcpio.conf
mkinitcpio -P

# Root password
printf 'root:%s' "$pass_root" | chpasswd

# Add user
useradd -m -G wheel "$username"
printf '%s:%s' "$username" "$pass_user" | chpasswd
sed -i -E 's/^#\s*(%wheel ALL=\(ALL:ALL\) ALL$)/\1/' /etc/sudoers

# Boot loader
case "$(lscpu | grep 'Vendor ID')" in
    *AuthenticAMD*)
        microcode='amd-ucode'
        ;;
    *GenuineIntel*)
        microcode='intel-ucode'
        ;;
    *)
        printf 'Could not find microcode for processor. Aborting script.\n'
        exit 1
        ;;
esac
pacman -S --noconfirm "$microcode"
# https://wiki.archlinux.org/title/EFISTUB#efibootmgr
# shellcheck disable=SC1003
efibootmgr --create --disk "/dev/$drive" --part 1 --label "Arch" --loader /vmlinuz-linux --unicode 'rd.luks.name='"$uuid_crypt"'=root root=/dev/mapper/root rw initrd=\'"$microcode"'.img initrd=\initramfs-linux.img'
