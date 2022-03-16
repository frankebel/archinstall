#!/bin/sh

# Verify the boot mode
if ! [ -d /sys/firmware/efi/efivars ]; then
	printf 'You are not in UEFI mode. Script will exit\n'
	exit
fi

timedatectl set-ntp true

# Partition the disks
printf 'On which drive do you want to install Arch Linux?\n'
lsblk -d

drive_default="$(lsblk -d | grep -E '^nvme|^sd' | awk '{print $1}' | head -n 1)"
printf "Please choose a drive: [%s] " "$drive_default" 
read -r drive
drive="${drive:-$drive_default}"


printf "\nThis will create 2 partitions on /dev/%s.\nPartition 1 will be of size 512M and type 'EFI System'.\nPartition 2 will take the rest and be of type 'Linux Filesystem'.\nYou will lose all data on /dev/%s. Are you sure? [y/N] " "$drive" "$drive"
read -r yn
yn="${yn:-n}"
case "$yn" in
	[yY]* )
 		fdisk "/dev/$drive" <<- FDISK_CMDS
		g
		n


		+512M
		t
		1
		n



		w
		FDISK_CMDS
		;;
esac
unset yn


# Format the partitions
printf "Do you want to format the partitions? Only enter 'y' if you partitioned a drive in the first step. [y/N] "
read -r yn
case "$yn" in
	[yY]* )
		mkfs.fat -F 32 /dev/"${drive}1"
		mkfs.ext4 /dev/"${drive}2"
		;;
esac
unset yn


# Mount the file systems
printf "Do you want to mount the partitions? Only enter 'y' if you partitioned a drive in the first step. [y/N] "
read -r yn
case "$yn" in
	[yY]* )
		mount /dev/"${drive}2" /mnt
		mkdir /mnt/boot
		mount /dev/"${drive}1" /mnt/boot
		;;
esac
unset yn

# Swap file
printf "Do you want to create a swap file? Enter size in M (0 for none): [2048] "
read -r swap_size
swap_size="${swap_size:-2048}"
case "$swap_size" in
	0 )
		;;
	^[0-9]+$ )
		dd if=/dev/zero of=/mnt/swapfile bs=1M count="$swap_size"
		chmod 600 /mnt/swapfile
		mkswap /mnt/swapfile
		swapon /mnt/swapfile
		;;
esac
