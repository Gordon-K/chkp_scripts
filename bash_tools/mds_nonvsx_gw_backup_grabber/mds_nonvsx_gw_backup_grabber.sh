#!/bin/bash

#
# Name: mds_nonvsx_gw_backup_grabber.sh
# Author: Kernel Gordon
# Date: 2020-08-06
# Purpose: Gather Gaia Clish config from all GWs managed by MDS
#

#--------------------------------------------------------------------
# Dependancies
#--------------------------------------------------------------------
source $CPDIR/tmp/.CPprofile.sh     # Make Checkpoint internals work in script

#--------------------------------------------------------------------
# Variables
#--------------------------------------------------------------------
TODAY=$(date +%F)

LOG_DIR="/var/log/fwbackups"
LOG_FILE="$LOG_DIR/fwbackup.log"
LOG_GW_LIST="$LOG_DIR/gw_list.txt"

#--------------------------------------------------------------------
# Functions
#--------------------------------------------------------------------
function gather_backup_info()
{
    while IFS= read -r line
    do
        if [[ $line == "CMA_NAME:"* ]] # Change domains
        then
            # TODO: Format string better
            CMA_NAME=$(echo "$line" | awk -F ": " '{print $2}') # Keep the space or it breaks; see above TODO
            mdsenv "$CMA_NAME"
            printf "[$(date +%T)] [INFO]: Moved to $CMA_NAME context\n" >> $LOG_FILE
            continue
        else # Run cprid commands per GW
            DEVICE_DETAILS=$(echo "$line" | awk '{print $1";"$2}')

            # Update date
            TODAY=$(date +%F)

            # Update device info
            DEVICE_HOSTNAME=$(echo "$DEVICE_DETAILS" | awk -F ";" '{print $1}')
            DEVICE_IP=$(echo "$DEVICE_DETAILS" | awk -F ";" '{print $2}')
            BACKUP_FILE="$LOG_DIR/$DEVICE_HOSTNAME-$TODAY"

            # Check for cprid_util connectivity
            if [[ $(cprid_util -server $DEVICE_IP -verbose -debug rexec -rcmd /bin/bash -c "free") == *"(NULL BUF)"* ]]; then
                printf "[$(date +%T)] [ERROR]: Unable to connect to $DEVICE_HOSTNAME ($DEVICE_IP) via cprid_util!\n" >> $LOG_FILE
                printf "\tConfirm that port 18208 is allowed to the device and that cprid and cprid_wd are running on device.\n" >> $LOG_FILE
                continue
            else
                printf "[$(date +%T)] [INFO]: Connected to $DEVICE_HOSTNAME ($DEVICE_IP) via cprid_util\n" >> $LOG_FILE
            fi

            # Run backup commands
            touch $BACKUP_FILE
            printf "[$(date +%T)] [INFO]: Created $BACKUP_FILE\n" >> $LOG_FILE

            # cprid_util -server $DEVICE_IP -verbose rexec -rcmd bash -c "mkdir -p $LOG_DIR"

            printf "===================================================\n" >> "$BACKUP_FILE"
            printf "Gaia Clish Config\n" >> "$BACKUP_FILE"
            printf  "$TODAY\n" >> "$BACKUP_FILE"
            printf "===================================================\n" >> "$BACKUP_FILE"
            cprid_util -server $DEVICE_IP -verbose rexec -rcmd clish -c "show configuration" > "$BACKUP_FILE"

            # TODO: Add check for changes to beloew files; if change make backup else don't
            printf "===================================================\n" >> "$BACKUP_FILE"
            printf "Dynamic Objects\n" >> "$BACKUP_FILE"
            printf  "\$FWDIR/database/dynamic_objects.db\n" >> "$BACKUP_FILE"
            printf "===================================================\n" >> "$BACKUP_FILE"
            cprid_util -server $DEVICE_IP -verbose rexec -rcmd bash -c "cat \$FWDIR/database/dynamic_objects.db" >> "$BACKUP_FILE" 2>&1
            cprid_util -server $DEVICE_IP -verbose rexec -rcmd bash -c "cp \$FWDIR/database/dynamic_objects.db \$FWDIR/database/dynamic_objects.$TODAY" >> "$BACKUP_FILE" 2>&1

            printf "===================================================\n" >> "$BACKUP_FILE"
            printf "Proxy ARP\n" >> "$BACKUP_FILE"
            printf  "\$FWDIR/conf/local.arp\n" >> "$BACKUP_FILE"
            printf "===================================================\n" >> "$BACKUP_FILE"
            cprid_util -server $DEVICE_IP -verbose rexec -rcmd bash -c "cat \$FWDIR/conf/local.arp" >> "$BACKUP_FILE" 2>&1
            cprid_util -server $DEVICE_IP -verbose rexec -rcmd bash -c "cp \$FWDIR/conf/local.arp \$FWDIR/conf/local.arp.$TODAY" >> "$BACKUP_FILE" 2>&1

            printf "===================================================\n" >> "$BACKUP_FILE"
            printf "Kernel Parameters\n" >> "$BACKUP_FILE"
            printf  "\$FWDIR/boot/modules/fwkern.conf\n" >> "$BACKUP_FILE"
            printf "===================================================\n" >> "$BACKUP_FILE"
            cprid_util -server $DEVICE_IP -verbose rexec -rcmd bash -c "cat \$FWDIR/boot/modules/fwkern.conf" >> "$BACKUP_FILE" 2>&1
            cprid_util -server $DEVICE_IP -verbose rexec -rcmd bash -c "cp \$FWDIR/boot/modules/fwkern.conf \$FWDIR/boot/modules/fwkern.conf.$TODAY" >> "$BACKUP_FILE" 2>&1
        fi

    done < $LOG_GW_LIST
}

function generate_list_of_gateways()
{
    # Go to MDS context
    mdsenv
    # mcd 1> /dev/null 2>&1

    # Make new list of GWs
    printf "" > $LOG_GW_LIST
    if [[ -f $LOG_GW_LIST ]]; then
        printf "[$(date +%T)] [INFO]: Cleared $LOG_GW_LIST\n" >> $LOG_FILE
    else
        printf "[$(date +%T)] [ERROR]: Unable to create $LOG_GW_LIST!\n" >> $LOG_FILE
        exit 1
    fi

    # Iterate over the CMAs
    for CMA_NAME in $($MDSVERUTIL AllCMAs)
    do
        mdsenv $CMA_NAME
        printf "" >> $LOG_GW_LIST
        printf "CMA_NAME: $CMA_NAME\n" >> $LOG_GW_LIST
        # printf "===================================================\n" >> $LOG_GW_LIST
        $MDSDIR/bin/cpmiquerybin attr "" network_objects \
            "class='gateway_ckp'|class='cluster_member'" \
            -a __name__,ipaddr,svn_version_name,appliance_type | sed 's/MISSING_ATTR//g' >> $LOG_GW_LIST
    done
}

#--------------------------------------------------------------------
# Main
#--------------------------------------------------------------------
mkdir -p $LOG_DIR
printf "===================================================\n" >> $LOG_FILE
printf "Starting $0 -- $(date)\n" >> $LOG_FILE
printf "===================================================\n" >> $LOG_FILE

which cprid_util 1> /dev/null 2>&1
if [ "$?" -ne 0 ];
then
  printf "[$(date +%T)] [ERROR]: Could not find the 'cprid_util' executable. Exiting...\n" >> $LOG_FILE
  exit 1
fi

generate_list_of_gateways
gather_backup_info

exit