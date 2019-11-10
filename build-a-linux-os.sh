#!/bin/bash

apt-get update
apt-get upgrade -y
apt-get install wget build-essential bison flex -y

# Download & verify kernel source
wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.3.10.tar.xz
wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.3.10.tar.sign
gpg --verify linux-5.3.10.tar.sign linux-5.3.10.tar.xz
tar -xz linux-5.3.10.tar.xz
cd linux-5.3.10
make defconfig
