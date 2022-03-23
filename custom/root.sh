#!/bin/bash

# edit /etc/pacman.conf
cp /etc/pacman.conf /etc/pacman.conf.old
sed -i '/^#Color/s/^#//' /etc/pacman.conf
sed -i '/^#VerbosePkgLists/s/^#//' /etc/pacman.conf
sed -i '/^#ParallelDownloads/c\ParallelDownloads = 8' /etc/pacman.conf
sed -i '/^ParallelDownloads/a ILoveCandy' /etc/pacman.conf
sed -i '/^#\[multilib\]/s/^#//' /etc/pacman.conf
sed -i '/^\[multilib\]/{n;s/^#//;}' /etc/pacman.conf
pacman -Sy
