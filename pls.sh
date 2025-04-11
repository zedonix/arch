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
parted -s "$disk" mklabel gpt

# Convert swap size to MiB
swap="8"
swap_mib=$((swap * 1024))

# Partition Layout
parted -s "$disk" mkpart ESP fat32 1MiB 1025MiB
parted -s "$disk" set 1 esp on
parted -s "$disk" mkpart primary linux-swap 1025MiB $((1025 + swap_mib))MiB
parted -s "$disk" mkpart primary ext4 $((1025 + swap_mib))MiB 100%

# Formatting
mkfs.fat -F32 -n BOOT "${disk}1"
mkswap -L SWAP "${disk}2"
mkfs.ext4 -L ROOT "${disk}3"

# Mounting
mount "${disk}3" /mnt
mkdir -p /mnt/boot
mount "${disk}1" /mnt/boot
swapon "${disk}2"

# Base Installation
install_pkgs=(
    base linux linux-firmware sudo intel-ucode 
    networkmanager pipewire wireplumber xorg-xwayland
    clamav inotify-tools libnotify sqlite pipewire-pulse
    ntfs-3g exfat-utils man-db man-pages 
    openssh neovim unzip unrar zip gzip 
    htop fastfetch bat eza fd fzf git 
    newsboat ripgrep xdg-desktop-portal-wlr 
    xdg-desktop-portal-gtk papirus-icon-theme 
    sway swaybg swayimg swaylock swayidle 
    chromium foot mako mpv fuzzel tmux 
    qemu-full libvirt virt-manager texlive-latex texlive-bin
    zathura wl-clipboard cliphist mtools dosfstools
    grim slurp thunar gimp asciinema yt-dlp 
    lua python clang ttc-iosevka seatd go
    noto-fonts xdg-utils xdg-desktop-portal
    noto-fonts-cjk noto-fonts-emoji polkit
)

# Update the package manager and install the base system
pacstrap /mnt "${install_pkgs[@]}"

# System Configuration
genfstab -U /mnt >> /mnt/etc/fstab

# Run commands in the chroot
arch-chroot /mnt /bin/bash -c "
    # Configuration
    timezone=\"Asia/Kolkata\"
    hostname=\"archlinux\"

    echo \"root passwd\"
    passwd

    read -p \"Username: \" user
    if [[ -z \"\$user\" ]]; then
        echo \"Error: Username cannot be empty\"
        exit 1
    fi

    # User Setup
    useradd -m -G wheel,storage,power,video,audio -s /bin/bash \"\$user\"
    echo \"Set password for \$user:\"
    passwd \"\$user\"

    # Local Setup
    ln -sf \"/usr/share/zoneinfo/\$timezone\" /etc/localtime
    hwclock --systohc
    sed -i \"/en_US.UTF-8/s/^#//\" /etc/locale.gen
    locale-gen
    echo \"LANG=en_US.UTF-8\" > /etc/locale.conf

    # Sudo Configuration
    echo \"%wheel ALL=(ALL) ALL\" > /etc/sudoers.d/wheel

    # Host Configuration
    echo \"\$hostname\" > /etc/hostname
    echo \"127.0.0.1  localhost\" > /etc/hosts
    echo \"::1        localhost\" >> /etc/hosts
    echo \"127.0.1.1  \$hostname.localdomain  \$hostname\" >> /etc/hosts

    # Bootloader
    pacman -S --noconfirm grub efibootmgr
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg

    # Services
    systemctl enable NetworkManager

    # Clean up package cache and Wrapping up
    pacman -Scc --noconfirm
"

# Unmount and finalize
umount -lR /mnt
echo "Installation completed. Please reboot your system."
