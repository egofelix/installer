#!/bin/bash
function printHelp() {
    #echo "";
    #logWarn "ssh-client is not intended to be called by yourself.";
    #echo "";
    
    echo "Usage: ${HOST_NAME} -t|--target <backupvolume> <command> <command-args...>";
    echo "";
    echo "Possible commands are:";
    printCommandLineProxyHelp --command-path "${BASH_SOURCE}";
    echo "";
}

# ssh-client -t|--target <backupvolume> <client-command> <client-command-args...>
function receiver() {
    #local LOGFILE="/tmp/receiver.log";
    
    
    # Scan Arguments
    local BACKUPVOLUME="";
    local RECEIVER_COMMAND="";
    local MANAGED="false";
    local KEY_MANAGER="false";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --managed) MANAGED="true";;
            --key-manager) KEY_MANAGER="true";;
            -t|--target) BACKUPVOLUME="$2"; shift;;
            -h|--help) ;;
            -*) logError "Unknown Argument: $1"; printHelp; exit 1;;
            *) RECEIVER_COMMAND="${1}"; shift; break;;
        esac;
        shift;
    done;
    
    if ! isTrue "${MANAGED}"; then
        logWarn "\`${HOST_NAME}\` should not be called by user direct, instead reference it in authorized_keys.";
    fi;
    
    if isTrue "${HOST_HELP}"; then
        if [[ -z "${RECEIVER_COMMAND:-}" ]]; then printHelp; exit 1; fi;
        if ! commandLineProxy --command-name "command" --command-value "${RECEIVER_COMMAND:-}" --command-path "${BASH_SOURCE}"${HOST_HELP_FLAG} $@; then printHelp; exit 1; fi;
        exit 0;
    fi;
    
    # Debug Variables
    logFunction "receiver#arguments \`${RECEIVER_COMMAND}\`";
    
    # Validate
    if [[ -z "${RECEIVER_COMMAND}" ]]; then
        logError "No command specified";
        printHelp;
        exit 1;
    fi;
    
    # Validate
    if isEmpty ${BACKUPVOLUME}; then
        logError "<backupvolume> cannot be empty";
        printHelp;
        exit 1;
    fi;
    if ! autodetect-backupvolume --backupvolume "${BACKUPVOLUME}"; then logError "<backupvolume> cannot be empty"; exit 1; fi;
    #if [[ -z "${USERNAME}" ]]; then logError "<username> cannot be empty"; exit 1; fi;
    #if containsIllegalCharacter "${USERNAME}"; then logError "Illegal character detected in <username> \"${USERNAME}\"."; return 1; fi;
    
    # Proxy
    if ! commandLineProxy --command-name "command" --command-value "${RECEIVER_COMMAND:-}" --command-path "${BASH_SOURCE}" $@; then printHelp; exit 1; fi;
}

receiver $@;
exit 0;