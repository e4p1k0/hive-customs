####################################################################################
###
### pyrin-miner
###
### Hive integration: Shatll
###
####################################################################################

#!/usr/bin/env bash
[[ -e /hive/custom ]] && . /hive/custom/pyrin-miner/h-manifest.conf
[[ -e /hive/miners/custom ]] && . /hive/miners/custom/pyrin-miner/h-manifest.conf
conf=""
conf+=" -s $CUSTOM_URL -a $CUSTOM_TEMPLATE"


[[ ! -z $CUSTOM_USER_CONFIG ]] && conf+=" $CUSTOM_USER_CONFIG"

echo "$conf"
echo "$conf" > $CUSTOM_CONFIG_FILENAME

