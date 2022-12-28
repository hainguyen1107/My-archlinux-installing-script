#!/usr/bin/env bash

set -e

# clean disk
sgdisk -Z /dev/sda
wipefs -a /dev/sda

# connect wifi
# iwctl --passphrase="hainguyen1107" station "wlan0" connect "Tho Bay Mau 5G"
# sleep 10
ping -c 3 8.8.8.8

# Disable reflector
systemctl disable reflector.service
systemctl disable reflector.timer
systemctl stop reflector.service
systemctl stop reflector.timer

# Update machine time to internet time
timedatectl set-ntp true

# setup mirror
printf "Server = http://mirror.bizflycloud.vn/archlinux/\$repo/os/\$arch\n" > /etc/pacman.d/mirrorlist

# make partitions
sgdisk -n 0:0:+550M -t 0:ef00 -c 0:"esp" /dev/sda
sgdisk -n 0:0:+550M -t 0:ea00 -c 0:"XBOOTLDR" /dev/sda
sgdisk -n 0:0:+20G -t 0:8200 -c 0:"swap" /dev/sda
sgdisk -n 0:0:0 -t 0:8304 -c 0:"root" /dev/sda

# clean partition signature
wipefs -a /dev/sda1
wipefs -a /dev/sda2
wipefs -a /dev/sda3
wipefs -a /dev/sda4

# format partitions
mkfs.vfat -F32 /dev/sda1
mkfs.vfat -F32 /dev/sda2
mkswap /dev/sda3
swapon /dev/sda3
mkfs.ext4 /dev/sda4

# mount partition
mount /dev/sda4 /mnt
mkdir -p /mnt/efi
mkdir -p /mnt/boot
mount /dev/sda1 /mnt/efi
mount /dev/sda2 /mnt/boot

# instal base system
pacstrap /mnt base base-devel linux linux-headers linux-firmware man-pages man-db iptables-nft

# generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# configure timezone
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime
arch-chroot /mnt hwclock --systohc

# configure localization
printf "en_US.UTF-8 UTF-8\n" > /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
printf "LANG=en_US.UTF-8\n" > /mnt/etc/locale.conf

# configure network
printf "dopamine\n" > /mnt/etc/hostname
printf "127.0.0.1\tlocalhost\n" >> /mnt/etc/hosts
printf "::1\tlocalhost\n" >> /mnt/etc/hosts
printf "127.0.0.1\tdopamine.localdomain\tdopamine\n" >> /mnt/etc/hosts
arch-chroot /mnt pacman -Syu --needed --noconfirm networkmanager
arch-chroot /mnt systemctl enable NetworkManager

# set user
echo -e "123\n123" | arch-chroot /mnt passwd

# add new user
arch-chroot /mnt useradd -G wheel,audio,lp,optical,storage,disk,video,power -s /bin/bash -m serotonin -d /home/serotonin -c "Acetylcholine"

# new user password
echo -e "123\n123" | arch-chroot /mnt passwd "serotonin"

# install bootloader
arch-chroot /mnt pacman -Syu --needed --noconfirm efibootmgr intel-ucode
arch-chroot /mnt bootctl --esp-path=/efi --boot-path=/boot install
echo "default archlinux" > /mnt/efi/loader/loader.conf
echo "timeout 5" >> /mnt/efi/loader/loader.conf
echo "console-mode keep" >> /mnt/efi/loader/loader.conf
echo "editor no" >> /mnt/efi/loader/loader.conf

echo "title Arch Linux" > /mnt/boot/loader/entries/archlinux.conf
echo "linux /vmlinuz-linux" >> /mnt/boot/loader/entries/archlinux.conf
echo "initrd /intel-ucode.img" >> /mnt/boot/loader/entries/archlinux.conf
echo "initrd /initramfs-linux.img" >> /mnt/boot/loader/entries/archlinux.conf

rootuuidvalue=$(arch-chroot /mnt blkid -s UUID -o value /dev/sda4)
echo "options root=UUID=${rootuuidvalue} rw" >> /mnt/boot/loader/entries/archlinux.conf

# set audio
arch-chroot /mnt pacman -Syu --needed --noconfirm pipewire pipewire-pulse pipewire-alsa alsa-utils xdg-desktop-portal-gtk gst-plugin-pipewire wireplumber
arch-chroot -u serotonin /mnt mkdir -p /home/serotonin/.config/pipewire
arch-chroot -u serotonin /mnt cp -r /usr/share/pipewire /home/serotonin/.config/
arch-chroot -u serotonin /mnt sed -i '/resample.quality/s/#//; /resample.quality/s/4/15/' \
     /home/serotonin/.config/pipewire/{client.conf,pipewire-pulse.conf}

# install graphic drivers
arch-chroot /mnt pacman -Syu --needed --noconfirm vulkan-icd-loader vulkan-intel intel-media-driver mesa ocl-icd intel-compute-runtime libva-utils nvidia nvidia-prime

# install DE
arch-chroot /mnt pacman -Syu --needed --noconfirm xorg-server baobab eog file-roller gdm gnome-calculator gnome-calendar gnome-characters gnome-clocks gnome-color-manager gnome-control-center gnome-font-viewer gnome-keyring gnome-screenshot gnome-shell-extensions gnome-system-monitor gnome-terminal gnome-themes-extra gnome-video-effects nautilus sushi gnome-tweaks totem xdg-user-dirs-gtk gnome-usage gnome-todo gnome-shell-extension-appindicator alacarte gedit gedit-plugins
arch-chroot /mnt systemctl enable gdm

# enable sudoer right for new user
linum=$(arch-chroot /mnt sed -n "/^# %wheel ALL=(ALL:ALL) ALL$/=" /etc/sudoers)
arch-chroot /mnt sed -i "${linum}s/^# //" /etc/sudoers # uncomment line

# install yay
arch-chroot -u serotonin  /mnt mkdir /home/serotonin/tmp
arch-chroot -u serotonin  /mnt curl -LJo /home/serotonin/tmp/yay.tar.gz https://aur.archlinux.org/cgit/aur.git/snapshot/yay.tar.gz
arch-chroot -u serotonin  /mnt tar -xvf /home/serotonin/tmp/yay.tar.gz -C /home/serotonin/tmp
arch-chroot -u serotonin  /mnt bash -c "printf \"123\" | sudo -S -i;
    export GOCACHE="/home/serotonin/.cache/go-build";
    cd /home/serotonin/tmp/yay;
    makepkg -sri --noconfirm"

# enable multilib
linum=$(arch-chroot /mnt sed -n "/\\[multilib\\]/=" /etc/pacman.conf)
arch-chroot /mnt sed -i "${linum}s/^#//" /etc/pacman.conf
((linum++))
arch-chroot /mnt sed -i "${linum}s/^#//" /etc/pacman.conf

# install aur packages
arch-chroot -u bash -c "printf \"123\" | sudo -S -i;
    export HOME=\"/home/serotonin\";
    yay -Syu --needed --noconfirm ferdium dropbox deluge google-chrome goldendict libreoffice-fresh keepassxc mpv okular steam steam-native-runtime ttf-ms-win10-auto vscodium-bin zsh zsh-completions zsh-syntax-highlighting zsh-theme-powerlevel10k-git oh-my-zsh-git ibus-bamboo"

# install ibus-bamboo
ibus restart
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('ibus', 'Bamboo')]"
gsettings set org.gnome.desktop.interface gtk-im-module "'ibus'"
