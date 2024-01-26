#!/usr/bin/env bash
#
# Copyright (C) 2023 AuxXxilium <https://github.com/AuxXxilium> and Ing <https://github.com/wjz304>
# 
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Get latest Buildroot
# $1 TAG
# $2 path
function getBuildroot() {
  echo "Getting Buildroot begin"
  local TAG="${1:-latest}"
  local DEST_PATH="${2:-br}"

  if [ "${1}" = "latest" ]; then
    TAG=$(curl -s "https://api.github.com/repos/AuxXxilium/arc-v-buildroot/releases" | jq -r ".[0].tag_name")
  fi
  [ ! -d "${DEST_PATH}" ] && mkdir -p "${DEST_PATH}"
  rm -rf "${DEST_PATH}/bzImage-arc"
  STATUS=$(curl -w "%{http_code}" -L "https://github.com/AuxXxilium/arc-v-buildroot/releases/download/${TAG}/bzImage" -o "${DEST_PATH}/bzImage-arc")
  echo "TAG=${TAG}; Status=${STATUS}"
  [ ${STATUS} -ne 200 ] && exit 1

  rm -rf "${DEST_PATH}/initrd-arc"
  STATUS=$(curl -w "%{http_code}" -L "https://github.com/AuxXxilium/arc-v-buildroot/releases/download/${TAG}/rootfs.cpio.xz" -o "${DEST_PATH}/initrd-arc")
  echo "TAG=${TAG}; Status=${STATUS}"
  [ ${STATUS} -ne 200 ] && exit 1

  echo "Getting Buildroot end"
}

# repack initrd
# $1 initrd file  
# $2 plugin path
# $3 output file
function repackInitrd() {
  INITRD_FILE="${1}"
  PLUGIN_PATH="${2}"
  OUTPUT_PATH="${3:-${INITRD_FILE}}"

  [ -z "${INITRD_FILE}" ] || [ ! -f "${INITRD_FILE}" ] && exit 1
  [ -z "${PLUGIN_PATH}" ] || [ ! -d "${PLUGIN_PATH}" ] && exit 1
  
  INITRD_FILE="$(readlink -f "${INITRD_FILE}")"
  PLUGIN_PATH="$(readlink -f "${PLUGIN_PATH}")"
  OUTPUT_PATH="$(readlink -f "${OUTPUT_PATH}")"

  RDXZ_PATH="rdxz_tmp"
  mkdir -p "${RDXZ_PATH}"
  (
    cd "${RDXZ_PATH}"
    sudo xz -dc <"${INITRD_FILE}" | sudo cpio -idm
  ) || true
  sudo cp -Rf "${PLUGIN_PATH}/"* "${RDXZ_PATH}/"
  [ -f "${OUTPUT_PATH}" ] && rm -rf "${OUTPUT_PATH}"
  (
    cd "${RDXZ_PATH}"
    sudo find . 2>/dev/null | sudo cpio -o -H newc -R root:root | xz --check=crc32 >"${OUTPUT_PATH}"
  ) || true
  sudo rm -rf "${RDXZ_PATH}"
}

# resizeimg
# $1 input file  
# $2 changsize MB eg: +50M -50M
# $3 output file
function resizeImg() {
  INPUT_FILE="${1}"
  CHANGE_SIZE="${2}"
  OUTPUT_FILE="${3:-${INPUT_FILE}}"

  [[ -z "${INPUT_FILE}" || ! -f "${INPUT_FILE}" ]] && exit 1
  [ -z "${CHANGE_SIZE}" ] && exit 1

  INPUT_FILE="$(readlink -f "${INPUT_FILE}")"
  OUTPUT_FILE="$(readlink -f "${OUTPUT_FILE}")"


  SIZE=$(($(du -m "${INPUT_FILE}" | awk '{print $1}')$(echo "${CHANGE_SIZE}" | sed 's/M//g; s/b//g')))
  [[ -z "${SIZE}" || "${SIZE}" -lt 0 ]] && exit 1

  if [ ! "${INPUT_FILE}" = "${OUTPUT_FILE}" ]; then
    sudo cp -f "${INPUT_FILE}" "${OUTPUT_FILE}"
  fi

  sudo truncate -s ${SIZE}M "${OUTPUT_FILE}"
  echo -e "d\n\nn\n\n\n\n\nn\nw" | sudo fdisk "${OUTPUT_FILE}"
  LOOPX=$(sudo losetup -f)
  sudo losetup -P ${LOOPX} "${OUTPUT_FILE}"
  sudo e2fsck -fp $(ls ${LOOPX}* | sort -n | tail -1)
  sudo resize2fs $(ls ${LOOPX}* | sort -n | tail -1)
  sudo losetup -d ${LOOPX}
}