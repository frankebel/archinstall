#!/bin/sh

# check if in right directory
if ! [ -f README.md ]; then
	printf 'Please change in directory archinstall.\n'
	exit 1
fi


arch_chroot() {
	arch-chroot /mnt /bin/bash -c "${1}"
}


format_and_partition() {
	printf '1) On which drive do you want to install Arch Linux?\n'
	lsblk -d

	drive_default="$(lsblk -d | grep -E '^nvme|^sd' | awk '{print $1}' | head -n 1)"
	printf "Please choose a drive: [%s] " "$drive_default"
	read -r drive
	drive="${drive:-$drive_default}"

	while true; do
		printf "Do you want to encrypt your root partition? [y/n] "
		read -r encrypt_root
		case "$encrypt_root" in
			[yY]* )
				encrypt_root='true'
				while true; do
					stty -echo
					printf '\nEnter partition password: '
					read -r pwd_partition
					printf "\nPlease enter again: "
					read -r pwd_partition2
					if [ "$pwd_partition" = "$pwd_partition2" ]; then
						stty echo
						break
					fi
				done
				break
				;;
			[nN]* )
				encrypt_root='false'
				break
				;;
		esac
	done

	printf "\nThis will partition and format /dev/%s.\n" "$drive"
	printf "\e[1;31mYou will lose all data on /dev/%s.\e[0m Are you sure? [y/N] " "$drive"
	read -r partition_drive
	partition_drive="${partition_drive:-n}"
	case "$partition_drive" in
		[yY]* )
			partition_drive='true'
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

	partitions="$(lsblk -r -n -o NAME,TYPE "/dev/$drive" | awk '/part/{print $1}')"
	efi_system_partition="$(echo "$partitions" | grep '1$')"
	root_partition="$(echo "$partitions" | grep '2$')"

	if [ "$encrypt_root" = 'true' ]; then
		if [ "$partition_drive" = 'true' ];then
			printf '%s' "$pwd_partition" | cryptsetup luksFormat --key-file=- "/dev/$root_partition"
		fi
		printf '%s' "$pwd_partition" | cryptsetup open --key-file=- "/dev/$root_partition" root
		root_partition_encrypted="$root_partition"
		root_partition='mapper/root'
	fi

	if [ "$partition_drive" = 'true' ]; then
		mkfs.fat -F 32 "/dev/$efi_system_partition"
		mkfs.ext4 "/dev/$root_partition"
	fi
}


mount_volumes() {
	mount "/dev/$root_partition" /mnt
	mkdir /mnt/boot
	mount "/dev/$efi_system_partition" /mnt/boot
}


set_swap() {
	printf "3) Do you want to create a swap file? Enter size in MiB (0 for none): [2048] "
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
}


update_mirrorlist() {
	printf '4) Do you want to update the mirrorlist? (This may take a while) [Y/n] '
	read -r updt_mirrorlist
	updt_mirrorlist="${updt_mirrorlist:-y}"
	case "$updt_mirrorlist" in
		[yY]* )
			cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.old
			reflector --latest 20 --sort rate --save /etc/pacman.d/mirrorlist
			;;
	esac
}


set_text_editor() {
	printf '5) Select text editor:\n'
	printf '[1] nano\n'
	printf '[2] neovim\n'
	printf '[3] vim\n'
	while true; do
		printf 'Enter option: [1,2,3] '
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
}


set_time_zone() {
	printf "8) Select timezone (Enter for list): "
	read -r timezone
	region=""
	while true; do
		if [ -f "/usr/share/zoneinfo/$timezone" ]; then
			printf "Confirm timezone: %s [y/N] " "$timezone"
			read -r confirm_timezone
			confirm_timezone="${confirm_timezone:-n}"
			case "$confirm_timezone" in
				[yY]* )
					break
					;;
				* )
					# clear variables to start from scratch
					timezone=""
					region=""
					;;
			esac
		elif [ "$region" != "" ] && [ -d "/usr/share/zoneinfo/$region" ]; then
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
}


set_keyboard_layout() {
	printf '9) Select keyboard layout:\n'
	printf '[1] colemak\n'
	printf '[2] de-latin1\n'
	printf '[3] us\n'
	while true; do
		printf 'Enter option: [1,2,3] '
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
}


set_hostname() {
	printf '10) Set hostname\n'
	while true; do
		printf 'Enter hostname: '
		read -r hostname
		printf "Is this hostname correct? %s [y/N] " "$hostname"
		read -r confirm_hostname
		confirm_hostname="${confirm_hostname:-n}"
		case "$confirm_hostname" in
			[yY]* )
				break
				;;
		esac
	done
}


create_initramfs() {
	if [ "$encrypt_root" = 'true' ]; then
		cp /mnt/etc/mkinitcpio.conf /mnt/etc/mkinitcpio.conf.old
		sed -i '/^HOOKS/s/ keyboard//' /mnt/etc/mkinitcpio.conf
		sed -i '/^HOOKS/s/autodetect/& keyboard keymap/' /mnt/etc/mkinitcpio.conf
		sed -i '/^HOOKS/s/block/& encrypt/' /mnt/etc/mkinitcpio.conf
	fi
	arch_chroot "mkinitcpio -P"
}


