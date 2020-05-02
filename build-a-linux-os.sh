#!/bin/bash

curl -OL https://ftp.gnu.org/gnu/gnu-keyring.gpg

function printLatestStableLinuxKernelVersion {
  unparsedStableKernel=$(curl -s https://www.kernel.org/ | tr -d '[:space:]' | grep -Po '<td>stable:</td><td><strong>[0-9]+.[0-9]+.[0-9]+</strong></td>')
  currentKernel=$(echo $unparsedStableKernel | grep -Po '[0-9]+.[0-9]+.[0-9]+')
  echo $currentKernel
}

dir="$PWD"
KERNEL_VERSION=$(printLatestStableLinuxKernelVersion)
OS_ROOT_DIR=${dir}/mnt/os
EFI_MOUNT_DIR=${OS_ROOT_DIR}/efi
BOOT_MOUNT_DIR=${OS_ROOT_DIR}/boot

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

dd if=/dev/zero of=os.img bs=1M count=512

first_unused_loop_device=$(sudo losetup -f)

mkfs.ext4 os.img

sudo losetup -P $first_unused_loop_device os.img
sudo parted -s $first_unused_loop_device mktable gpt
sudo parted -s $first_unused_loop_device mkpart primary fat32 1MiB 261MiB 
sudo parted -s $first_unused_loop_device set 1 esp on
sudo parted -s $first_unused_loop_device mkpart primary ext4 261MiB 100%

mkdir -p $EFI_MOUNT_DIR
mkdir -p $BOOT_MOUNT_DIR

mkfs.fat ${first_unused_loop_device}p1
mkfs.ext4 ${first_unused_loop_device}p2

sudo mount ${first_unused_loop_device}p1 $EFI_MOUNT_DIR
sudo mount ${first_unused_loop_device}p2 $BOOT_MOUNT_DIR

# Create a directory for the final image & setup
# using "Filesystem Hierarchy Standard" as a guide, creating
# just the required directories for now.
mkdir -vp ${BOOT_MOUNT_DIR}/{bin,boot,dev,etc,lib,media,mnt,opt,run,sbin,srv,tmp,var}
mkdir -vp ${BOOT_MOUNT_DIR}/etc/opt
mkdir -vp ${BOOT_MOUNT_DIR}/usr/{bin,lib,sbin,share,include}
mkdir -vp ${BOOT_MOUNT_DIR}/usr/local/{bin,etc,games,include,lib,man,sbin,share,src}

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
  make ARCH=x86_64 defconfig
  make -j $(nproc)
make modules_install
make install
cd ..
  
# glibc: Download, build, & install
curl -OL http://ftp.wayne.edu/gnu/libc/glibc-2.30.tar.xz.sig
curl -OL http://ftp.wayne.edu/gnu/libc/glibc-2.30.tar.xz
gpg2 --verify --keyring ./gnu-keyring.gpg glibc-2.30.tar.xz.sig
gpg2 --verify --keyring ./gnu-keyring.gpg glibc-2.30.tar.xz.sig glibc-2.30.tar.xz
tar -xf glibc-2.30.tar.xz
cd ./glibc-2.30
./configure --prefix="${pwd}/mnt/os/boot/usr/local" --enable-kernel $KERNEL_VERSION
make
make install
cd ..

# Install Grub
sudo grub-install --target=x86_64-efi --efi-directory=${EFI_MOUNT_DIR} --bootloader-id=GRUB

sudo umount $EFI_MOUNT_DIR
sudo umount $BOOT_MOUNT_DIR

lsblk -a

sudo losetup -d $first_unused_loop_device
