#!/bin/bash

sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install wget build-essential bison flex xz -y

# Download & verify kernel source
wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.3.10.tar.xz
wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.3.10.tar.sign
gpg2 --locate-keys torvalds@kernel.org gregkh@kernel.org
gpg2 --verify linux-5.3.10.tar.sign
unxz linux-5.3.10.tar.xz
gpg2 --verify linux-5.3.10.tar.sign linux-5.3.10.tar
cd linux-5.3.10
make ARCH=x86_64 defconfig
