#!/bin/bash

#
# Name: crs_checker.sh
# Author: Kernel Gordon
# Date: 2020-08-06
# Purpose: Read through two hotfix files and determine from the crs.xml
#           files inside if all fixes from hotfix1 are included in 
#           hotfix2.
#

#--------------------------------------------------------------------
# Dependancies
#--------------------------------------------------------------------


#--------------------------------------------------------------------
# Variables
#--------------------------------------------------------------------
HOTFIX1=$1
HOTFIX2=$2

#--------------------------------------------------------------------
# Functions
#--------------------------------------------------------------------


#--------------------------------------------------------------------
# Main
#--------------------------------------------------------------------
if [[ $# != 2 ]]
then
    printf "Need 2 fixes to compare\n"
    exit 1
fi

# tar -tf "$HOTFIX1" | grep -E ".tgz|crs.xml"

for FILE in hotfix1/
do
    if [[ "$FILE" == *".tgz" ]]
    then
        echo "a"
    else
        echo "B"  
    fi
done