set_root_password() {
	printf '12) Set root password\n'
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
	arch_chroot "printf '%s\n%s' '$pwd_root' '$pwd_root' | passwd root"
}


add_user() {
	while true; do
		printf 'Add regular user: '
		read -r user
		printf "\nIs this username correct? %s [y/N] " "$user"
		read -r confirm_username
		confirm_username="${confirm_username:-n}"
		case "$confirm_username" in
			[yY]* )
				break
				;;
		esac
	done
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
	arch_chroot "printf '%s\n%s' '$pwd_user' '$pwd_user' | passwd $user"

	# add sudo
	arch_chroot "pacman -S --noconfirm sudo"
	sed -i '/^# %wheel ALL=(ALL:ALL) ALL/s/^# //' /mnt/etc/sudoers
}


boot_loader() {
	case "$(lscpu | grep 'Vendor ID')" in
		*AuthenticAMD* )
			microcode='amd-ucode'
			;;
		*GenuineIntel* )
			microcode='intel-ucode'
			;;
		* )
			printf "Could not find microcode for procesor. Aborting script.\n"
			exit 1
			;;
	esac
	arch_chroot "pacman -S --noconfirm $microcode grub efibootmgr"
	if [ "$encrypt_root" = 'true' ]; then
		temp="$(lsblk -d -n -o UUID "/dev/$root_partition_encrypted")"
		sed -i "/^GRUB_CMDLINE_LINUX=\"/s//&root=\/dev\/mapper\/root cryptdevice=UUID=$temp:root/" /mnt/etc/default/grub
	fi
	arch_chroot "grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB"
	arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg"
}


main_menu() {
	clear
	printf '\033[1mArchinstall https://github.com/frankebel/archinstall\033[m\n\n'
	printf ' 1) Partition and format drive\n'
	printf ' 2) Mount volumes (automatic)\n'
	printf ' 3) Create swapfile (optional)\n'
	printf ' 4) Update mirrorlist (optional)\n'
	printf ' 5) Set text editor\n'
	printf ' 6) Install essential packages (automatic)\n'
	printf ' 7) Generate fstab (automatic)\n'
	printf ' 8) Set time zone\n'
	printf ' 9) Set keyboard layout\n'
	printf '10) Set hostname\n'
	printf '11) Create initramfs (automatic)\n'
	printf '12) Set root password\n'
	printf '13) Add user and sudo (optional)\n'
	printf '14) Install boot loader GRUB (automatic)\n'
	printf '\n'
}


# main part starts here

# Pre-installation
if ! [ -d /sys/firmware/efi/efivars ]; then
	echo 'You are not in UEFI mode. Script will exit'
	exit 1
fi
## Update the system clock
timedatectl set-ntp true
## Partition the disks, Format the partitions
main_menu
format_and_partition
## Mount the file systems
main_menu
mount_volumes
main_menu
set_swap

# Installation
## Select the mirrors
main_menu
update_mirrorlist
# Install essential packages
main_menu
set_text_editor
main_menu
pacstrap /mnt base linux linux-firmware $editor

# Configure the system
## Fstab
main_menu
genfstab -U /mnt >> /mnt/etc/fstab
## Time zone
main_menu
set_time_zone
arch_chroot "ln -sf /usr/share/zoneinfo/$timezone /etc/localtime"
arch_chroot "hwclock --systohc"
## Localization
sed -i '/^#en_US.UTF-8 UTF-8/s/^#//' /mnt/etc/locale.gen
arch_chroot "locale-gen"
echo 'LANG=en_US.UTF-8' > /mnt/etc/locale.conf
main_menu
set_keyboard_layout
echo "KEYMAP=$keymap" > /mnt/etc/vconsole.conf
## Network configuration
main_menu
set_hostname
echo "$hostname" > /mnt/etc/hostname
arch_chroot "pacman -S --noconfirm networkmanager"
arch_chroot "systemctl enable --now NetworkManager"
printf "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.0.1\t%s\n" "$hostname" > /mnt/etc/hosts
## Initramfs
main_menu
create_initramfs
## Root password
main_menu
set_root_password
## add user
main_menu
printf '13) Do you want to add a user and install the sudo package? [y/N] '
read -r adduser
case "$adduser" in
	[yY]* )
		add_user
	;;
esac
## Boot loader
main_menu
boot_loader

# copy archinstall to new system
cp -r ../archinstall /mnt/root

# Reboot
if [ "$swap_size" -gt 0 ]; then
	swapoff /mnt/swapfile
fi
umount -R /mnt
if [ "$encrypt_root" = 'true' ]; then
	cryptsetup close "/dev/$root_partition"
fi

clear
main_menu
printf '\033[1mInstallation is done.\n'
