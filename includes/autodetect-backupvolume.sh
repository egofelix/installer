function autodetect-backupvolume() {
    if [[ ! -z "${BACKUPVOLUME:-}" ]]; then
        logDebug "Skipping autodetect-backupvolume, using Cache...";
        return 0;
    fi;
    
    # Search BACKUPVOLUME via Environment or AutoDetect
    if isEmpty "${BACKUPVOLUME:-}"; then export BACKUPVOLUME=$(LC_ALL=C mount | grep '@backups' | grep -o 'on /\..* type btrfs' | awk '{print $2}'); fi;
    if isEmpty "${BACKUPVOLUME}"; then logError "Cannot find @backups directory"; exit 1; fi;
    
    # Test if SNAPSHOTSPATH is a btrfs subvol
    logDebug "BACKUPVOLUME: ${BACKUPVOLUME}";
    if isEmpty $(LC_ALL=C mount | grep "${BACKUPVOLUME}" | grep 'type btrfs'); then logError "<backupvolume> \"${BACKUPVOLUME}\" must be a btrfs volume"; exit 1; fi;
    
    # Get Volumename from Path
    local TESTMOUNT=$(LC_ALL=C findmnt -n -o SOURCE --target "${BACKUPVOLUME}")
    if [[ $? -ne 0 ]] || [[ -z "${TESTMOUNT}" ]]; then logWarn "Could not verify volumename for \"${BACKUPVOLUME}\"."; return 0; fi;
    
    local TESTDEVICE=$(echo "${TESTMOUNT}" | awk -F'[' '{print $1}')
    if [[ -z "${TESTDEVICE}" ]]; then logWarn "Could not find device for ${TESTDEVICE}."; return 0; fi;
    
    local TESTVOLUME=$(echo "${TESTMOUNT}" | awk -F'[' '{print $2}' | awk -F']' '{print $1}')
    if [[ -z "${TESTVOLUME}" ]]; then logError "Could not find volume for ${TESTVOLUME}."; return 0; fi;
    
    if [[ ! ${TESTVOLUME} = "@"* ]] && [[ ! ${TESTVOLUME} = "/@"* ]]; then
        logWarn "The target directory relies on volume \"${TESTVOLUME}\" which will also be snapshotted/backuped, consider using a targetvolume with an @ name...";
    fi;
    
    return 0;
    
}