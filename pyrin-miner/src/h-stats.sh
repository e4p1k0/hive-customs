####################################################################################
###
### pyrin-miner
###
### Hive integration: Shatll
###
####################################################################################

#!/usr/bin/env bash

#######################
# MAIN script body
#######################

. /hive/miners/custom/pyrin-miner/h-manifest.conf
stats_raw=`cat $CUSTOM_LOG_BASENAME.log | grep -w "hashrate" | tail -n 1 `
#echo $stats_raw

#Calculate miner log freshness

maxDelay=120
time_now=`date +%s`
datetime_rep=`echo $stats_raw | awk '{print $1}' | awk -F[ '{print $2}'`
time_rep=`date -d $datetime_rep +%s`
diffTime=`echo $((time_now-time_rep)) | tr -d '-'`

if [ "$diffTime" -lt "$maxDelay" ]; then
        [[ $stats_raw == *"Ghash"* ]] && multiplier=1000000 || multiplier=1000
        miner_total_hr_raw=`echo "$stats_raw" | awk '{print $7}'`
        total_hashrate=`echo "scale=0; $miner_total_hr_raw * $multiplier / 1" | bc -l`

        #GPU Status
        gpu_stats=$(< $GPU_STATS_JSON)

        readarray -t gpu_stats < <( jq --slurp -r -c '.[] | .busids, .brand, .temp, .fan | join(" ")' $GPU_STATS_JSON 2>/dev/null)
        busids=(${gpu_stats[0]})
        brands=(${gpu_stats[1]})
        temps=(${gpu_stats[2]})
        fans=(${gpu_stats[3]})
        gpu_count=${#busids[@]}

        hash_arr=()
        busid_arr=()
        fan_arr=()
        temp_arr=()
        lines=()

        if [ $(gpu-detect NVIDIA) -gt 0 ]; then
                brand_gpu_count=$(gpu-detect NVIDIA)
                BRAND_MINER="nvidia"
        elif [ $(gpu-detect AMD) -gt 0 ]; then
                brand_gpu_count=$(gpu-detect AMD)
                BRAND_MINER="amd"
        fi

		[[ `cat $GPU_STATS_JSON | jq '.brand | contains(["cpu"])'` == true ]] && shift=1 || shift=0

        for(( i=0; i < gpu_count; i++ )); do
			jqNumber=`echo "$i+$shift" | bc`
            [[ "${brands[jqNumber]}" != $BRAND_MINER ]] && continue
            [[ "${busids[jqNumber]}" =~ ^([A-Fa-f0-9]+): ]]
            busid_arr+=($((16#${BASH_REMATCH[1]})))
            temp_arr+=(${temps[jqNumber]})
            fan_arr+=(${fans[jqNumber]})                
            gpu_raw=`cat $CUSTOM_LOG_BASENAME.log | grep -w "Device #"$i | tail -n 1 `
            hr_raw=`echo $gpu_raw | awk '{print $(NF-1)}'`
            [[ $gpu_raw == *"Ghash"* ]] && multiplier=1000000 || multiplier=1000
            hashrate=`echo "scale=0; $hr_raw * $multiplier / 1" | bc -l`
            hash_arr+=($hashrate)		
        done

        hash_json=`printf '%s\n' "${hash_arr[@]}" | jq -cs '.'`
        bus_numbers=`printf '%s\n' "${busid_arr[@]}"  | jq -cs '.'`
        fan_json=`printf '%s\n' "${fan_arr[@]}"  | jq -cs '.'`
        temp_json=`printf '%s\n' "${temp_arr[@]}"  | jq -cs '.'`

        uptime=$(( `date +%s` - `stat -c %Y $CUSTOM_CONFIG_FILENAME` ))


        #Compile stats/khs
        stats=$(jq -nc \
                --argjson hs "$hash_json"\
                --arg ver "$CUSTOM_VERSION" \
                --arg ths "$total_hashrate" \
                --argjson bus_numbers "$bus_numbers" \
                --argjson fan "$fan_json" \
                --argjson temp "$temp_json" \
                --arg uptime "$uptime" \
                '{ hs: $hs, hs_units: "khs", algo : "heavyhash", ver:$ver , $uptime, $bus_numbers, $temp, $fan}')
        khs=$total_hashrate
else
  khs=0
  stats="null"
fi

echo Debug info:
echo Log file : $CUSTOM_LOG_BASENAME.log
echo Time since last log entry : $diffTime
echo Raw stats : $stats_raw
echo KHS : $khs
echo Output : $stats

[[ -z $khs ]] && khs=0
[[ -z $stats ]] && stats="null"
