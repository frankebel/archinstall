#!/bin/sh

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

cp -r ../archinstall /mnt/root
