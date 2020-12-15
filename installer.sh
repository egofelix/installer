#!/bin/bash

############### Main Script ################

## Load Functions
source "${BASH_SOURCE%/*}/functions.sh"

## Script must be started as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root";
  exit;
fi;

## We only support EFI systems for now
if ! isEfiSystem; then
  echo "Installer only works on EFI systems";
  exit;
fi;