#!/bin/bash
set -uo pipefail

############### Main Script ################
## Load Functions
source "${BASH_SOURCE%/*}/includes/functions.sh"

# We must have first parameter
if [[ -z "$1" ]]; then
	echo "Missing Home dir in first paramete";
	exit 1;
fi;

# Update home for this script
HOME=$1
shift 1;

# Test if home is on btrfs and @ mount
MOUNTPOINT=$(findmnt -n -o SOURCE --target ${HOME})
if [[ $? -ne 0 ]] || [[ -z "${MOUNTPOINT}" ]]; then 
  echo "Could not find MOUNTPOINT for ${HOME}."; exit 1;
fi;
MOUNTDEVICE=$(echo "${MOUNTPOINT}" | awk -F'[' '{print $1}')
if [[ -z "${MOUNTDEVICE}" ]]; then 
  echo "Could not find MOUNTDEVICE for ${MOUNTPOINT}."; exit 1;
fi;
MOUNTVOLUME=$(echo "${MOUNTPOINT}" | awk -F'[' '{print $2}' | awk -F']' '{print $1}')
if [[ -z "${MOUNTVOLUME}" ]]; then 
  echo "Could not find MOUNTVOLUME for ${MOUNTPOINT}."; exit 1;
fi;
if [[ ! ${MOUNTVOLUME} = *"@"* ]]; then
  echo "Could not backup to ${HOME} as this does not lie on a @ subvolume."; exit 1;
fi;

# We must have first parameter
if [[ -z "$1" ]]; then
	echo "Missing command";
	exit 1;
fi;

# Main Commands
if [[ "$1" = "testSshReceiver" ]]; then
  echo "success"; exit 0;
fi;

if [[ "$1" = "create-volume-directory" ]]; then
  # Check Argument Count
  if [[ -z "$2" ]]; then echo "Usage: create-volume-directory volume"; exit 1; fi;
 
  # Check volume parameter
  if [[ $2 = *"."* ]]; then echo "Illegal character . detected in parameter volume."; exit 1;  fi;
  
  # Create directory
  if ! runCmd mkdir -p ${HOME}/$2; then echo "Error creating directory."; exit 1; fi;
  echo "success"; exit 0;
fi;

if [[ "$1" = "check-volume-backup" ]]; then
  # Check Argument Count
  if [[ -z "$2" ]] || [[ -z "$3" ]]; then echo "Usage: check-volume-backup volume backup"; exit 1; fi;
  
  # Check volume parameter
  if [[ $2 = *"."* ]]; then echo "Illegal character . detected in parameter volume."; exit 1;  fi;
  
  # Check backup parameter
  if [[ $3 = *"."* ]]; then echo "Illegal character . detected in parameter backup."; exit 1;  fi;
  
  # Test and return
  if [[ ! -d "${HOME}/$2/$3" ]]; then echo "false"; exit 0; fi;
  echo "true"; exit 0;
fi;

if [[ "$1" = "create-volume-backup" ]]; then
  # Check Argument Count
  if [[ -z "$2" ]] || [[ -z "$3" ]]; then echo "Usage: check-volume-backup volume backup"; exit 1; fi;
  
  # Check volume parameter
  if [[ $2 = *"."* ]]; then echo "Illegal character . detected in parameter volume."; exit 1;  fi;
  
  # Check backup parameter
  if [[ $3 = *"."* ]]; then echo "Illegal character . detected in parameter backup."; exit 1;  fi;

  if [[ -d "${HOME}/$2/$3" ]]; then echo "backup already exists"; exit 0; fi;
  
  # Receive  
  btrfs receive -q ${HOME}/$2 < /dev/stdin
  if [ $? -ne 0 ]; then 
    # Remove broken backup
    btrfs subvol del ${HOME}/$2/$3
	
	# Return error
    echo "backup receive failed";
	exit 1;
  fi;
  
  # Backup received
  echo "success"; exit 0;
fi;

if [[ "$1" = "list-volumes" ]]; then
  # Create directory
  RESULT=$(ls ${HOME})
  if [ $? -ne 0 ]; then echo "Error listing volumes."; exit 1; fi;
  exit 0;
fi;

if [[ "$1" = "list-volume" ]]; then
  # Check Argument Count
  if [[ -z "$2" ]]; then echo "Usage: list-volume volume"; exit 1; fi;
 
  # Check volume parameter
  if [[ $2 = *"."* ]]; then echo "Illegal character . detected in parameter volume."; exit 1;  fi;
  
  # Create directory
  ls ${HOME}/$2
  if [ $? -ne 0 ]; then echo "Error listing volume $2."; exit 1; fi;
  exit 0;
fi;

if [[ "$1" = "receive-volume-backup" ]]; then
  # Check Argument Count
  if [[ -z "$2" ]] || [[ -z "$3" ]]; then echo "Usage: receive-volume-backup volume backup"; exit 1; fi;
  
  # Check volume parameter
  if [[ $2 = *"."* ]]; then echo "Illegal character . detected in parameter volume."; exit 1;  fi;
  
  # Check backup parameter
  if [[ $3 = *"."* ]]; then echo "Illegal character . detected in parameter backup."; exit 1;  fi;

  # Check if backup exists
  if [[ ! -d "${HOME}/$2/$3" ]]; then echo "backup does not exists"; exit 0; fi;

  # Send Backup
  btrfs send -q ${HOME}/$2/$3
  if [ $? -ne 0 ]; then echo "Error sending volumes."; exit 1; fi;
  exit 0;
fi;

echo "Error";
exit 1;