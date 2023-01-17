#!/bin/sh
# Script to install Arch Linux.
# Default value for passphrases is "pass".
# Default username is "user".
# Default hostname is "arch".
# Default swap size is 8 GiB.


# Uncomment lines below and set values manually.
# drive=""              # Drive to install Arch Linux.
# swap_size=""          # Swap size in GiB. Set 0 for none.
# pass_luks=""          # Passphrase for luks.
# pass_root=""          # Passphrase for root user.
# username=""           # Username for regular user.
# pass_user=""          # Passphrase for regular user.
# hostname=""           # Hostname of the device.


# Set default values.
drive_default="$(lsblk -dno NAME | grep -E '^nvme|^sd|^vd' | head -n 1)"
drive="${drive:-$drive_default}"
swap_size="${swap_size:-8}"
pass_luks="${pass_luks:-pass}"
pass_root="${pass_root:-pass}"
username="${username:-user}"
pass_user="${pass_user:-pass}"
hostname="${hostname:-arch}"


# Main program
# Assert file existence.
[ -f chroot.sh ] || exit 1


# Pre-installation

[ -d /sys/firmware/efi/efivars ] || exit 1

# Partition the disks
fdisk "/dev/$drive" << FDISK_CMDS
g
n


+512M
t
1
n



w
FDISK_CMDS
efi_system_partition="$(lsblk -rno NAME "/dev/$drive" | grep "$drive.*1")"
root_partition="$(lsblk -rno NAME "/dev/$drive" | grep "$drive.*2")"

# Format the partitions
printf '%s' "$pass_luks" | cryptsetup luksFormat --key-file - "/dev/$root_partition"
printf '%s' "$pass_luks" | cryptsetup open --key-file - "/dev/$root_partition" root
mkfs.fat -F 32 "/dev/$efi_system_partition"
mkfs.ext4 /dev/mapper/root

# Mount the file systems
mount /dev/mapper/root /mnt
mkdir /mnt/boot
mount "/dev/$efi_system_partition" /mnt/boot
# swap
if [ "$swap_size" -gt 0 ]; then
    dd if=/dev/zero of=/mnt/swapfile bs=1GiB count="$swap_size"
    chmod 600 /mnt/swapfile
    mkswap /mnt/swapfile
    swapon /mnt/swapfile
fi


# Installation
pacstrap /mnt base linux linux-firmware neovim networkmanager sudo efibootmgr


# Configure the system
genfstab -U /mnt >> /mnt/etc/fstab
# Create and edit "chroot.sh".
uuid_crypt="$(lsblk -dno UUID "/dev/$root_partition")"
sed -i -E "s/(^uuid_crypt=$)/\1'$uuid_crypt'/" chroot.sh
sed -i -E "s/(^drive=$)/\1'$drive'/" chroot.sh
sed -i -E "s/(^pass_root=$)/\1'$pass_root'/" chroot.sh
sed -i -E "s/(^username=$)/\1'$username'/" chroot.sh
sed -i -E "s/(^pass_user=$)/\1'$pass_user'/" chroot.sh
sed -i -E "s/(^hostname=$)/\1'$hostname'/" chroot.sh
cp chroot.sh /mnt/root/chroot.sh
# chroot into system
arch-chroot /mnt /root/chroot.sh
shred -u /mnt/root/chroot.sh


# Reboot
[ "$swap_size" -gt 0 ] && swapoff /mnt/swapfile
umount -R /mnt
cryptsetup close /dev/mapper/root


# Finalize
printf '\033[1mInstallation is done.\n'
