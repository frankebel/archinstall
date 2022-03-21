#!/bin/sh

arch_chroot() {
	arch-chroot /mnt /bin/bash -c "${1}"
}

# check if in right directory
if ! [ -f README.md ]; then
	printf 'Please change in directory archinstall.\n'
	exit 1
fi

# Verify the boot mode
if ! [ -d /sys/firmware/efi/efivars ]; then
	printf 'You are not in UEFI mode. Script will exit\n'
	exit 1
fi

timedatectl set-ntp true

# Partition the disks
printf 'On which drive do you want to install Arch Linux?\n'
lsblk -d

drive_default="$(lsblk -d | grep -E '^nvme|^sd' | awk '{print $1}' | head -n 1)"
printf "Please choose a drive: [%s] " "$drive_default" 
read -r drive
drive="${drive:-$drive_default}"


printf "\nThis will create 2 partitions on /dev/%s.\nPartition 1 will be of size 512M and type 'EFI System'.\nPartition 2 will take the rest and be of type 'Linux Filesystem'.\n\e[1;31mYou will lose all data on /dev/%s.\e[0m Are you sure? [y/N] " "$drive" "$drive"
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
printf "Do you want to create a swap file? Enter size in MiB (0 for none): [2048] "
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
clear
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

pacstrap /mnt base linux linux-firmware

# Configure the system
genfstab -U /mnt >> /mnt/etc/fstab

clear
printf "Select timezone (Enter for list): "
read -r timezone
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

arch_chroot "ln -sf /usr/share/zoneinfo/$timezone /etc/localtime"
arch_chroot "hwclock --systohc"

# Localization
clear
sed -i '/^#en_US.UTF-8 UTF-8/s/^#//' /mnt/etc/locale.gen
arch_chroot "locale-gen"
echo 'LANG=en_US.UTF-8' > /mnt/etc/locale.conf
clear
printf 'Select a keyboard layout:\n1) colemak\n2) de-latin1\n3) us\n'
while true; do
	printf 'Choose a layout: '
	read -r keyboard_layout
	case "$keyboard_layout" in
		1 )
			keymap='colemak'
			break
			;;
		2 )
			keymap='de-latin1'
			break
			;;
		3 )
			keymap='us'
			break
			;;
	esac
done
echo "KEYMAP=$keymap" > /mnt/etc/vconsole.conf

# Network configuration
clear
while true; do
	printf 'Enter hostname: '
	read -r hostname
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

echo "$hostname" > /mnt/etc/hostname
arch_chroot "pacman -S --noconfirm networkmanager"
arch_chroot "systemctl enable --now NetworkManager"

printf "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.0.1\t%s\n" "$hostname" > /mnt/etc/hosts

# Initramfs
arch_chroot "mkinitcpio -P"

# Root password
clear
while true; do
	stty -echo
	printf '\nEnter root password: '
	read -r pwd_root
	printf "\nPlease enter again: "
	read -r pwd_root2
	if [ "$pwd_root" = "$pwd_root2" ]; then
		stty echo
		break
	fi
done
unset pwd_root2
arch_chroot "printf '%s\n%s' '$pwd_root' '$pwd_root' | passwd root"

# add user
while true; do
	printf 'Add regular user: '
	read -r user
	printf "\nIs this username correct? %s [y/N] " "$user"
	read -r yn
	yn="${yn:-n}"
	case "$yn" in
		[yY]* )
			break
			;;
	esac
done
unset yn
arch_chroot "useradd -m $user -G wheel"
while true; do
	stty -echo
	printf '\nEnter user password: '
	read -r pwd_user
	printf "\nPlease enter again: "
	read -r pwd_user2
	if [ "$pwd_user" = "$pwd_user2" ]; then
		stty echo
		break
	fi
done
unset pwd_user2
arch_chroot "printf '%s\n%s' '$pwd_user' '$pwd_user' | passwd $user"

# add sudo
arch_chroot "pacman -S --noconfirm sudo"
sed -i '/^# %wheel ALL=(ALL:ALL) ALL/s/^# //' /mnt/etc/sudoers

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
		exit 1
		;;
esac
arch_chroot "pacman -S --noconfirm $microcode grub efibootmgr"
arch_chroot "grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB"
arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"

# add text editor
clear
printf 'Choose a text editor:\n1) nano\n2) neovim\n3) vim\n'
while true; do
	printf 'Choose an editor: '
	read -r editor
	case "$editor" in
		1 )
			editor='nano'
			break
			;;
		2 )
			editor='neovim'
			break
			;;
		3 )
			editor='vim'
			break
			;;
	esac
done
arch_chroot "pacman -S --noconfirm $editor"

# Reboot
if [ "$swap_size" -gt 0 ]; then
	swapoff /mnt/swapfile
fi
umount -R /mnt

clear
printf 'Installation is done.\n'
