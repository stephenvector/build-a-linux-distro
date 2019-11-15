#!/bin/bash

ls -la

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
