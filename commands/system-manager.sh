#!/bin/bash
function printReceiverHelp() {
    echo "Usage: ${HOST_NAME} [-s|--snapshot <snapshotvolume>] [-b|--backup <backupvolume>] <client-command> <client-command-args...>";
    echo "";
    echo "If you omit the <backupvolume> then the script will try to locate it with the subvolume name @backups.";
    echo "If you omit the <snapshotvolume> then the script will try to locate it with the subvolume name @snapshots.";
    echo "";
    echo "Possible client-commands are:";
    printCommandLineProxyHelp --command-path "${BASH_SOURCE}";
}

# system-manager [-s|--snapshot <snapshotvolume>] [-b|--backup <backupvolume>] <client-command> <client-command-args...>
function receiver() {
    #local LOGFILE="/tmp/receiver.log";
    
    # Scan Arguments
    local HOST_ARGS=" [-r|--remote <ssh-uri>] [-s|--snapshots <snapshotvolume>]";
    local SNAPSHOTVOLUME="";
    local SSH_URI="";
    local RECEIVER_COMMAND="";
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -r|--remote) SSH_URI="$2"; shift;;
            -s|--snapshots) SNAPSHOTVOLUME="$2"; shift;;
            -h|--help) printReceiverHelp; exit 0;;
            -*) logError "Unknown Argument: $1"; printReceiverHelp; exit 1;;
            *) RECEIVER_COMMAND="${1}"; shift; break;;
        esac;
        shift;
    done;
    
    # Debug Variables
    logFunction "receiver#arguments --snapshotvolume \`${SNAPSHOTVOLUME}\` --remote\`${SSH_URI}\` \`${RECEIVER_COMMAND}\`";
    
    # Validate
    if [[ -z "${RECEIVER_COMMAND}" ]]; then
        logError "No command specified";
        printReceiverHelp;
        exit 1;
    fi;
    
    # Detect / check variables
    autodetect-server --uri "${SSH_URI}";
    autodetect-snapshotvolume --snapshotvolume "${SNAPSHOTVOLUME}";
    
    # Debug
    logFunction "receiver#expandedArguments --snapshotvolume \`${SNAPSHOTVOLUME}\` --remote\`${SSH_URI}\` \`${RECEIVER_COMMAND}\`";
    
    # Proxy
    if ! commandLineProxy --command-name "client-command" --command-value "${RECEIVER_COMMAND:-}" --command-path "${BASH_SOURCE}" $@; then printReceiverHelp; exit 1; fi;
    exit 0;
}

receiver $@;
exit 0;