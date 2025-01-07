#!/bin/sh
# Script to install Arch Linux.

# Uncomment lines below and set values manually.
# drive=""              # Drive to install Arch Linux. (default first drive)
# swap_size=""          # Swap size in GiB. Set "0" for none. (default "8")
# encrypt_root=""       # Encrypt root partition ("true" or "false"). (default "false")
# pass_luks=""          # Passphrase for LUKS if encryption is "true". (default "pass")
# pass_root=""          # Passphrase for root user. (default "pass")
# username=""           # Username for regular user. (default "user")
# pass_user=""          # Passphrase for regular user. (default "pass")
# hostname=""           # Hostname of the device. (default "arch")
# keymap=""             # Keyboard mapping for console. (default "us")

# Set default values.
drive_default="$(lsblk -dno NAME | grep -E '^nvme|^sd|^vd' | head -n 1)"
drive="${drive:-$drive_default}"
swap_size="${swap_size:-8}"
encrypt_root="${encrypt_root:-false}"
pass_luks="${pass_luks:-pass}"
pass_root="${pass_root:-pass}"
username="${username:-user}"
pass_user="${pass_user:-pass}"
hostname="${hostname:-arch}"
keymap="${keymap:-us}"

# Assert file existence.
[ -f chroot.sh ] || exit 1

# Main program following https://wiki.archlinux.org/title/Installation_guide

# Pre-installation

# Verify the boot mode
[ -d /sys/firmware/efi/efivars ] || exit

# Partition the disks
fdisk "/dev/$drive" << FDISK_CMDS
g
n


+1024M
t
1
n



w
FDISK_CMDS
efi_system_partition="$(lsblk -rno NAME "/dev/$drive" | grep "$drive.*1")"
root_partition="$(lsblk -rno NAME "/dev/$drive" | grep "$drive.*2")"

# Format the partitions
mkfs.fat -F 32 "/dev/$efi_system_partition"
if [ "$encrypt_root" = "true" ]; then
    printf '%s' "$pass_luks" | cryptsetup luksFormat --key-file - "/dev/$root_partition"
    printf '%s' "$pass_luks" | cryptsetup open --key-file - "/dev/$root_partition" root
    mkfs.ext4 /dev/mapper/root
else
    mkfs.ext4 "/dev/$root_partition"
fi

# Mount the file systems
if [ "$encrypt_root" = "true" ]; then
    mount /dev/mapper/root /mnt
else
    mount "/dev/$root_partition" /mnt
fi
mount --mkdir "/dev/$efi_system_partition" /mnt/boot
# swap
if [ "$swap_size" -gt 0 ]; then
    dd if=/dev/zero of=/mnt/swapfile bs=1GiB count="$swap_size"
    chmod 600 /mnt/swapfile
    mkswap /mnt/swapfile
    swapon /mnt/swapfile
fi

# Installation

# Install essential packages
pacstrap -K /mnt base linux linux-firmware base-devel efibootmgr neovim networkmanager

# Configure the system

# Fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Create and edit "chroot.sh".
uuid_root="$(lsblk -dno UUID "/dev/$root_partition")"
sed -i -E "s/(^drive=$)/\1'$drive'/" chroot.sh
sed -i -E "s/(^encrypt_root=$)/\1'$encrypt_root'/" chroot.sh
sed -i -E "s/(^uuid_root=$)/\1'$uuid_root'/" chroot.sh
sed -i -E "s/(^pass_root=$)/\1'$pass_root'/" chroot.sh
sed -i -E "s/(^username=$)/\1'$username'/" chroot.sh
sed -i -E "s/(^pass_user=$)/\1'$pass_user'/" chroot.sh
sed -i -E "s/(^hostname=$)/\1'$hostname'/" chroot.sh
sed -i -E "s/(^keymap=$)/\1'$keymap'/" chroot.sh
cp chroot.sh /mnt/root/chroot.sh
# Chroot
arch-chroot /mnt /root/chroot.sh
shred -u /mnt/root/chroot.sh

# Reboot
[ "$swap_size" -gt 0 ] && swapoff /mnt/swapfile
umount -R /mnt
[ "$encrypt_root" = "true" ] && cryptsetup close /dev/mapper/root

# Finalize
printf '\033[1mInstallation is done.\n'
