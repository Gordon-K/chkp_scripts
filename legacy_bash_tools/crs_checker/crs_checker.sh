#!/bin/bash

#
# Name: crs_checker.sh
# Author: Kernel Gordon
# Date: 2020-08-06
# Purpose: Read through two hotfix files and determine from the crs.xml
#           files inside if all fixes from hotfix1 are included in 
#           hotfix2. Hotfixes need to be in the same dir as the script.
#

#--------------------------------------------------------------------
# Dependancies
#--------------------------------------------------------------------


#--------------------------------------------------------------------
# Variables
#--------------------------------------------------------------------
HOTFIX1=$(basename -- "$1")
HOTFIX2=$(basename -- "$2")

#--------------------------------------------------------------------
# Functions
#--------------------------------------------------------------------
function crs_aggregator()
{
    # Check for crs.xml and more archives that it could be hiding in
    FILES=$(tar -tf "$1" | grep -E ".tgz|crs.xml" | grep "CheckPoint#")

    rm -rf tmp
    mkdir tmp
    rm -rf HOTFIX"$2"_crs.xml
    for FILE in $FILES
    do
        # MODULE=$(echo $FILE | awk -F "#" '{print $2}')
        tar zxf "$1" -C tmp/ "$FILE" 2>/dev/null

        if [[ "$FILE" == "crs.xml" ]]
        then
            cat tmp/crs.xml >> HOTFIX"$2"_crs.xml 2>/dev/null
        else
            tar zxf tmp/"$FILE" -C tmp/ "crs.xml" 2>/dev/null
            cat tmp/crs.xml >> HOTFIX"$2"_crs.xml 2>/dev/null
        fi
    done
}

#--------------------------------------------------------------------
# Main
#--------------------------------------------------------------------
# Check for enough args
if [[ $# != 2 ]]
then
    printf "Need 2 fixes to compare\n"
    exit 1
fi

# Put contents of all crs.xml files into a single file per hotfix
crs_aggregator $HOTFIX1 1
crs_aggregator $HOTFIX2 2

# Find all CRs in HOTFIX1
CRS_HOTFIX1=$(grep -oE "crs=\".*\"" HOTFIX1_crs.xml | sed -e 's/crs=//gi' -e 's/"//gi') 

# Find missing CRs in HOTFIX2
IFS=","
for CR in $CRS_HOTFIX1
do
    if [[ ! $(grep $CR HOTFIX2_crs.xml) ]]
    then
        printf "Missing: $CR\n"
    fi
done
unset IFS
rm -rf tmp