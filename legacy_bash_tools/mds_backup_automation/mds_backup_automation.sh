#!/bin/bash

#
# Name: mds_backup_automation.sh
# Author: Kernel Gordon
# Purpose: Automade MDS backup and xfer from device
#

#--------------------------------------------------------------------
# Variables
#--------------------------------------------------------------------
TRUE=1
FALSE=0

DBG_ENABLED=$FALSE      # Debugging of script disabled by default

REMOTE_SERVER_IP=""     # Remote server we will upload mds_backup to
REMOTE_SERVER_USER=""   # Username for remote server login
REMOTE_SERVER_PASS=""   # Password for remote server login

BACKUP_FILE_LOCATION=/var/log/tmp/daily_backup      # mds_backup output directory
BACKUP_SIZE_REQUIRED=$((50 * 1024 * 1024))          # Number of MB required to take mds_backup

#--------------------------------------------------------------------
# Functions
#--------------------------------------------------------------------
# Prints script usage to terminal
function PrintHelpText()
{
    printf "$0 USAGE:\n"
    printf "\t$0 [-d|--debug] [-s|--server (remote_server_ip)] \
            [-u|--username (username)] [-p|--password (password)]\n"
}

# Checks for valid IP
function bIsValidIP()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

# Checks for enough space to take mds_backup

#--------------------------------------------------------------------
# Arg handling
#--------------------------------------------------------------------
# Check for valid arg count
# Args should be in pairs of two so there should always be an
#  even number of args
if [[ $# > 0 ]]; then # Script run with args
    # Debugging
    if [[ $1 == "-d" || $1 == "--debug" ]]; then
        DBG_ENABLED=$TRUE
        shift
    fi

    if [[ $(( $# % 2 )) == 0 ]]; then
        if [ $DBG_ENABLED == $TRUE ]; then # DEBUG: Arg validation
            printf "DEBUG: Valid arg count\n"
            printf "DEBUG: Arg Count: $#\n"
        fi
    else
        printf "ERROR: Invalid arg count\n"
        PrintHelpText
        exit 1
    fi
else # Script run without args
    PrintHelpText
    exit 1
fi

# Read args
while [[ $# > 0 ]]; do
    ARG_FLAG="$1"

    case $ARG_FLAG in
    # Remote server we will upload mds_backup to
    -s|--server)     
        if bIsValidIP $2; then   
            REMOTE_SERVER_IP=$2     # Set remote server to CLI arg
            shift                   # past ARG_FLAG
            shift                   # past ARG
        else
            printf "$2 is not a valid IP address!\n"
            exit 1
        fi
    ;;

    # Username for remote server login
    -u|--username)
        REMOTE_SERVER_USER=$2   # Set remote server username to CLI arg
        shift                   # past ARG_FLAG
        shift                   # past ARG
    ;;

    # Password for remote server login
    -p|--password)
        REMOTE_SERVER_PASS=$2   # Set remote server password to CLI arg
        shift                   # past ARG_FLAG
        shift                   # past ARG
    ;;

    # Unknown option
    *)                  
        printf "ERROR: Unknown arg '$1'.\n"
        PrintHelpText
        exit 1
    ;;
    esac
done

#--------------------------------------------------------------------
# Main
#--------------------------------------------------------------------
if [ $DBG_ENABLED == $TRUE ]; then # DEBUG: Remote server info
    printf "DEBUG: Remote Server IP - $REMOTE_SERVER_IP\n"
    printf "DEBUG: Remote Server User - $REMOTE_SERVER_USER\n"
    printf "DEBUG: Remote Server Pass - $REMOTE_SERVER_PASS\n"
fi

# Check if output dir exists
printf "INFO: Checking if $BACKUP_FILE_LOCATION exists\n"
if [[ -d "$BACKUP_FILE_LOCATION" ]]; then # dir found
    printf "INFO: $BACKUP_FILE_LOCATION found. Proceeding...\n"
else # dir not found
    printf "WARN: $BACKUP_FILE_LOCATION does not exist! Making dir!\n"
    mkdir -p "$BACKUP_FILE_LOCATION"
fi

# Check if there is enough free space in output dir partition
printf "INFO: Checking free space in $(df | tail -1 | awk '{print $1}') partition.\n"
FREE_SPACE_LOCAL="$(df $BACKUP_FILE_LOCATION | tail -1 | awk '{print $4}')"

if [ $DBG_ENABLED == $TRUE ]; then # DEBUG: Available space check
    printf "DEBUG: FREE_SPACE_LOCAL=$FREE_SPACE_LOCAL\n"
    printf "DEBUG: BACKUP_SIZE_REQUIRED=$BACKUP_SIZE_REQUIRED\n"
fi

if [[ "$FREE_SPACE_LOCAL" -gt "$BACKUP_SIZE_REQUIRED" ]]; then
    printf "INFO: $((FREE_SPACE_LOCAL / 1024 / 1024))G available in $BACKUP_FILE_LOCATION\n"
else
    printf "ERROR: Not enough space to create mds_backup locally\n"
    exit 1
fi

# Stop all MDS processes
# mdsstop
# killall -9 fwm

