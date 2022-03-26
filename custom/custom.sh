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
user="$(pwd | awk -F "/" '{print $3}')"

edit_pacman
edit_makepkg
pacman -S --needed - < pkglist.txt

# install aur helper paru
sudo -u "$user" git clone https://aur.archlinux.org/paru.git
cd paru || exit
sudo -u "$user" makepkg -si
cd .. || exit
rm -rf paru

sudo -u "$user" paru -S --needed - < pkglist_aur.txt
