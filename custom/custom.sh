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


edit_grub() {
	cp /etc/default/grub /etc/default/grub.old
	sed -i '/^GRUB_DEFAULT/c\GRUB_DEFAULT=saved' /etc/default/grub
	sed -i '/^GRUB_DEFAULT/a GRUB_SAVEDEFAULT=true' /etc/default/grub
	sed -i '/^GRUB_TIMEOUT/c\GRUB_TIMEOUT=1' /etc/default/grub
	grub-mkconfig -o /boot/grub/grub.cfg
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

pacman -S --noconfirm archlinux-keyring
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
sudo -u "$SUDO_USER" mkdir -p "/home/$SUDO_USER/.cache/zsh"
sudo -u "$SUDO_USER" mkdir -p "/home/$SUDO_USER/.local/share/gnupg"
chmod 700 "/home/$SUDO_USER/.local/share/gnupg"
sudo -u "$SUDO_USER" mkdir -p "/home/$SUDO_USER/.local/share/pass"
sudo -u "$SUDO_USER" mkdir -p "/home/$SUDO_USER/.local/share/isync/mailbox"
sudo -u "$SUDO_USER" mkdir -p "/home/$SUDO_USER/.local/share/isync/tuw"

# themes
sudo -u "$SUDO_USER" git clone https://github.com/dracula/gtk.git "/home/$SUDO_USER/.themes/Dracula"

# configure and regenerate grub
edit_grub

# remove bash files
rm /home/"$SUDO_USER"/.bash*

# systemd units
cp files/suspend@.service /etc/systemd/system/
systemctl enable "suspend@$SUDO_USER.service"
sudo -u "$SUDO_USER" systemctl enable --user "/home/$SUDO_USER/.config/systemd/user/mbsync.timer"
case "$(cat /etc/hostname)" in
	*"desktop"* )
		cp files/amdgpu-fan.yml /etc/amdgpu-fan.yml
		systemctl enable amdgpu-fan.service
		;;
esac
