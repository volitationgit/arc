
[[ -z "${ARC_PATH}" || ! -d "${ARC_PATH}/include" ]] && ARC_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

. ${ARC_PATH}/include/consts.sh
. ${ARC_PATH}/include/configFile.sh
. ${ARC_PATH}/include/addons.sh

###############################################################################
# read key value from model config file
# 1 - Model
# 2 - Key
# Return Value
function readModelKey() {
  readConfigKey "${2}" "${MODEL_CONFIG_PATH}/${1}.yml"
}

###############################################################################
# read Entries as map(key=value) from model config
# 1 - Model
# 2 - Path of key
# Returns map of values
function readModelMap() {
  readConfigMap "${2}" "${MODEL_CONFIG_PATH}/${1}.yml"
}

###############################################################################
# read an array from model config
# 1 - Model
# 2 - Path of key
# Returns array/map of values
function readModelArray() {
  readConfigArray "${2}" "${MODEL_CONFIG_PATH}/${1}.yml"
}

###############################################################################
# Just show error message and dies
function die() {
  echo -e "\033[1;41m$@\033[0m"
  exit 1
}

###############################################################################
# Show error message with log content and dies
function dieLog() {
  echo -en "\n\033[1;41mUNRECOVERY ERROR: "
  cat "${LOG_FILE}"
  echo -e "\033[0m"
  sleep 3
  exit 1
}

###############################################################################
# Generate a number with 6 digits from 1 to 30000
function random() {
  printf "%06d" $((${RANDOM} % 30000 + 1))
}

###############################################################################
# Generate a hexa number from 0x00 to 0xFF
function randomhex() {
  printf "&02X" "$((${RANDOM} % 255 + 1))"
}

###############################################################################
# Generate a random letter
function genRandomLetter() {
  for i in A B C D E F G H J K L M N P Q R S T V W X Y Z; do
    echo ${i}
  done | sort -R | tail -1
}

###############################################################################
# Generate a random digit (0-9A-Z)
function genRandomValue() {
  for i in 0 1 2 3 4 5 6 7 8 9 A B C D E F G H J K L M N P Q R S T V W X Y Z; do
    echo ${i}
  done | sort -R | tail -1
}

###############################################################################
# Generate a random serial number for a model
# 1 - Model
# Returns serial number
function generateSerial() {
  ID="$(readModelKey "${1}" "id")"
  PREFIX="$(readConfigArray "${ID}.prefix" "${S_FILE}" | sort -R | tail -1)"
  MIDDLE="$(readConfigArray "${ID}.middle" "${S_FILE}" | sort -R | tail -1)"
  SUFFIX="$(readConfigKey "${ID}.suffix" "${S_FILE}")"

  case "${SUFFIX}" in
  numeric)
    SUFFIX="$(random)"
    ;;
  alpha)
    SUFFIX="$(genRandomLetter)$(genRandomValue)$(genRandomValue)$(genRandomValue)$(genRandomValue)$(genRandomLetter)"
    ;;
  esac
  SERIAL="${PREFIX:-"0000"}${MIDDLE:-"XXX"}${SUFFIX:-"123456"}"
  echo ${SERIAL}
  return 0
}

###############################################################################
# Generate a MAC address for a model
# 1 - Model
# 2 - Amount of MACs to generate
# Returns serial number
function generateMacAddress() {
  ID="$(readModelKey "${1}" "id")"
  MACPRE="$(readConfigKey "${ID}.macpre" "${S_FILE}")"
  MACSUF="$(printf '%02x%02x%02x' $((${RANDOM} % 256)) $((${RANDOM} % 256)) $((${RANDOM} % 256)))"
  NUM=${2:-1}
  MACS=""
  for I in $(seq 1 ${NUM}); do
    MACS+="$(printf '%06x%06x' $((0x${MACPRE:-"001132"})) $(($((0x${MACSUF})) + ${I})))"
    [ ${I} -lt ${NUM} ] && MACS+=" "
  done
  echo "${MACS}"
  return 0
}

