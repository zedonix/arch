#!/bin/bash
set -euo pipefail

# Configuration
timezone="Asia/Kolkata"
localization="en_US.UTF-8"
hostname="archlinux"
swap_size="8GiB"

# total_bytes=$(blockdev --getsize64 "$disk")
# swap_end=$((total_bytes - 8*1024*1024*1024))
# swap_end_mib=$((swap_end / 1048576))
# parted -s "$disk" mkpart primary ext4 512MiB ${swap_end_mib}MiB
# parted -s "$disk" mkpart primary linux-swap ${swap_end_mib}MiB 100%

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

read -p "Username: " user
if [[ -z "$user" ]]; then
    echo "Error: Username cannot be empty"
    exit 1
fi

# Partitioning
echo "Wiping $disk - ALL DATA WILL BE LOST!"
parted -s "$disk" mklabel gpt

# Partition Layout
parted -s "$disk" mkpart ESP fat32 1MiB 512MiB
parted -s "$disk" set 1 esp on
parted -s "$disk" mkpart primary ext4 512MiB -"$swap_size"
parted -s "$disk" mkpart primary linux-swap -"$swap_size" 100%

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
    base linux linux-firmware intel-ucode 
    networkmanager pipewire wireplumber 
    clamav inotify-tools libnotify sqlite
    ntfs-3g exfat-utils man-db man-pages 
    openssh neovim unzip unrar zip gzip 
    htop fastfetch bat eza fd fzf git 
    newsboat ripgrep xdg-desktop-portal-wlr 
    xdg-desktop-portal-gtk papirus-icon-theme 
    sway swaybg swayimg swaylock swayidle 
    chromium foot mako mpv rofi tmux 
    zathura wl-clipboard wl-clip-persist 
    cliphist slurp pcmanfm gimp virt-manager 
    qemu-full libvirt asciinema yt-dlp 
    lua python clang ttc-iosevka 
    ttf-iosevkaterm-nerd noto-fonts 
    noto-fonts-cjk noto-fonts-emoji 
    texlive-latex texlive-bin
)
pacman -S reflector
reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
pacstrap /mnt "${install_pkgs[@]}"

# System Configuration
genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
arch-chroot /mnt hwclock --systohc
arch-chroot /mnt sed -i "/$localization/s/^#//" /etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=$localization" > /mnt/etc/locale.conf

# User Setup
arch-chroot /mnt useradd -m -G wheel,storage,power,video,audio -s /bin/bash "$user"
echo "Set password for $user:"
arch-chroot /mnt passwd "$user"

# Sudo Configuration
echo "%wheel ALL=(ALL) ALL" > /mnt/etc/sudoers.d/wheel
chmod 440 /mnt/etc/sudoers.d/wheel

# Host Configuration
echo "$hostname" > /mnt/etc/hostname
cat > /mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain $hostname
EOF

# Bootloader
arch-chroot /mnt pacman -S --noconfirm grub efibootmgr
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Services
arch-chroot /mnt systemctl enable NetworkManager
arch-chroot /mnt pacman -Scc --noconfirm

# Finalization
echo "Set root password:"
arch-chroot /mnt passwd

umount -R /mnt
swapoff -a
echo "Installation complete! Reboot and remove installation media."
