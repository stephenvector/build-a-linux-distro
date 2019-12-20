#!/bin/bash

function printLatestStableLinuxKernelVersion {
  unparsedStableKernel=$(curl -s https://www.kernel.org/ | tr -d '[:space:]' | grep -Po '<td>stable:</td><td><strong>[0-9]+.[0-9]+.[0-9]+</strong></td>')
  currentKernel=$(echo $unparsedStableKernel | grep -Po '[0-9]+.[0-9]+.[0-9]+')
  echo $currentKernel
}

dir="$PWD"
IMAGE_PATH="$PWD/image"
KERNEL_VERSION=$(printLatestStableLinuxKernelVersion)

# function cleanup {
  # cleanup old files - BE CAREFUL WITH THIS! Make sure you've added the proper
  # scripts to the ignored list
  # shopt -s extglob
  # rm -rf ./*.xz !(README.md|build-a-linux-os.sh|.git|.gitignore)
# }

function setup {
  # Install necessary packages
  sudo apt-get update -q
  sudo apt-get upgrade -y -q
  sudo apt-get install wget build-essential bison flex xz-utils gnupg2 -y -q

  # Download GNU keyring to verify GNU utilities
  curl -OL https://ftp.gnu.org/gnu/gnu-keyring.gpg
}

function kernel {
  # Download kernel source, verify source, & build kernel
  export INSTALL_PATH="$IMAGE_PATH/boot"
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
}

# Create a directory for the final image & setup
# using "Filesystem Hierarchy Standard" as a guide, creating
# just the required directories for now.
function create_file_system {
  # Delete old directory
  rm -rf "$IMAGE_PATH"

  # Create a virtual file system

  mkdir image
  cd image
  mkdir bin boot dev etc lib media mnt opt run sbin srv tmp usr var

  mkdir etc/opt

  mkdir usr/bin
  mkdir usr/lib
  mkdir usr/local
  mkdir usr/sbin
  mkdir usr/share
  mkdir usr/include

  cd usr/local

  mkdir bin
  mkdir etc
  mkdir games
  mkdir include
  mkdir lib
  mkdir man
  mkdir sbin
  mkdir share
  mkdir src

  # cd ../../

  # # Make 64mb file
  # dd if=/dev/zero of=./image.img bs=1024 count=$[1024*64]

  # mkfs -t ext4 ./image.img

  # mkdir /mnt/image

  # mount -t auto -o loop ./image.img /mnt/image
}

# glibc: Download, build, & install
function add_glibc {
  curl -OL http://ftp.wayne.edu/gnu/libc/glibc-2.30.tar.xz.sig
  curl -OL http://ftp.wayne.edu/gnu/libc/glibc-2.30.tar.xz
  gpg2 --verify --keyring ./gnu-keyring.gpg glibc-2.30.tar.xz.sig
  gpg2 --verify --keyring ./gnu-keyring.gpg glibc-2.30.tar.xz.sig glibc-2.30.tar.xz
  tar -xf glibc-2.30.tar.xz
  cd glibc-2.30
  mkdir "$PWD/glibcbuild"
  cd "$PWD/glibcbuild"
  "$dir/glibc-2.30/configure" --prefix="$IMAGE_PATH/usr"
  make
  make install 
}

# GNU Coreutils: Download, build, & install
function add_coreutils {
  curl -OL https://ftp.gnu.org/gnu/coreutils/coreutils-8.31.tar.xz.sig
  curl -OL https://ftp.gnu.org/gnu/coreutils/coreutils-8.31.tar.xz
  gpg2 --verify --keyring ./gnu-keyring.gpg coreutils-8.31.tar.xz.sig
  gpg2 --verify --keyring ./gnu-keyring.gpg coreutils-8.31.tar.xz.sig coreutils-8.31.tar.xz
  tar xf coreutils-8.31.tar.xz
  cd "$dir/coreutils-8.31"
  ./configure --prefix="$IMAGE_PATH"
  make
  make install
}


# systemd: Download, build, & install
function add_systemd {
  curl -OL https://github.com/systemd/systemd/archive/v243.tar.gz
  tar xf v243.tar.gz
  cd systemd-243
  ./configure
  make
  make install DESTDIR="$IMAGE_PATH"
}

# Download grub2: IN PROGRESS / NOT WORKING
function add_grub2 {
  curl -OL https://ftp.gnu.org/gnu/grub/grub-2.04.tar.xz
  curl -OL https://ftp.gnu.org/gnu/grub/grub-2.04.tar.xz.sig
  gpg2 --verify --keyring ./gnu-keyring.gpg grub-2.04.tar.xz.sig
  gpg2 --verify --keyring ./gnu-keyring.gpg grub-2.04.tar.xz.sig grub-2.04.tar.xz
  tar xf grub-2.04.tar.xz
  cd grub-2.04
  ./configure --prefix="$IMAGE_PATH"
  make
  make install
}

# Download & Build Bash
function add_bash {
  curl -OL https://ftp.gnu.org/gnu/bash/bash-5.0.tar.gz
  curl -OL https://ftp.gnu.org/gnu/bash/bash-5.0.tar.gz.sig
  gpg2 --verify --keyring ./gnu-keyring.gpg bash-5.0.tar.gz.sig
  gpg2 --verify --keyring ./gnu-keyring.gpg bash-5.0.tar.gz.sig bash-5.0.tar.gz
  tar xf bash-5.0.tar.gz
  cd bash-5.0
  ./configure --prefix="$IMAGE_PATH"
  make
  make install
}

function make_image {
  grub-mkrescue -o linux.iso "$IMAGE_PATH"
}

function build_a_linux_os {
  cleanup
  setup
  create_file_system
  add_glibc
  add_coreutils
  add_kernel
  add_bash
  add_systemd
  # add_grub2
  make_image
}

build_a_linux_os