###############################################################################
# Validate a serial number for a model
# 1 - Model
# 2 - Serial number to test
# Returns 1 if serial number is valid
function validateSerial() {
  PREFIX=$(readModelArray "${1}" "serial.prefix")
  MIDDLE=$(readModelKey "${1}" "serial.middle")
  S=${2:0:4}
  P=${2:4:3}
  L=${#2}
  if [ ${L} -ne 13 ]; then
    return 0
  fi
  echo "${PREFIX}" | grep -q "${S}"
  if [ $? -eq 1 ]; then
    return 0
  fi
  if [ "${MIDDLE}" != "${P}" ]; then
    return 0
  fi
  return 1
}

###############################################################################
# Check if a item exists into array
# 1 - Item
# 2.. - Array
# Return 0 if exists
function arrayExistItem() {
  EXISTS=1
  ITEM="${1}"
  shift
  for i in "$@"; do
    [ "${i}" = "${ITEM}" ] || continue
    EXISTS=0
    break
  done
  return ${EXISTS}
}

###############################################################################
# Get values in .conf K=V file
# 1 - key
# 2 - file
function _get_conf_kv() {
  grep "${1}" "${2}" | sed "s|^${1}=\"\(.*\)\"$|\1|g"
}

###############################################################################
# Replace/remove/add values in .conf K=V file
# 1 - name
# 2 - new_val
# 3 - path
function _set_conf_kv() {
  # Delete
  if [ -z "${2}" ]; then
    sed -i "${3}" -e "s/^${1}=.*$//"
    return $?;
  fi

  # Replace
  if grep -q "^${1}=" "${3}"; then
    sed -i "${3}" -e "s\"^${1}=.*\"${1}=\\\"${2}\\\"\""
    return $?
  fi

  # Add if doesn't exist
  echo "${1}=\"${2}\"" >>"${3}"
}

###############################################################################
# sort netif name
# @1 -mac1,mac2,mac3...
function _sort_netif() {
  ETHLIST=""
  ETHX=$(ls /sys/class/net/ 2>/dev/null | grep eth) # real network cards list
  for ETH in ${ETHX}; do
    MAC="$(cat /sys/class/net/${ETH}/address 2>/dev/null | sed 's/://g' | tr '[:upper:]' '[:lower:]')"
    BUS=$(ethtool -i ${ETH} 2>/dev/null | grep bus-info | awk '{print $2}')
    ETHLIST="${ETHLIST}${BUS} ${MAC} ${ETH}\n"
  done

  if [ -n "${1}" ]; then
    MACS=$(echo "${1}" | sed 's/://g' | tr '[:upper:]' '[:lower:]' | tr ',' ' ')
    ETHLISTTMPC=""
    ETHLISTTMPF=""

    for MACX in ${MACS}; do
      ETHLISTTMPC="${ETHLISTTMPC}$(echo -e "${ETHLIST}" | grep "${MACX}")\n"
    done

    while read -r BUS MAC ETH; do
      [ -z "${MAC}" ] && continue
      if echo "${MACS}" | grep -q "${MAC}"; then continue; fi
      ETHLISTTMPF="${ETHLISTTMPF}${BUS} ${MAC} ${ETH}\n"
    done <<EOF
$(echo -e ${ETHLIST} | sort)
EOF
    ETHLIST="${ETHLISTTMPC}${ETHLISTTMPF}"
  else
    ETHLIST="$(echo -e "${ETHLIST}" | sort)"
  fi
  ETHLIST="$(echo -e "${ETHLIST}" | grep -v '^$')"

  echo -e "${ETHLIST}" >${TMP_PATH}/ethlist
  # cat ${TMP_PATH}/ethlist

  # sort
  IDX=0
  while true; do
    # cat ${TMP_PATH}/ethlist
    [ ${IDX} -ge $(wc -l <${TMP_PATH}/ethlist) ] && break
    ETH=$(cat ${TMP_PATH}/ethlist | sed -n "$((${IDX} + 1))p" | awk '{print $3}')
    # echo "ETH: ${ETH}"
    if [ -n "${ETH}" ] && [ ! "${ETH}" = "eth${IDX}" ]; then
      # echo "change ${ETH} <=> eth${IDX}"
      ip link set dev eth${IDX} down
      ip link set dev ${ETH} down
      sleep 1
      ip link set dev eth${IDX} name ethN
      ip link set dev ${ETH} name eth${IDX}
      ip link set dev ethN name ${ETH}
      sleep 1
      ip link set dev eth${IDX} up
      ip link set dev ${ETH} up
      sleep 1
      sed -i "s/eth${IDX}/ethN/" ${TMP_PATH}/ethlist
      sed -i "s/${ETH}/eth${IDX}/" ${TMP_PATH}/ethlist
      sed -i "s/ethN/${ETH}/" ${TMP_PATH}/ethlist
      sleep 1
    fi
    IDX=$((${IDX} + 1))
  done

  rm -f ${TMP_PATH}/ethlist
  return 0
}

###############################################################################
# get bus of disk
# 1 - device path
function getBus() {
  BUS=""
  # usb/ata(sata/ide)/scsi
  [ -z "${BUS}" ] && BUS=$(udevadm info --query property --name "${1}" 2>/dev/null | grep ID_BUS | cut -d= -f2 | sed 's/ata/sata/')
  # usb/sata(sata/ide)/nvme
  [ -z "${BUS}" ] && BUS=$(lsblk -dpno KNAME,TRAN 2>/dev/null | grep "${1} " | awk '{print $2}') #Spaces are intentional
  # usb/scsi(sata/ide)/virtio(scsi/virtio)/mmc/nvme
  [ -z "${BUS}" ] && BUS=$(lsblk -dpno KNAME,SUBSYSTEMS 2>/dev/null | grep "${1} " | awk -F':' '{print $(NF-1)}' | sed 's/_host//') #Spaces are intentional
  echo "${BUS}"
  return 0
}

###############################################################################
# get IP
# 1 - ethN
function getIP() {
  IP=""
  if [ -n "${1}" -a -d "/sys/class/net/${1}" ]; then
    IP=$(ip route show dev ${1} 2>/dev/null | sed -n 's/.* via .* src \(.*\)  metric .*/\1/p')
    [ -z "${IP}" ] && IP=$(ip addr show ${1} scope global 2>/dev/null | grep -E "inet .* eth" | awk '{print $2}' | cut -f1 -d'/' | head -1)
  else
    IP=$(ip route show 2>/dev/null | sed -n 's/.* via .* src \(.*\)  metric .*/\1/p' | head -1)
    [ -z "${IP}" ] && IP=$(ip addr show scope global 2>/dev/null | grep -E "inet .* eth" | awk '{print $2}' | cut -f1 -d'/' | head -1)
  fi
  echo "${IP}"
  return 0
}

###############################################################################
# get logo of model
# 1 - model
function getLogo() {
  MODEL="${1}"
  rm -f "${PART3_PATH}/logo.png"
  STATUS=$(curl -skL -m 10 -w "%{http_code}" "https://www.synology.com/api/products/getPhoto?product=${MODEL/+/%2B}&type=img_s&sort=0" -o "${PART3_PATH}/logo.png")
  if [ $? -ne 0 -o ${STATUS:-0} -ne 200 -o ! -f "${PART3_PATH}/logo.png" ]; then
    rm -f "${PART3_PATH}/logo.png"
    return 1
  fi
  convert -rotate 180 "${PART3_PATH}/logo.png" "${PART3_PATH}/logo.png" 2>/dev/null
  magick montage "${PART3_PATH}/logo.png" -background 'none' -tile '3x3' -geometry '350x210' "${PART3_PATH}/logo.png" 2>/dev/null
  convert -rotate 180 "${PART3_PATH}/logo.png" "${PART3_PATH}/logo.png" 2>/dev/null
  return 0
}

###############################################################################
# Find and mount the DSM root filesystem
function findDSMRoot() {
  DSMROOTS=""
  [ -z "${DSMROOTS}" ] && DSMROOTS="$(mdadm --detail --scan 2>/dev/null | grep -E "name=SynologyNAS:0|name=DiskStation:0|name=SynologyNVR:0|name=BeeStation:0" | awk '{print $2}' | uniq)"
  [ -z "${DSMROOTS}" ] && DSMROOTS="$(lsblk -pno KNAME,PARTN,FSTYPE,FSVER,LABEL | grep -E "sd[a-z]{1,2}1" | grep -w "linux_raid_member" | grep "0.9" | awk '{print $1}')"
  echo "${DSMROOTS}"
  return 0
}

###############################################################################
# Convert Netmask eq. 255.255.255.0 to /24
# 1 - Netmask
function convert_netmask() {
  bits=0
  for octet in $(echo $1| sed 's/\./ /g'); do 
      binbits=$(echo "obase=2; ibase=10; ${octet}"| bc | sed 's/0//g') 
      bits=$((${bits} + ${#binbits}))
  done
  echo "${bits}"
}

###############################################################################
# Livepatch
function livepatch() {
  FAIL=0
  # Patch zImage
  if ! ${ARC_PATH}/zimage-patch.sh; then
    FAIL=1
  else
    ZIMAGE_HASH_CUR="$(sha256sum "${ORI_ZIMAGE_FILE}" | awk '{print $1}')"
    writeConfigKey "zimage-hash" "${ZIMAGE_HASH_CUR}" "${USER_CONFIG_FILE}"
    FAIL=0
  fi
  # Patch Ramdisk
  if ! ${ARC_PATH}/ramdisk-patch.sh; then
    FAIL=1
  else
    RAMDISK_HASH_CUR="$(sha256sum "${ORI_RDGZ_FILE}" | awk '{print $1}')"
    writeConfigKey "ramdisk-hash" "${RAMDISK_HASH_CUR}" "${USER_CONFIG_FILE}"
    FAIL=0
  fi
  if [ "${OFFLINE}" = "false" ]; then
    # Looking for Update
    if [ ${FAIL} -eq 1 ]; then
      # Update Configs
      TAG="$(curl --insecure -m 5 -s https://api.github.com/repos/AuxXxilium/arc-configs/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3)}')"
      if [[ $? -ne 0 || -z "${TAG}" ]]; then
        return 1
      fi
      STATUS=$(curl --insecure -s -w "%{http_code}" -L "https://github.com/AuxXxilium/arc-configs/releases/download/${TAG}/configs.zip" -o "${TMP_PATH}/configs.zip")
      if [[ $? -ne 0 || ${STATUS} -ne 200 ]]; then
        return 1
      fi
      rm -rf "${MODEL_CONFIG_PATH}"
      mkdir -p "${MODEL_CONFIG_PATH}"
      unzip -oq "${TMP_PATH}/configs.zip" -d "${MODEL_CONFIG_PATH}" >/dev/null 2>&1
      rm -f "${TMP_PATH}/configs.zip"
      # Update Patches
      TAG="$(curl --insecure -m 5 -s https://api.github.com/repos/AuxXxilium/arc-patches/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3)}')"
      if [[ $? -ne 0 || -z "${TAG}" ]]; then
        return 1
      fi
      STATUS=$(curl --insecure -s -w "%{http_code}" -L "https://github.com/AuxXxilium/arc-patches/releases/download/${TAG}/patches.zip" -o "${TMP_PATH}/patches.zip")
      if [[ $? -ne 0 || ${STATUS} -ne 200 ]]; then
        return 1
      fi
      rm -rf "${PATCH_PATH}"
      mkdir -p "${PATCH_PATH}"
      unzip -oq "${TMP_PATH}/patches.zip" -d "${PATCH_PATH}" >/dev/null 2>&1
      rm -f "${TMP_PATH}/patches.zip"
      # Patch zImage
      if ! ${ARC_PATH}/zimage-patch.sh; then
        FAIL=1
      else
        ZIMAGE_HASH_CUR="$(sha256sum "${ORI_ZIMAGE_FILE}" | awk '{print $1}')"
        writeConfigKey "zimage-hash" "${ZIMAGE_HASH_CUR}" "${USER_CONFIG_FILE}"
        FAIL=0
      fi
      # Patch Ramdisk
      if ! ${ARC_PATH}/ramdisk-patch.sh; then
        FAIL=1
      else
        RAMDISK_HASH_CUR="$(sha256sum "${ORI_RDGZ_FILE}" | awk '{print $1}')"
        writeConfigKey "ramdisk-hash" "${RAMDISK_HASH_CUR}" "${USER_CONFIG_FILE}"
        FAIL=0
      fi
    fi
  fi
  if [ ${FAIL} -eq 1 ]; then
    echo
    echo -e "Patching DSM Files failed! Please stay patient for Update." 0 0
    sleep 5
    exit 1
  else
    echo "DSM Image patched - Ready!"
  fi
}

###############################################################################
# Rebooting
# (based on pocopico's TCRP code)
function rebootTo() {
  MODES="config recovery junior automated update"
  [ -z "${1}" ] && exit 1
  if ! echo "${MODES}" | grep -qw "${1}"; then exit 1; fi
  # echo "Rebooting to ${1} mode"
  GRUBPATH="$(dirname $(find ${BOOTLOADER_PATH}/ -name grub.cfg | head -1))"
  ENVFILE="${GRUBPATH}/grubenv"
  [ ! -f "${ENVFILE}" ] && grub-editenv ${ENVFILE} create
  grub-editenv ${ENVFILE} set next_entry="${1}"
  reboot
}