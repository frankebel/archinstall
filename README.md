# archinstall

My script for a base installation of [Arch Linux](https://archlinux.org).

```sh
loadkeys colemak
pacman -Sy archlinux-keyring git
git clone https://github.com/frankebel/archinstall.git
cd archinstall
```

Set parameters at the beginning of `install.sh`, then run file with:

```sh
./install.sh
```
