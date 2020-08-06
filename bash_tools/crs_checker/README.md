# crs_checker
## Usage:
```
chmod +x crs_checker.sh
dos2unix crs_checker.sh
./crs_checker.sh <CheckpointHotfix1> <CheckpointHotfix2> 
```
Make sure the script is in the same directory as the hotfixes.

Script will print the hotfix CRs that are present in CheckpointHotfix1 and missing in CheckpointHotfix2. Script is great for seeing if your adhoc hotfix has been included into the Jumbo hotfix that you are wanting to upgrade to. If it's missing open a ticket with Checkpoint support and ask for a portfix task with R&D. Make sure you provide support with a CPInfo file!