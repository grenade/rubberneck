#!/usr/bin/env bash

declare -a fqdn_list=()
fqdn_list+=( frootmig.thgttg.com )

while true; do
    for fqdn in ${fqdn_list[@]}; do
        status=$(ssh ${fqdn} 'monerod --rpc-bind-port 18089 status' | tr --squeeze-repeats '\n\t' ' ')
        echo "${fqdn} ${status}"
    done
done
