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


install_pacman() {
	if [ "$(grep '#\| ' pkglist.txt)" != '' ]; then
		printf 'Please remove comments and whitespace from pkglist.txt.\n'
		exit 1
	fi
	pacman -S --needed - < pkglist.txt
}


install_aur() {
	if [ "$(grep '#\| ' pkglist_aur.txt)" != '' ]; then
		printf 'Please remove comments and whitespace from pkglist_aur.txt.\n'
		exit 1
	fi
	sudo -u "$SUDO_USER" sh -c 'paru -S --needed - < pkglist_aur.txt'
}


install_pip() {
	if [ "$(grep '#\| ' pkglist_pip.txt)" != '' ]; then
		printf 'Please remove comments and whitespace from pkglist_pip.txt.\n'
		exit 1
	fi
	sudo -u "$SUDO_USER" pip install --user -r pkglist_pip.txt
}


install_dotfiles() {
	gitdir="/home/$SUDO_USER/.dotfiles"
	wktree="/home/$SUDO_USER"
	sudo -u "$SUDO_USER" mkdir "$gitdir"
	sudo -u "$SUDO_USER" git clone --bare https://github.com/frankebel/dotfiles.git "$gitdir"
	sudo -u "$SUDO_USER" git --git-dir="$gitdir" --work-tree="$wktree" checkout --force
	sudo -u "$SUDO_USER" git --git-dir="$gitdir" --work-tree="$wktree" config status.showUntrackedFiles no
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
install_pacman

# install aur helper paru
sudo -u "$SUDO_USER" git clone https://aur.archlinux.org/paru.git
cd paru || exit
sudo -u "$SUDO_USER" makepkg -si
cd .. || exit
rm -rf paru

install_aur
install_pip

install_dotfiles

# user and group management
usermod -aG lp video "$SUDO_USER" # video group for light package
usermod -s /bin/zsh "$SUDO_USER"

# create directories
sudo -u "$SUDO_USER" mkdir -p "/home/$SUDO_USER/Data"
sudo -u "$SUDO_USER" mkdir -p "/home/$SUDO_USER/Temp/Torrents"
sudo -u "$SUDO_USER" mkdir -p "/home/$SUDO_USER/.local/share/pass"
sudo -u "$SUDO_USER" mkdir -p "/home/$SUDO_USER/.local/share/isync/mailbox"
sudo -u "$SUDO_USER" mkdir -p "/home/$SUDO_USER/.local/share/isync/tuw"
