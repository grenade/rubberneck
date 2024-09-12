#!/usr/bin/env bash

_decode_property() {
  echo ${1} | base64 --decode | jq -r ${2}
}

declare -a fqdn_list=()
fqdn_list+=( allitnils.thgttg.com )
fqdn_list+=( anjie.thgttg.com )
fqdn_list+=( blart.thgttg.com )
fqdn_list+=( bob.thgttg.com )
fqdn_list+=( caveman.thgttg.com )
fqdn_list+=( colin.thgttg.com )
fqdn_list+=( effrafax.thgttg.com )
fqdn_list+=( frootmig.thgttg.com )
fqdn_list+=( gallumbits.thgttg.com )
fqdn_list+=( golgafrinchans.thgttg.com )
fqdn_list+=( gramathea.thgttg.com )
fqdn_list+=( hawalius.thgttg.com )
fqdn_list+=( krikkit.thgttg.com )
fqdn_list+=( midgard.thgttg.com )
fqdn_list+=( mitko.thgttg.com )
fqdn_list+=( novgorodian.thgttg.com )
fqdn_list+=( quordlepleen.thgttg.com )
fqdn_list+=( slartibartfast.thgttg.com )
fqdn_list+=( midgard.v8r.io )

remote_path=/tmp/passmark-$(date --iso).json

for fqdn in ${fqdn_list[@]}; do
  local_path=/tmp/passmark/$(date --iso)/${fqdn}/passmark.json
  mkdir -p $(dirname ${local_path})
  if [ -s ${local_path} ] || rsync -e "ssh -o ConnectTimeout=1" -a ${fqdn}:${remote_path} ${local_path} 2> /dev/null; then
    echo "- ${fqdn}"
    passmark_os=$(jq -r .SystemInformation.OSName ${local_path})
    passmark_kernel=$(jq -r .SystemInformation.Kernel ${local_path})
    passmark_processor=$(jq -r .SystemInformation.Processor ${local_path} | tr -s ' ')
    passmark_ram_total_bytes=$(jq -r .SystemInformation.Memory ${local_path})
    passmark_ram_total_gb=$((passmark_ram_total_bytes >> 10))
    passmark_ram_slots_total=$(jq -r .SystemInformation.MemModuleInfo.iNumMemSticks ${local_path})
    passmark_ram_slots_occupied=$(jq -r '[ .SystemInformation.MemModuleInfo | to_entries[] | select(.key != "iNumMemSticks" and .value.size > 0) ] | length' ${local_path})

    passmark_cpu_manufacturer=$(jq -r .SystemInformation.Manufacturer ${local_path})
    passmark_cpu_manufacturer=${passmark_cpu_manufacturer/Authentic/}
    passmark_cpu_manufacturer=${passmark_cpu_manufacturer/Genuine/}

    passmark_cpu_sockets=$(jq -r .SystemInformation.NumSockets ${local_path})
    passmark_cpu_cores=$(jq -r .SystemInformation.NumCores ${local_path})
    passmark_cpu_logicals=$(jq -r .SystemInformation.NumLogicals ${local_path})
    passmark_cpu_frequency=$(jq -r .SystemInformation.CPUFrequency ${local_path})

    passmark_score_cpu=$(jq -r .Results.SUMM_CPU ${local_path})
    passmark_score_mem=$(jq -r .Results.SUMM_ME ${local_path})

    echo "  - os: ${passmark_os}"
    echo "  - kernel: ${passmark_kernel}"
    echo "  - processor: ${passmark_processor}"
    echo "  - cpu:"
    echo "    - manufacturer: ${passmark_cpu_manufacturer}"
    echo "    - sockets: ${passmark_cpu_sockets}"
    echo "    - cores: ${passmark_cpu_cores}"
    echo "    - logicals: ${passmark_cpu_logicals}"
    echo "    - Frequency: ${passmark_cpu_frequency}"
    echo "  - ram:"
    echo "    - slots: ${passmark_ram_slots_occupied}/${passmark_ram_slots_total}"
    echo "    - total: ${passmark_ram_total_gb}gb"
    echo "    - modules:"

    dimm_list_as_base64=$(jq -r '.SystemInformation.MemModuleInfo | to_entries[] | select(.key != "iNumMemSticks" and .value.size > 0) | @base64' ${local_path})
    for dimm_as_base64 in ${dimm_list_as_base64[@]}; do
      dimm_manufacturer=$(_decode_property ${dimm_as_base64} .value.manufacturer | tr -s ' ')
      dimm_model=$(_decode_property ${dimm_as_base64} .value.modulePartNo | tr -s ' ')
      dimm_size=$(_decode_property ${dimm_as_base64} .value.size)
      dimm_speed=$(_decode_property ${dimm_as_base64} .value.clkspeed)
      dimm_type=$(_decode_property ${dimm_as_base64} .value.memType)
      dimm_voltage=$(_decode_property ${dimm_as_base64} .value.moduleVoltage)
      if [ "${dimm_manufacturer}" = "Not Specified" ]; then
        echo "      - ${dimm_size}gb ${dimm_type} @${dimm_speed}mhz"
      else
        echo "      - ${dimm_size}gb ${dimm_type} @${dimm_speed}mhz (${dimm_manufacturer} ${dimm_model})"
      fi
    done
    echo "  - score:"
    echo "    - cpu: ${passmark_score_cpu}"
    echo "    - memory: ${passmark_score_mem}"
  else
    echo "- ${fqdn}: rsync failure"
  fi
done
