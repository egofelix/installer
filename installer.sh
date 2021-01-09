#!/bin/bash
set -uo pipefail

############### Main Script ################

## Load Functions
source "${BASH_SOURCE%/*}/includes/functions.sh"

# Load Variables
source "${BASH_SOURCE%/*}/includes/defaults.sh"
QUIET="false";

# Scan arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -q|--quiet) QUIET="true"; QUIETPS=" &>/dev/null"; ;;
	-nc|--nocrypt) CRYPTED="false"; ;;
	--debug) DEBUG="true"; ;;
	-t|--target) DRIVE_ROOT="$2"; shift ;;
	-h|--help) 
	  SELFNAME=$(basename $BASH_SOURCE) 
	  echo "Usage: ${SELFNAME} [-q|--quiet] [-nc|--nocrypt] [-t|--target <targetdevice>]";
	  echo "";
	  echo "    ${SELFNAME}";
	  echo "      Will install encrypted arch linux.";
	  echo "";
	  echo "    ${SELFNAME} -nc.";
	  echo "      Will install unencrypted arch linux.";
	  echo "";
	  exit 0;
	  ;;
    *) echo "unknown parameter passed: ${1}."; exit 1;;
  esac
  shift
done


## Script must be started as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root";
  exit;
fi;

if [[ $(getSystemName) != "ARCHLINUX" ]]; then
  echo "This installer can only run on archlinux";
  exit;
fi;

# Install Dependencies
source "${BASH_SOURCE%/*}/scripts/dependencies.sh"

# Unmount possible earlier mounted stuff
source "${BASH_SOURCE%/*}/scripts/unmount.sh"

# Detect ROOT-Drive
source "${BASH_SOURCE%/*}/scripts/drive_detect.sh"

# Print INFO
echo
echo "System will be installed to: ${DRIVE_ROOT}"
if isTrue "${CRYPTED}"; then
	echo "The System will be encrypted with cryptsetup";
fi;
echo "Distribution will be: ${DISTRO}"
echo

# Get user confirmation
read -p "Continue? (Any data on the drive will be ereased) [yN]: " -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Script canceled by user";
    exit;   
fi

# Prepare drive
source "${BASH_SOURCE%/*}/scripts/drive_prepare.sh"

# Create Subvolumes
logLine "Creating BTRFS-Subvolumes on SYSTEM-Partition...";
if ! runCmd btrfs subvolume create /tmp/mnt/disks/system/@snapshots; then echo "Failed to create btrfs SNAPSHOTS-Volume"; exit; fi;
if ! runCmd btrfs subvolume create /tmp/mnt/disks/system/@swap; then echo "Failed to create btrfs SWAP-Volume"; exit; fi;
if ! runCmd btrfs subvolume create /tmp/mnt/disks/system/@logs; then echo "Failed to create btrfs LOGS-Volume"; exit; fi;
if ! runCmd btrfs subvolume create /tmp/mnt/disks/system/root-data; then echo "Failed to create btrfs ROOT-DATA-Volume"; exit; fi;
for subvolName in ${SUBVOLUMES}
do
	if ! runCmd btrfs subvolume create /tmp/mnt/disks/system/${subvolName,,}-data; then echo "Failed to create btrfs ${subvolName^^}-DATA-Volume"; exit; fi;
done;
	
# Mount Subvolumes
logLine "Mounting..."
mkdir -p /tmp/mnt/root
if ! runCmd mount -o subvol=/root-data ${PART_SYSTEM} /tmp/mnt/root; then echo "Failed to Mount Subvolume ROOT-DATA at /tmp/mnt/root"; exit; fi;
mkdir -p /tmp/mnt/root/boot
if ! runCmd mount ${PART_BOOT} /tmp/mnt/root/boot; then echo "Failed to mount BOOT-Partition"; exit; fi;

# Create Snapshot-Volume
mkdir -p /tmp/mnt/root/.snapshots
if ! runCmd mount -o subvol=@snapshots ${PART_SYSTEM} /tmp/mnt/root/.snapshots; then echo "Failed to Mount Snapshot-Volume at /tmp/mnt/root/.snapshots"; exit; fi;

