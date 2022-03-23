#!/bin/sh


edit_pacman() {
	cp /etc/pacman.conf /etc/pacman.conf.old
	sed -i '/^#Color/s/^#//' /etc/pacman.conf
	sed -i '/^#VerbosePkgLists/s/^#//' /etc/pacman.conf
	sed -i '/^#ParallelDownloads/c\ParallelDownloads = 8' /etc/pacman.conf
	sed -i '/^ParallelDownloads/a ILoveCandy' /etc/pacman.conf
	sed -i '/^#\[multilib\]/s/^#//' /etc/pacman.conf
	sed -i '/^\[multilib\]/{n;s/^#//;}' /etc/pacman.conf
	pacman -Sy
}


edit_makepkg() {
	cp /etc/makepkg.conf /etc/makepkg.conf.old
	sed -i '/^#MAKEFLAGS/c\MAKEFLAGS="-j8"' /etc/makepkg.conf
}


set_user() {
	while true; do
		printf 'Enter username: '
		read -r username
		if ! [ -d "/home/$username" ]; then
			continue
		fi
		printf "Confirm username: %s [y/N] " "$username"
		read -r confirm_username
		confirm_username="${confirm_username:-n}"
		case "$confirm_username" in
			[yY]* )
				break
				;;
		esac
	done
}


# main part starts here
# warning
printf "\e[1;31mDo not execute this script without knowing what it does.\e[0m Continue? [y/N] "
read -r yn
case "$yn" in
	[yY]* )
		;;
	* )
		exit 0
		;;
esac

edit_pacman
edit_makepkg

# install aur helper paru
sudo -u "$user" git clone https://aur.archlinux.org/paru.git
sudo -u "$user" cd paru
sudo -u "$user" makepkg -si
