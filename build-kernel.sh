#!/bin/bash

printLatestStableLinuxKernelVersion() {
  unparsedStableKernel=$(curl -s https://www.kernel.org/ | tr -d '[:space:]' | grep -Po '<td>stable:</td><td><strong>[0-9]+.[0-9]+.[0-9]+</strong></td>')
  currentKernel=$(echo $unparsedStableKernel | grep -Po '[0-9]+.[0-9]+.[0-9]+')
  echo $currentKernel
}

KERNEL_VERSION=$(printLatestStableLinuxKernelVersion)

# Download kernel source, verify source, & build kernel
# Eventually we will need to add support for changing this based on the kernel version
curl -OL "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-$KERNEL_VERSION.tar.xz"
curl -OL "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-$KERNEL_VERSION.tar.sign"
gpg2 --locate-keys torvalds@kernel.org gregkh@kernel.org
gpg2 --verify "linux-$KERNEL_VERSION.tar.sign"
unxz "linux-$KERNEL_VERSION.tar.xz"
gpg2 --verify "linux-$KERNEL_VERSION.tar.sign" "linux-$KERNEL_VERSION.tar"
tar -xf "linux-$KERNEL_VERSION.tar"
cd "linux-$KERNEL_VERSION"
make ARCH=x86_64 defconfig
make
