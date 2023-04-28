
ARPL_VERSION="23.4.0"

# Define paths
TMP_PATH="/tmp"
UNTAR_PAT_PATH="${TMP_PATH}/pat"
RAMDISK_PATH="${TMP_PATH}/ramdisk"
LOG_FILE="${TMP_PATH}/log.txt"

BACKUPDIR="${CACHE_PATH}/backup"

USER_CONFIG_FILE="${BOOTLOADER_PATH}/user-config.yml"
BB_USER_CONFIG_FILE="${BACKUPDIR}/user-config.yml"
GRUB_PATH="${BOOTLOADER_PATH}/boot/grub"
SYSINFO_PATH="${BOOTLOADER_PATH}/sysinfo.yml"

ORI_ZIMAGE_FILE="${SLPART_PATH}/zImage"
ORI_RDGZ_FILE="${SLPART_PATH}/rd.gz"

ARPL_BZIMAGE_FILE="${CACHE_PATH}/bzImage-arpl"
ARPL_RAMDISK_FILE="${CACHE_PATH}/initrd-arpl"
MOD_ZIMAGE_FILE="${CACHE_PATH}/zImage-dsm"
MOD_RDGZ_FILE="${CACHE_PATH}/initrd-dsm"
BB_MOD_ZIMAGE_FILE="${BACKUPDIR}/zImage-dsm"
BB_MOD_RDGZ_FILE="${BACKUPDIR}/initrd-dsm"
ADDONS_PATH="${CACHE_PATH}/addons"
LKM_PATH="${CACHE_PATH}/lkms"
MODULES_PATH="${CACHE_PATH}/modules"

MODEL_CONFIG_PATH="/opt/arpl/model-configs"
INCLUDE_PATH="/opt/arpl/include"
PATCH_PATH="/opt/arpl/patch"