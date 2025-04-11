#!/bin/bash
set -euo pipefail

# Disk Selection
echo "Available disks:"
lsblk
read -p "Enter Disk: " disk
disk="/dev/${disk%/}"

# Input Validation
if [[ ! -b "$disk" ]]; then
    echo "Error: $disk is not a valid block device"
    exit 1
fi

# Partitioning
echo "Wiping $disk - ALL DATA WILL BE LOST!"
wipefs -a ${disk}
parted -s "$disk" mklabel gpt

# Convert swap size to MiB
swap_size="8"
swap_size_mib=$((swap_size * 1024))

# Partition Layout
parted -s "$disk" mkpart ESP fat32 1MiB 512MiB
parted -s "$disk" set 1 esp on
parted -s "$disk" mkpart primary ext4 512MiB -8GiB
parted -s "$disk" mkpart primary linux-swap -8GiB 100%

# Formatting
mkfs.fat -F32 -n BOOT "${disk}1"
mkfs.ext4 -L ROOT "${disk}2"
mkswap -L SWAP "${disk}3"

# Mounting
mount "${disk}2" /mnt
mkdir -p /mnt/boot
mount "${disk}1" /mnt/boot
swapon "${disk}3"

# Base Installation
install_pkgs=(
    base linux linux-firmware sudo intel-ucode 
    networkmanager pipewire wireplumber xorg-xwayland
    clamav inotify-tools libnotify sqlite
    ntfs-3g exfat-utils man-db man-pages 
    openssh neovim unzip unrar zip gzip 
    htop fastfetch bat eza fd fzf git 
    newsboat ripgrep xdg-desktop-portal-wlr 
    xdg-desktop-portal-gtk papirus-icon-theme 
    sway swaybg swayimg swaylock swayidle 
    chromium foot mako mpv rofi-wayland tmux 
    zathura wl-clipboard wl-clip-persist 
    cliphist slurp pcmanfm gimp asciinema yt-dlp 
    lua python clang ttc-iosevka seatd go
    ttf-iosevkaterm-nerd noto-fonts xdg-utils
    noto-fonts-cjk noto-fonts-emoji polkit
)

# Update the package manager and install the base system
pacstrap /mnt "${install_pkgs[@]}"

# System Configuration
genfstab -U /mnt >> /mnt/etc/fstab

# Run commands in the chroot
arch-chroot /mnt
