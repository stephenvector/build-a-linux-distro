#!/bin/bash

set -e

export PATH=~/.local/bin:$PATH

curl -OL https://ftp.gnu.org/gnu/gnu-keyring.gpg

function printLatestStableLinuxKernelVersion {
  unparsedStableKernel=$(curl -s https://www.kernel.org/ | tr -d '[:space:]' | grep -Po '<td>stable:</td><td><strong>[0-9]+.[0-9]+.[0-9]+</strong></td>')
  currentKernel=$(echo $unparsedStableKernel | grep -Po '[0-9]+.[0-9]+.[0-9]+')
  echo $currentKernel
}

SYSTEMD_VERSION="245"
COREUTILS_VERSION="8.32"

dir="$PWD"
KERNEL_VERSION=$(printLatestStableLinuxKernelVersion)
OS_ROOT_DIR=${dir}/mnt/os
EFI_MOUNT_DIR=${OS_ROOT_DIR}/efi
BOOT_MOUNT_DIR=${OS_ROOT_DIR}/boot

dd if=/dev/zero of=os.img bs=1M count=32

first_unused_loop_device=$(sudo losetup -f)

mkfs.ext4 os.img

sudo losetup -P $first_unused_loop_device os.img
sudo parted -s $first_unused_loop_device mktable gpt
sudo parted -s $first_unused_loop_device mkpart primary fat32 1MiB 16MiB 
sudo parted -s $first_unused_loop_device set 1 esp on
sudo parted -s $first_unused_loop_device mkpart primary ext4 16MiB 100%

mkdir -p $EFI_MOUNT_DIR
mkdir -p $BOOT_MOUNT_DIR

mkfs.fat ${first_unused_loop_device}p1
mkfs.ext4 ${first_unused_loop_device}p2

sudo mount ${first_unused_loop_device}p1 -o loop $EFI_MOUNT_DIR
sudo mount ${first_unused_loop_device}p2 -o loop $BOOT_MOUNT_DIR

# Create a directory for the final image & setup
# using "Filesystem Hierarchy Standard" as a guide, creating
# just the required directories for now.
mkdir -vp ${BOOT_MOUNT_DIR}/{bin,boot,dev,etc,lib,media,mnt,opt,run,sbin,srv,tmp,var}
mkdir -vp ${BOOT_MOUNT_DIR}/etc/opt
mkdir -vp ${BOOT_MOUNT_DIR}/usr/{bin,lib,sbin,share,include}
mkdir -vp ${BOOT_MOUNT_DIR}/usr/local/{bin,etc,games,include,lib,man,sbin,share,src}
mkdir -vp ${BOOT_MOUNT_DIR}/boot/grub

# Download kernel source, verify source, & build kernel
export INSTALL_PATH=$OS_ROOT_DIR
curl -OL "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-$KERNEL_VERSION.tar.xz"
curl -OL "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-$KERNEL_VERSION.tar.sign"
gpg2 --locate-keys torvalds@kernel.org gregkh@kernel.org
gpg2 --verify "linux-$KERNEL_VERSION.tar.sign"
unxz "linux-$KERNEL_VERSION.tar.xz"
gpg2 --verify "linux-$KERNEL_VERSION.tar.sign" "linux-$KERNEL_VERSION.tar"
tar -xf "linux-$KERNEL_VERSION.tar"
cd "linux-$KERNEL_VERSION"
make mrproper
make ARCH=x86_64 defconfig
make -j $(nproc)
make modules_install
make install
cp -iv arch/x86_64/boot/bzImage ${BOOT_MOUNT_DIR}/boot/vmlinuz
cd ..
  
# glibc: Download, build, & install
curl -OL http://ftp.wayne.edu/gnu/libc/glibc-2.30.tar.xz.sig
curl -OL http://ftp.wayne.edu/gnu/libc/glibc-2.30.tar.xz
gpg2 --verify --keyring ./gnu-keyring.gpg glibc-2.30.tar.xz.sig
gpg2 --verify --keyring ./gnu-keyring.gpg glibc-2.30.tar.xz.sig glibc-2.30.tar.xz
tar -xf glibc-2.30.tar.xz
cd ./glibc-2.30
./configure --prefix="${BOOT_MOUNT_DIR}/usr/local" --enable-kernel $KERNEL_VERSION
make
make install
cd ..

# GNU Coreutils: Download, build, & install
curl -OL https://ftp.gnu.org/gnu/coreutils/coreutils-${COREUTILS_VERSION}.tar.xz.sig
curl -OL https://ftp.gnu.org/gnu/coreutils/coreutils-${COREUTILS_VERSION}.tar.xz
gpg2 --verify --keyring ./gnu-keyring.gpg coreutils-${COREUTILS_VERSION}.tar.xz.sig
gpg2 --verify --keyring ./gnu-keyring.gpg coreutils-${COREUTILS_VERSION}.tar.xz.sig coreutils-${COREUTILS_VERSION}.tar.xz
tar xf coreutils-${COREUTILS_VERSION}.tar.xz
cd "$./coreutils-$COREUTILS_VERSION}"
./configure --prefix="$OS_ROOT_DIR"
make
make install
cd ..

# Download & Build Bash
curl -OL https://ftp.gnu.org/gnu/bash/bash-5.0.tar.gz
curl -OL https://ftp.gnu.org/gnu/bash/bash-5.0.tar.gz.sig
gpg2 --verify --keyring ./gnu-keyring.gpg bash-5.0.tar.gz.sig
gpg2 --verify --keyring ./gnu-keyring.gpg bash-5.0.tar.gz.sig bash-5.0.tar.gz
tar xf bash-5.0.tar.gz
cd bash-5.0
./configure --prefix="$OS_ROOT_DIR"
make
make install
cd ..

# systemd: Download, build, & install
curl -OL https://github.com/systemd/systemd/archive/v${SYSTEMD_VERSION}.tar.gz
tar xf v${SYSTEMD_VERSION}.tar.gz
cd systemd-${SYSTEMD_VERSION}
mkdir build
meson build/ && ninja -C build
sudo ninja install DESTDIR="$MOUNT_PATH"
cd ..

sudo grub-install --target=x86_64-efi --efi-directory=${EFI_MOUNT_DIR} --bootloader-id=GRUB

# Get the uuid of each partition
p1uuid=$(lsblk ${first_unused_loop_device}p1 -no UUID)
p2uuid=$(lsblk ${first_unused_loop_device}p2 -no UUID)

# Create fstab file
cat > ${BOOT_MOUNT_DIR}/etc/fstab << "EOF"
UUID=$p2uuid /boot           ext4    defaults        0       2
UUID=$p1uuid /boot/efi       vfat    umask=0077      0       1
EOF

sudo grub-mkconfig -o ${BOOT_MOUNT_DIR}/grub/grub.cfg

sudo cat ${BOOT_MOUNT_DIR}/grub/grub.cfg

# Unmount boot & efi directories
sudo umount $EFI_MOUNT_DIR
sudo umount $BOOT_MOUNT_DIR

# Free up the loop device
sudo losetup -d $first_unused_loop_device
