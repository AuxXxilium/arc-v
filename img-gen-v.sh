#!/usr/bin/env bash

set -e

# Clean cached Files
sudo git clean -fdx

. scripts/func.sh "${AUX_TOKEN}"

# Get extractor, LKM, addons and Modules
echo "Get Dependencies"
getTheme "files/p1/boot/grub"
mkdir -p "brv"
[ ! -f "../brv/bzImage" ] && getBuildrootx "brv" || copyBuildroot "brv"

# Sbase
IMAGE_FILE="arc.img"
gzip -dc "files/initrd/opt/arc/grub.img.gz" >"${IMAGE_FILE}"
fdisk -l "${IMAGE_FILE}"

LOOPX=$(sudo losetup -f)
sudo losetup -P "${LOOPX}" "${IMAGE_FILE}"

echo "Mounting Image File"
sudo rm -rf "/tmp/p1"
sudo rm -rf "/tmp/p3"
mkdir -p "/tmp/p1"
mkdir -p "/tmp/p3"
sudo mount ${LOOPX}p1 "/tmp/p1"
sudo mount ${LOOPX}p3 "/tmp/p3"

ARC_BUILD="`date +'%y%m%d'`"
ARC_VERSION="13.3.7"
ARC_BRANCH="virtual"
echo "${ARC_BUILD}" >files/p1/ARC-BUILD
echo "${ARC_VERSION}" >files/p1/ARC-VERSION
echo "${ARC_BRANCH}" >files/p1/ARC-BRANCH

echo "Repack initrd"
if [ -f "brv/bzImage-arc" ] && [ -f "brv/initrd-arc" ]; then
    cp -f "brv/bzImage-arc" "files/p3/bzImage-arc"
    repackInitrd "brv/initrd-arc" "files/initrd" "files/p3/initrd-arc"
else
    sudo umount "/tmp/p1"
    sudo umount "/tmp/p3"
    exit 1
fi

echo "Copying files"
sudo cp -rf "files/p1/"* "/tmp/p1"
sudo cp -rf "files/p3/"* "/tmp/p3"
sync

echo "Unmount image file"
sudo umount "/tmp/p1"
sudo umount "/tmp/p3"
rmdir "/tmp/p1"
rmdir "/tmp/p3"

sudo losetup --detach ${LOOPX}

echo "Resize Image"
mv -f "arc.img" "arc_1G.img"
resizeImg "arc_1G.img" "+3072M" "arc.img"

qemu-img convert -p -f raw -o subformat=monolithicFlat -O vmdk ${IMAGE_FILE} arc.vmdk
