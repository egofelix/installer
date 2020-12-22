#!/bin/bash
if [[ $(getSystemName) = "ARCHLINUX" ]]; then
	source "${BASH_SOURCE%/*}/../systems/archlinux/bootmanager.sh"
else
	logLine "Unknown system detected... Aborting"
	exit 1;
fi;