# Create Swap-Volume and Swap-File
mkdir -p /tmp/mnt/root/.swap
if ! runCmd mount -o subvol=@swap ${PART_SYSTEM} /tmp/mnt/root/.swap; then echo "Failed to Mount Swap-Volume at /tmp/mnt/root/.swap"; exit; fi;
if ! runCmd truncate -s 0 /tmp/mnt/root/.swap/swapfile; then echo "Failed to truncate Swap-File at /tmp/mnt/root/.swap/swapfile"; exit; fi;
if ! runCmd chattr +C /tmp/mnt/root/.swap/swapfile; then echo "Failed to chattr Swap-File at /tmp/mnt/root/.swap/swapfile"; exit; fi;
if ! runCmd chmod 600 /tmp/mnt/root/.swap/swapfile; then echo "Failed to chmod Swap-File at /tmp/mnt/root/.swap/swapfile"; exit; fi;
if ! runCmd btrfs property set /tmp/mnt/root/.swap/swapfile compression none; then echo "Failed to disable compression for Swap-File at /tmp/mnt/root/.swap/swapfile"; exit; fi;
if ! runCmd fallocate /tmp/mnt/root/.swap/swapfile -l2g; then echo "Failed to fallocate 2G Swap-File at /tmp/mnt/root/.swap/swapfile"; exit; fi;
if ! runCmd mkswap /tmp/mnt/root/.swap/swapfile; then echo "Failed to mkswap for Swap-File at /tmp/mnt/root/.swap/swapfile"; exit; fi;

# Mount EFI
if [[ "${BIOSTYPE}" == "EFI" ]]; then
	mkdir -p /tmp/mnt/root/boot/efi
	if isEfiSystem; then
		if ! runCmd mount ${PART_EFI} /tmp/mnt/root/boot/efi; then echo "Failed to mount BOOT-Partition"; exit; fi;
	fi;
fi;

# Mount Subvolumes
for subvolName in ${SUBVOLUMES}
do
	mkdir -p /tmp/mnt/root/${subvolName,,}
	if ! runCmd mount -o subvol=/${subvolName,,}-data ${PART_SYSTEM} /tmp/mnt/root/${subvolName,,}; then echo "Failed to Mount Subvolume ${subvolName^^}-DATA at /tmp/mnt/root/${subvolName,,}"; exit; fi;
done;

# Mount logs
mkdir -p /tmp/mnt/root/var/log
if ! runCmd mount -o subvol=/@logs ${PART_SYSTEM} /tmp/mnt/root/var/log; then echo "Failed to Mount Subvolume LOGS-Volume at /tmp/mnt/root/var/log"; exit; fi;

# Install base system
logLine "Installing Base-System (${DISTRO^^})...";
source "${BASH_SOURCE%/*}/scripts/strap.sh";

# Generate fstab
genfstab -pL /tmp/mnt/root >> /tmp/mnt/root/etc/fstab;
if [ $? -ne 0 ]; then
	logLine "Failed to generate fstab";
	exit
fi;

if isTrue "${CRYPTED}"; then
	if ! runCmd sed -i 's#^LABEL=system#/dev/mapper/cryptsystem#g' /tmp/mnt/root/etc/fstab; then echo "Failed to modify fstab"; exit; fi;
fi;

if ! runCmd sed -i 's/,subvolid=[0-9]*//g' /tmp/mnt/root/etc/fstab; then echo "Failed to modify fstab"; exit; fi;
if ! runCmd sed -i 's/,subvol=\/[^,]*//g' /tmp/mnt/root/etc/fstab; then echo "Failed to modify fstab"; exit; fi;

# Add Swapfile to fstab
echo '# Swapfile' >> /tmp/mnt/root/etc/fstab
echo '/.swap/swapfile                 none                            swap    sw                                                      0 0' >> /tmp/mnt/root/etc/fstab

# Install CryptoKey
if isTrue "${CRYPTED}"; then
	if ! runCmd cp /tmp/crypto.key /tmp/mnt/root/etc/; then logLine "Failed to copy crypto.key"; exit; fi;
	if ! runCmd cp /tmp/crypto.header /tmp/mnt/root/etc/; then logLine "Failed to copy crypto.header"; exit; fi;
fi;

# Prepare ChRoot
source "${BASH_SOURCE%/*}/scripts/chroot_prepare.sh";

# Run installer
logLine "Setting up system...";
source "${BASH_SOURCE%/*}/scripts/chroot.sh";

# Question for CHROOT
sync
read -p "Your system has been installed. Do you want to chroot into the system now and make changes? [yN]: " -n 1 -r;
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]; then
    logLine "Entering chroot...";
    chroot /tmp/mnt/root /bin/bash;
	sync;
fi

# Restore resolve
logDebug "Restoring resolv.conf...";
source "${BASH_SOURCE%/*}/scripts/restoreresolv.sh";

# Question for reboot
read -p "Do you want to reboot into the system now? [Yn]: " -n 1 -r;
if [[ $REPLY =~ ^[Yy]$ ]] || [[ $REPLY =~ ^$ ]]; then
	sync;
	source "${BASH_SOURCE%/*}/scripts/unmount.sh";
	logLine "Rebooting...";
	reboot now;
	exit 0;
fi

# Finish
sync
logLine "Your system is ready! Type reboot to boot it.";
