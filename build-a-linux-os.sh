#!/bin/bash

set -u

function printLatestStableLinuxKernelVersion {
  unparsedStableKernel=$(curl -s https://www.kernel.org/ | tr -d '[:space:]' | grep -Po '<td>stable:</td><td><strong>[0-9]+.[0-9]+.[0-9]+</strong></td>')
  currentKernel=$(echo $unparsedStableKernel | grep -Po '[0-9]+.[0-9]+.[0-9]+')
  echo $currentKernel
}

dir="$PWD"
MOUNT_PATH="$PWD/imagesd"
IMAGE_FILE_PATH="$PWD/image.img"
KERNEL_VERSION=$(printLatestStableLinuxKernelVersion)

echo "Latest kernel version: $KERNEL_VERSION"

function setup {
  # Download GNU keyring to verify GNU utilities
  curl -OL https://ftp.gnu.org/gnu/gnu-keyring.gpg
  ls -la
}

function kernel {
  # Download kernel source, verify source, & build kernel
  export INSTALL_PATH="/mnt/os/boot"
  curl -OL "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-$KERNEL_VERSION.tar.xz"
  curl -OL "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-$KERNEL_VERSION.tar.sign"
  gpg2 --locate-keys torvalds@kernel.org gregkh@kernel.org
  gpg2 --verify "linux-$KERNEL_VERSION.tar.sign"
  unxz "linux-$KERNEL_VERSION.tar.xz"
  gpg2 --verify "linux-$KERNEL_VERSION.tar.sign" "linux-$KERNEL_VERSION.tar"
  tar -xf "linux-$KERNEL_VERSION.tar"
  cd "linux-$KERNEL_VERSION"
  make --quiet ARCH=x86_64 defconfig
  make --quiet -j $(nproc)
  make --quiet modules_install
  make --quiet install
}

# Create a directory for the final image & setup
# using "Filesystem Hierarchy Standard" as a guide, creating
# just the required directories for now.
function create_file_system {
  mkdir -vp $MOUNT_PATH
  mkdir -vp $MOUNT_PATH/{bin,boot,dev,etc,lib,media,mnt,opt,run,sbin,srv,tmp,var}
  mkdir -vp $MOUNT_PATH/etc/opt
  mkdir -vp $MOUNT_PATH/usr/{bin,lib,sbin,share,include}
  mkdir -vp $MOUNT_PATH/usr/local/{bin,etc,games,include,lib,man,sbin,share,src}
}

# glibc: Download, build, & install
function add_glibc {
  cd $PWD
  curl -OL http://ftp.wayne.edu/gnu/libc/glibc-2.30.tar.xz.sig
  curl -OL http://ftp.wayne.edu/gnu/libc/glibc-2.30.tar.xz
  gpg2 --verify --keyring ./gnu-keyring.gpg glibc-2.30.tar.xz.sig
  gpg2 --verify --keyring ./gnu-keyring.gpg glibc-2.30.tar.xz.sig glibc-2.30.tar.xz
  tar -xf glibc-2.30.tar.xz
  cd glibc-2.30
  mkdir "$PWD/glibcbuild"
  cd "$PWD/glibcbuild"
  "$dir/glibc-2.30/configure" --prefix="$MOUNT_PATH/usr"
  make --quiet
  make --quiet install 
}

# GNU Coreutils: Download, build, & install
function add_coreutils {
  cd $PWD
  curl -OL https://ftp.gnu.org/gnu/coreutils/coreutils-8.31.tar.xz.sig
  curl -OL https://ftp.gnu.org/gnu/coreutils/coreutils-8.31.tar.xz
  gpg2 --verify --keyring ./gnu-keyring.gpg coreutils-8.31.tar.xz.sig
  gpg2 --verify --keyring ./gnu-keyring.gpg coreutils-8.31.tar.xz.sig coreutils-8.31.tar.xz
  tar xf coreutils-8.31.tar.xz
  cd "$dir/coreutils-8.31"
  ./configure --prefix="$MOUNT_PATH"
  make --quiet
  make --quiet install
}

# systemd: Download, build, & install
function add_systemd {
  cd $PWD
  curl -OL https://github.com/systemd/systemd/archive/v243.tar.gz
  tar xf v243.tar.gz
  cd systemd-243
  ./configure
  make --quiet
  make --quiet install DESTDIR="$MOUNT_PATH"
}

# Download & Build Bash
function add_bash {
  cd $PWD
  curl -OL https://ftp.gnu.org/gnu/bash/bash-5.0.tar.gz
  curl -OL https://ftp.gnu.org/gnu/bash/bash-5.0.tar.gz.sig
  gpg2 --verify --keyring ./gnu-keyring.gpg bash-5.0.tar.gz.sig
  gpg2 --verify --keyring ./gnu-keyring.gpg bash-5.0.tar.gz.sig bash-5.0.tar.gz
  tar xf bash-5.0.tar.gz
  cd bash-5.0
  ./configure --prefix="$MOUNT_PATH"
  make --quiet
  make --quiet install
}

curl -OL https://ftp.gnu.org/gnu/gnu-keyring.gpg

dd if=/dev/zero of=os.img bs=1M count=512
first_unused_loop_device=$(sudo losetup -f)
sudo mkfs.ext4 os.img
sudo losetup -P $first_unused_loop_device os.img
sudo parted -s $first_unused_loop_device mktable gpt
sudo parted -s $first_unused_loop_device mkpart primary fat32 1MiB 261MiB 
sudo parted -s $first_unused_loop_device set 1 esp on
sudo parted -s $first_unused_loop_device mkpart primary ext4 261MiB 100%
sudo mkdir -p /mnt/os/efi
sudo mkdir -p /mnt/os/boot

sudo mkfs.fat ${first_unused_loop_device}p1
sudo mkfs.ext4 ${first_unused_loop_device}p2

sudo mount ${first_unused_loop_device}p1 /mnt/os/efi
sudo mount ${first_unused_loop_device}p2 /mnt/os/boot

mkdir -vp /mnt/os/boot
mkdir -vp /mnt/os/boot/{bin,boot,dev,etc,lib,media,mnt,opt,run,sbin,srv,tmp,var}
mkdir -vp /mnt/os/boot/etc/opt
mkdir -vp /mnt/os/boot/usr/{bin,lib,sbin,share,include}
mkdir -vp /mnt/os/boot/usr/local/{bin,etc,games,include,lib,man,sbin,share,src}

kernel

sudo grub-install --target=x86_64-efi --efi-directory=/mnt/os --bootloader-id=GRUB

sudo umount /mnt/os/efi
sudo umount /mnt/os/boot
sudo losetup -d $first_unused_loop_device
