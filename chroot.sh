# Configuration
timezone="Asia/Kolkata"
hostname="archlinux"

echo "root passwd"
passwd

read -p "Username: " user
if [[ -z "$user" ]]; then
    echo "Error: Username cannot be empty"
    exit 1
fi

# User Setup
useradd -m -G wheel,storage,power,video,audio -s /bin/bash "$user"
echo "Set password for $user:"
passwd "$user"

# Local Setup
ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
hwclock --systohc
sed -i "/en_US.UTF-8/s/^#//" /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Sudo Configuration
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel

# Host Configuration
echo "${hostname}" > /etc/hostname
echo "127.0.0.1  localhost" > /etc/hosts
echo "::1        localhost" >> /etc/hosts
echo "127.0.1.1  ${hostname}.localdomain  ${hostname}" >> /etc/hosts

# Bootloader
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Services
systemctl enable NetworkManager

# Clean up package cache
arch-chroot /mnt pacman -Scc --noconfirm

# Finalization
echo "Set root password:"
arch-chroot /mnt passwd

exit

echo "type umount -lR /mnt"
