# archinstall
My Script for installing Arch Linux.

## Base install:
```sh
loadkeys colemak
pacman -Sy git
git clone https://github.com/frankebel/archinstall.git
cd archinstall
```
Set parameters at the beginning of `install.sh`, then run file with:
```sh
./install.sh
```

## Custom install (optional)
Reboot into the new system after the base installation and run:
```sh
git clone https://github.com/frankebel/archinstall.git
cd archinstall/custom
```
Set packages in `*.txt` if necessary, then run file with:
```sh
./custom.sh
```
Suggestions when asked for packages:
- jack: `pipewire-jack`
- pipewire-session-manager: `wireplumber`
- vulkan-driver: on AMD use `vulkan-radeon`
