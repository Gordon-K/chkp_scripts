#!/bin/bash

#--------------------------------------------------------------------
# Variables
#--------------------------------------------------------------------
USERNAME=""
PASSWORD=""

#--------------------------------------------------------------------
# Functions
#--------------------------------------------------------------------
function get_credentials()
{
    printf "=====================================================\n"
    printf "Enter credentials for mgmt_cli commands:\n"
    printf "=====================================================\n"
    printf "Username: "
    read USERNAME
    printf "Password: "
    read -s PASSWORD
    echo ""
}

function disable_ips_scheduled_update()
{
    # Disable IPS Scheduled Update on all domains
    printf "=====================================================\n"
    printf "Disabling IPS Scheduled Updates for ALL domains:\n"
    printf "=====================================================\n"

    for domain in $(mgmt_cli -r true show domains | grep "\- uid" -A1 | grep name | awk '{print $2}' | sed $'s/[^[:print:]\t]//g')
    do
        printf "Disabling IPS Scheduled updates for $domain... "
        mgmt_cli set ips-update-schedule enabled false -u $USERNAME -p $PASSWORD -d $domain 1>/dev/null 2>&1

        # Print success if scheduled update is disabled
        if [[ $(mgmt_cli show ips-update-schedule -u $USERNAME -p $PASSWORD -d $domain | head -1) == *"false"* ]]; then
            printf "$(tput setaf 2)Success!$(tput sgr 0)\n"
        else
            printf "$(tput setaf 1)Failed!$(tput sgr 0)\n"
        fi
    done
}

function check_ips_scheduled_update_status()
{
    # Disable IPS Scheduled Update on all domains
    printf "=====================================================\n"
    printf "Checking IPS Scheduled Updates for ALL domains:\n"
    printf "=====================================================\n"
    for domain in $(mgmt_cli -r true show domains | grep "\- uid" -A1 | grep name | awk '{print $2}' | sed $'s/[^[:print:]\t]//g')
    do
        printf "$domain... "
        if [[ $(mgmt_cli show ips-update-schedule -u $USERNAME -p $PASSWORD -d $domain | head -1) == *"false"* ]]; then
            printf "$(tput setaf 2)Enabled!$(tput sgr 0)\n"
        else
            printf "$(tput setaf 1)Disabled!$(tput sgr 0)\n"
        fi
    done
}

#--------------------------------------------------------------------
# Main
#--------------------------------------------------------------------
clear
get_credentials
# disable_ips_scheduled_update
check_ips_scheduled_update_status