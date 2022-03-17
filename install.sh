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
while true; do
	read -r swap_size
	swap_size="${swap_size:-2048}"
	if [ "$swap_size" -ge 0 ]; then
		break
	else
		printf "Please enter a number: [2048] "
	fi
done

if [ "$swap_size" -gt 0 ]; then
	dd if=/dev/zero of=/mnt/swapfile bs=1M count="$swap_size"
	chmod 600 /mnt/swapfile
	mkswap /mnt/swapfile
	swapon /mnt/swapfile
fi

# Installation
printf 'Do you want to update the mirrorlist? (This may take a while) [Y/n] '
read -r yn
yn="${yn:-y}"
case "$yn" in
	[yY]* )
		cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.old
		reflector --latest 20 --sort rate --save /etc/pacman.d/mirrorlist
		;;
esac
unset yn

pacstrap /mnt base linux linux-firmware neovim

# Configure the system
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt

printf "Select timezone (Enter for list): [Europe/Vienna] "
read -r timezone
timezone="${timezone:-Europe/Vienna}"
region=""
while true; do
	if [ -f "/usr/share/zoneinfo/$timezone" ]; then
		printf "Confirm timezone: %s [y/N] " "$timezone"
		read -r yn
		yn="${yn:-n}"
		case "$yn" in
			[yY]* )
				break
				;;
			* )
				timezone=""
				region=""
				;;
		esac
	elif ! [ "$region" = "" ] && [ -d "/usr/share/zoneinfo/$region" ]; then
		ls "/usr/share/zoneinfo/$region"
		printf "Enter city: "
		read -r city
		timezone="$region/$city"
	else
		find /usr/share/zoneinfo -maxdepth 1 -type d | awk -F "/" '{print $5}'
		printf "Enter region: "
		read -r region
	fi

done
unset yn

ls -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
hwclock --systohc

# Localization
localization='en_US.UTF-8 UTF-8'
sed -i "s/^#$localization/$localization/" /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' >> /etc/locale.conf
echo 'KEYMAP=colemak' >> /etc/vconsole.conf

# Network configuration
printf 'Enter hostname: '
read -r hostname
while true; do
	printf "Is this hostname correct? %s [y/N] " "$hostname"
	read -r yn
	yn="${yn:-n}"
	case "$yn" in
		[yY]* )
			break
			;;
	esac
done
unset yn

echo "$hostname" > /etc/hostname
pacman -S --noconfirm networkmanager
systemctl enable --now NetworkManager

printf "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.0.1\t%s\n" "$hostname" > /etc/hosts

# Initramfs
mkinitcpio -P

# Root password
while true; do
	printf 'Enter root password: '
	read -r pwd_root
	printf "Please enter again: "
	read -r pwd_root2
	if [ "$pwd_root" = "$pwd_root2" ]; then
		break
	fi
done
unset pwd_root2
printf "%s\n%s" "$pwd_root" "$pwd_root" | passwd root

# Boot loader
case "$(lscpu | grep 'Vendor ID')" in
	*AuthenticAMD )
		microcode='amd-ucode'
		;;
	*GenuineIntel )
		microcode='intel-ucode'
		;;
	* )
		printf "Could not find microcode for procesor. Aborting script.\n"
		exit
		;;
esac
pacman -S "$microcode" grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Reboot
exit
umount -R /mnt

printf 'Installation is done\n'
