#!/usr/bin/env bash

set -e
[[ -z "${ARC_PATH}" || ! -d "${ARC_PATH}/include" ]] && ARC_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

. ${ARC_PATH}/include/functions.sh
. ${ARC_PATH}/include/addons.sh

[ -z "${LOADER_DISK}" ] && die "Loader Disk not found!"

# Shows title
clear
[ -z "${COLUMNS}" ] && COLUMNS=50
TITLE="${ARC_TITLE}"
printf "\033[1;30m%*s\n" ${COLUMNS} ""
printf "\033[1;30m%*s\033[A\n" ${COLUMNS} ""
printf "\033[1;34m%*s\033[0m\n" $(((${#TITLE} + ${COLUMNS}) / 2)) "${TITLE}"
printf "\033[1;30m%*s\033[0m\n" ${COLUMNS} ""

# Get the VID/PID if we are in USB
VID="0x46f4"
PID="0x0001"
BUS=$(getBus "${LOADER_DISK}")

if [ "${BUS}" = "usb" ]; then
  VID="0x$(udevadm info --query property --name "${LOADER_DISK}" | grep ID_VENDOR_ID | cut -d= -f2)"
  PID="0x$(udevadm info --query property --name "${LOADER_DISK}" | grep ID_MODEL_ID | cut -d= -f2)"
elif [[ "${BUS}" != "sata" && "${BUS}" != "scsi" && "${BUS}" != "nvme" ]]; then
  die "Loader disk is not USB or SATA/SCSI/NVME DoM"
fi

# Inform user
echo -e "Loader Disk: \033[1;34m${LOADER_DISK}\033[0m"
echo -e "Loader Disk Type: \033[1;34m${BUS^^}\033[0m"

echo -e "\033[1;34mDetected ${ETH} NIC.\033[0m \033[1;37mWaiting for Connection:\033[0m"
for N in ${ETHX}; do
  IP=""
  DRIVER=$(ls -ld /sys/class/net/${N}/device/driver 2>/dev/null | awk -F '/' '{print $NF}')
  COUNT=0
  while true; do
    IP="$(getIP ${N})"
    MSG="DHCP"
    if [ -n "${IP}" ]; then
      SPEED=$(ethtool ${N} | grep "Speed:" | awk '{print $2}')
      echo -e "\r\033[1;37m${DRIVER} (${SPEED} | ${MSG}):\033[0m Access \033[1;34mhttp://${IP}:7681\033[0m to connect to Arc via web."
      break
    fi
    if [ ${COUNT} -gt ${BOOTIPWAIT} ]; then
      echo -e echo -e "\r\033[1;37m${DRIVER}:\033[0m TIMEOUT"
      break
    fi
    sleep 3
    if ethtool ${N} | grep 'Link detected' | grep -q 'no'; then
      echo -e "\r\033[1;37m${DRIVER}:\033[0m NOT CONNECTED"
      break
    fi
    COUNT=$((${COUNT} + 3))
  done
  ethtool -s ${N} wol g 2>/dev/null
done

# Inform user
echo
echo -e "Call \033[1;34marc.sh\033[0m to configure Arc-V"
echo
echo -e "Default SSH Root password is \033[1;34marc\033[0m"
echo

# Load Arc-V
echo -e "\033[1;34mLoading Arc-V Overlay...\033[0m"
sleep 2

# Diskcheck
HASATA=0
for D in $(lsblk -dpno NAME); do
  [ "${D}" = "${LOADER_DISK}" ] && continue
  if [[ "$(getBus "${D}")" = "sata" || "$(getBus "${D}")" = "scsi" ]]; then
    HASATA=1
    break
  fi
done

# Check memory and load Arc-V
RAM=$(free -m | grep -i mem | awk '{print$2}')
if [ ${RAM} -le 3500 ]; then
  echo -e "\033[1;31mYou have less than 4GB of RAM, if errors occur in loader creation, please increase the amount of RAM.\033[0m\n"
  echo -e "\033[1;31mUse arc.sh to proceed. Not recommended!\033[0m\n"
elif [ ${HASATA} = "0" ]; then
  echo -e "\033[1;31m*** Please insert at least one Sata/SAS Disk for System Installation, except for the Bootloader Disk. ***\033[0m\n"
  echo -e "\033[1;31mUse arc.sh to proceed. Not recommended!\033[0m\n"
else
  sysctl -p /etc/sysctl.conf
fi