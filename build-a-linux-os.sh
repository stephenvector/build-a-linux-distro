#!/bin/bash

printLatestStableLinuxKernelVersion() {
  unparsedStableKernel=$(curl -s https://www.kernel.org/ | tr -d '[:space:]' | grep -Po '<td>stable:</td><td><strong>[0-9]+.[0-9]+.[0-9]+</strong></td>')
  currentKernel=$(echo $unparsedStableKernel | grep -Po '[0-9]+.[0-9]+.[0-9]+')
  echo $currentKernel
}

dir="$PWD"
KERNEL_VERSION=$(printLatestStableLinuxKernelVersion)

echo $KERNEL_VERSION

# Install necessary packages
sudo apt-get update -q
sudo apt-get upgrade -y -q
sudo apt-get install wget build-essential bison flex xz-utils gnupg2 -y -q

# cleanup old files - BE CAREFUL WITH THIS!
# shopt -s extglob
# rm -rf ./*.xz !(README.md|build-a-linux-os.sh|.git|.gitignore|build-a-linux-os.sh)

# Create a directory for the final image & setup
# using "Filesystem Hierarchy Standard" as a guide, creating
# just the required directories for now.
mkdir ./linux-os-image

# Download gnu keyring to verify gnu utilities with
curl -OL https://ftp.gnu.org/gnu/gnu-keyring.gpg

# Download & verify glibc
curl -OL http://ftp.wayne.edu/gnu/libc/glibc-2.30.tar.xz.sig
curl -OL http://ftp.wayne.edu/gnu/libc/glibc-2.30.tar.xz
gpg2 --verify --keyring ./gnu-keyring.gpg glibc-2.30.tar.xz.sig
gpg2 --verify --keyring ./gnu-keyring.gpg glibc-2.30.tar.xz.sig glibc-2.30.tar.xz
tar -xf glibc-2.30.tar.xz
cd glibc-2.30
mkdir "$PWD/glibcbuild"
cd "$PWD/glibcbuild"
"$dir/glibc-2.30/configure" --prefix="$PWD/linux-os-image/usr"
make
make install 

# Download & verify GNU Coreutils
cd "$dir"
curl -OL https://ftp.gnu.org/gnu/coreutils/coreutils-8.31.tar.xz.sig
curl -OL https://ftp.gnu.org/gnu/coreutils/coreutils-8.31.tar.xz
gpg2 --verify --keyring ./gnu-keyring.gpg coreutils-8.31.tar.xz.sig
gpg2 --verify --keyring ./gnu-keyring.gpg coreutils-8.31.tar.xz.sig coreutils-8.31.tar.xz
tar xf coreutils-8.31.tar.xz
cd "$dir/coreutils-8.31"
./configure --prefix="$dir/linux-os-image"
make
make install
cd "$dir"

# Download systemd
curl -OL https://github.com/systemd/systemd/archive/v243.tar.gz
tar xf v243.tar.gz
cd systemd-243
./configure
make
make install DESTDIR="$dir/linux-os-image"

cd "$dir"

# Download grub2: IN PROGRESS / NOT WORKING
curl -OL https://ftp.gnu.org/gnu/grub/grub-2.04.tar.xz
curl -OL https://ftp.gnu.org/gnu/grub/grub-2.04.tar.xz.sig
gpg2 --verify --keyring ./gnu-keyring.gpg grub-2.04.tar.xz.sig
gpg2 --verify --keyring ./gnu-keyring.gpg grub-2.04.tar.xz.sig grub-2.04.tar.xz
tar xf grub-2.04.tar.xz
cd grub-2.04
./configure
make
