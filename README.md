# archinstall
My Script for installing Arch Linux.

## Base install:
```sh
loadkeys colemak
pacman -Sy git
git clone https://github.com/frankebel/archinstall.git
cd archinstall
./install.sh
```

## Custom install
```sh
git clone https://github.com/frankebel/archinstall.git
cd archinstall/custom
```

edit pkglist*.txt to your liking

```sh
sudo ./custom.sh
```
