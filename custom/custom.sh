#!/bin/sh
# Set up custom installation. Run this script after base installation is done.
# Configure packages/*.txt for packages to install.

# Get hostname
host="$(hostnamectl hostname)"

# Package management

# Edit pacman.conf
sudo patch /etc/pacman.conf files/pacman.diff
sudo pacman -Syu

# Edit makepkg.conf
sudo patch /etc/makepkg.conf files/makepkg.diff

# Pacman install
cd packages || exit
# shellcheck disable=SC2024
[ -f pacman.txt ] && sudo pacman -S --needed - < pacman.txt
case "$host" in
    *desktop*)
        # shellcheck disable=SC2024
        [ -f pacman_desktop.txt ] \
            && sudo pacman -S --needed - < pacman_desktop.txt
        ;;
    *laptop*)
        # shellcheck disable=SC2024
        [ -f pacman_laptop.txt ] \
            && sudo pacman -S --needed - < pacman_laptop.txt
        ;;
esac
cd ..

# AUR install with paru
cd packages || exit
if ! [ -x /usr/bin/paru ]; then
    git clone https://aur.archlinux.org/paru.git
    cd paru || exit
    makepkg -si
    cd .. || exit
    rm -rf paru
fi
[ -f aur.txt ] && paru -S --needed - < aur.txt
case "$host" in
    *desktop*)
        [ -f aur_desktop.txt ] && paru -S --needed - < aur_desktop.txt
        ;;
    *laptop*)
        [ -f aur_laptop.txt ] && paru -S --needed - < aur_laptop.txt
        ;;
esac
cd ..

# User and group management
sudo usermod -s /bin/zsh "$USER"
sudo usermod -aG libvirt "$USER"

# Set up dotfiles

# Create directories
# Dummy directories are created for stow to symlink at the right depth.
mkdir -p ~/.config/dummy
mkdir -p ~/.local/bin/dummy
mkdir -p ~/.local/share/applications/dummy
mkdir -p ~/.local/share/gnupg/dummy
mkdir -p ~/.local/share/isync/mailbox
mkdir -p ~/.local/share/isync/tuw
mkdir -p ~/.ssh/dummy
chmod 700 ~/.local/share/gnupg
chmod 700 ~/.ssh

# Clone repo and run stow
git clone https://github.com/frankebel/dotfiles.git ~/.dotfiles
git -C ~/.dotfiles remote set-url origin git@github.com:frankebel/dotfiles.git
# Why does "~" instead of "$HOME" cause errors in stow command?
stow home --dir="$HOME/.dotfiles" --target="$HOME" home
case "$host" in
    *laptop*)
        stow home --dir="$HOME/.dotfiles" --target="$HOME" laptop
        ;;
esac

# Remove dummy directories.
rmdir ~/.config/dummy
rmdir ~/.local/bin/dummy
rmdir ~/.local/share/applications/dummy
rmdir ~/.local/share/gnupg/dummy
rmdir ~/.ssh/dummy

# Remove bash files
rm ~/.bash*

# System files

# zsh
sudo cp files/zshenv /etc/zsh/zshenv

# systemd
sudo timedatectl set-ntp true
sudo cp files/suspend@.service /etc/systemd/system/
sudo systemctl enable "suspend@$USER.service"
# user
systemctl enable --user huewarm.timer
systemctl enable --user mailsync.timer
systemctl enable --user newsboat.timer
systemctl enable --user ssh-agent.service
systemctl enable --user suspend.target
systemctl enable --user trash-empty.timer
# Device specific setup
case "$host" in
    *desktop*)
        # amdgpu-fan
        sudo cp files/amdgpu-fan.yml /etc/amdgpu-fan.yml
        sudo systemctl enable amdgpu-fan.service
        ;;
esac

# virt-manager
sudo patch /etc/libvirt/libvirtd.conf files/libvirtd.diff

# Finalize
printf '\033[1mCustom installation is done. Please reboot.\n'
