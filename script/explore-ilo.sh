#!/usr/bin/env bash

max_session_age_in_seconds=1800
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

subl /tmp/ilo

# to reset the administrator password, execute on host:

# sudo dnf install -y https://downloads.hpe.com/pub/softlib2/software1/pubsw-linux/p215998034/v109045/hponcfg-4.6.0-0.x86_64.rpm
# echo "
# <RIBCL VERSION=\"2.0\">
#   <LOGIN USER_LOGIN=\"Administrator\" PASSWORD=\"password\">
#     <USER_INFO MODE=\"write\">
#       <MOD_USER USER_LOGIN=\"Administrator\">
#         <PASSWORD value=\"password\"/>
#       </MOD_USER>
#     </USER_INFO>
#   </LOGIN>
# </RIBCL>
# " | sudo hponcfg -i

color_red=$(tput setaf 1)
color_reset=$(tput sgr0)

declare -a fqdn_list=()
fqdn_list+=( expralite.thgttg.com )
fqdn_list+=( kavula.thgttg.com )
fqdn_list+=( mp.thgttg.com )
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
fqdn_list+=( midgard.v8r.io )
fqdn_list+=( mitko.thgttg.com )
fqdn_list+=( novgorodian.thgttg.com )
fqdn_list+=( quordlepleen.thgttg.com )
fqdn_list+=( slartibartfast.thgttg.com )

echo "probing ${#fqdn_list[@]} interfaces..."
for fqdn in ${fqdn_list[@]}; do
  domain=${fqdn#*.}
  hostname=${fqdn%%.*}
  if [ ! -d /tmp/ilo/${fqdn} ]; then
    mkdir -p /tmp/ilo/${fqdn}
  fi
  response_headers_create_session_path=/tmp/ilo/${fqdn}/$(date --iso=s)-response-headers-create-session.log
  response_body_create_session_path=/tmp/ilo/${fqdn}/$(date --iso=s)-response-body-create-session.log
  session_token_path=/tmp/ilo/${fqdn}/session-token
  echo "- ilo.${fqdn}"
  if [ -s ${session_token_path} ]; then
    session_age_in_seconds=$(($(date +%s) - $(date +%s -r ${session_token_path})))
  else
    session_age_in_seconds=$((max_session_age_in_seconds + 1))
  fi
  if [ "${session_age_in_seconds}" -lt "${max_session_age_in_seconds}" ] || curl \
    --silent \
    --connect-timeout 1 \
    --header 'Content-Type: application/json' \
    --header 'OData-Version: 4.0' \
    --request POST \
    --data "{\"UserName\":\"Administrator\",\"Password\":\"$(${script_dir}/get-ilo-password.sh ${fqdn})\"}" \
    --dump-header ${response_headers_create_session_path} \
    --output ${response_body_create_session_path} \
    --url https://ilo.${fqdn}/redfish/v1/SessionService/Sessions/; then
    if grep X-Auth-Token ${response_headers_create_session_path} &> /dev/null; then
      token=$(grep X-Auth-Token ${response_headers_create_session_path} | cut -d ' ' -f 2)
      echo ${token} > ${session_token_path}
      for method in {systems,chassis,managers,sessions}; do
        #echo "    - ${method}"
        if curl \
          --silent \
          --header 'Content-Type: application/json' \
          --header 'OData-Version: 4.0' \
          --header "X-Auth-Token: ${token}" \
          --request GET \
          --output /tmp/ilo/${fqdn}/response-body-${method} \
          --url https://ilo.${fqdn}/redfish/v1/${method}/; then
          jq . /tmp/ilo/${fqdn}/response-body-${method} > /tmp/ilo/${fqdn}/response-body-${method}.json
          members=$(jq -r '.Members[]."@odata.id"' /tmp/ilo/${fqdn}/response-body-${method}.json)
          for member in ${members[@]}; do
            member_number=$(echo ${member} | cut -d '/' -f 5)
            #echo "      ${member_number}:"
            if curl \
              --silent \
              --header 'Content-Type: application/json' \
              --header 'OData-Version: 4.0' \
              --header "X-Auth-Token: ${token}" \
              --request GET \
              --output /tmp/ilo/${fqdn}/response-body-${method}-${member_number} \
              --url https://ilo.${fqdn}${member}; then
              jq . /tmp/ilo/${fqdn}/response-body-${method}-${member_number} > /tmp/ilo/${fqdn}/response-body-${method}-${member_number}.json
            fi
            rm /tmp/ilo/${fqdn}/response-body-${method}-${member_number}
          done
        fi
        rm /tmp/ilo/${fqdn}/response-body-${method}
        case ${method} in
          systems)
            if [ -f /tmp/ilo/${fqdn}/response-body-${method}-1.json ]; then
              ethernet_interfaces_uri=https://ilo.$fqdn$(jq -r '.EthernetInterfaces."@odata.id"' /tmp/ilo/${fqdn}/response-body-${method}-1.json)
              if curl \
                --silent \
                --header 'Content-Type: application/json' \
                --header 'OData-Version: 4.0' \
                --header "X-Auth-Token: ${token}" \
                --request GET \
                --output /tmp/ilo/${fqdn}/response-body-${method}-1-ethernet-interfaces \
                --url ${ethernet_interfaces_uri}; then
                jq . /tmp/ilo/${fqdn}/response-body-${method}-1-ethernet-interfaces > /tmp/ilo/${fqdn}/response-body-${method}-1-ethernet-interfaces.json
                members=$(jq -r '.Members[]."@odata.id"' /tmp/ilo/${fqdn}/response-body-${method}-1-ethernet-interfaces.json)
                for member in ${members[@]}; do
                  member_number=$(echo ${member} | cut -d '/' -f 7)
                  if curl \
                    --silent \
                    --header 'Content-Type: application/json' \
                    --header 'OData-Version: 4.0' \
                    --header "X-Auth-Token: ${token}" \
                    --request GET \
                    --output /tmp/ilo/${fqdn}/response-body-${method}-1-ethernet-interface-${member_number} \
                    --url https://ilo.${fqdn}${member}; then
                    jq . /tmp/ilo/${fqdn}/response-body-${method}-1-ethernet-interface-${member_number} > /tmp/ilo/${fqdn}/response-body-${method}-1-ethernet-interface-${member_number}.json
                  fi
                  rm /tmp/ilo/${fqdn}/response-body-${method}-1-ethernet-interface-${member_number}
                done
              fi
              rm /tmp/ilo/${fqdn}/response-body-${method}-1-ethernet-interfaces
            fi
            ;;
          *)
            ;;
        esac
      done

      if curl \
        --silent \
        --header 'Content-Type: application/json' \
        --header 'OData-Version: 4.0' \
        --header "X-Auth-Token: ${token}" \
        --request GET \
        --output /tmp/ilo/${fqdn}/metrics-power \
        --url https://ilo.${fqdn}/redfish/v1/Chassis/1/Power/; then
        jq . /tmp/ilo/${fqdn}/metrics-power > /tmp/ilo/${fqdn}/metrics-power.json
      fi
      rm /tmp/ilo/${fqdn}/metrics-power

      if curl \
        --silent \
        --header 'Content-Type: application/json' \
        --header 'OData-Version: 4.0' \
        --header "X-Auth-Token: ${token}" \
        --request GET \
        --output /tmp/ilo/${fqdn}/metrics-thermal \
        --url https://ilo.${fqdn}/redfish/v1/Chassis/1/Thermal/; then
        jq . /tmp/ilo/${fqdn}/metrics-thermal > /tmp/ilo/${fqdn}/metrics-thermal.json
      fi
      rm /tmp/ilo/${fqdn}/metrics-thermal

      if curl \
        --silent \
        --header 'Content-Type: application/json' \
        --header 'OData-Version: 4.0' \
        --header "X-Auth-Token: ${token}" \
        --request GET \
        --output /tmp/ilo/${fqdn}/metrics-compute \
        --url https://ilo.${fqdn}/redfish/v1/TelemetryService/MetricReports/; then
        jq . /tmp/ilo/${fqdn}/metrics-compute > /tmp/ilo/${fqdn}/metrics-compute.json
      fi
      rm /tmp/ilo/${fqdn}/metrics-compute
      if [[ "$(jq -r '.error."@Message.ExtendedInfo"[0].MessageId' /tmp/ilo/${fqdn}/metrics-compute.json)" == *"ResourceMissingAtURI" ]]; then
        rm /tmp/ilo/${fqdn}/metrics-compute.json
      fi
    elif grep '502 Bad Gateway' ${response_headers_create_session_path} &> /dev/null; then
      echo "  ${color_red}- 502 bad gateway${color_reset}"
    elif [ "$(jq -r '.error."@Message.ExtendedInfo"[0].MessageId' ${response_body_create_session_path} 2> /dev/null)" != "null" ] && [ "$(jq -r '.error."@Message.ExtendedInfo"[0].MessageId' ${response_body_create_session_path} 2> /dev/null)" != "" ]; then
      echo "  ${color_red}- $(jq -r '.error."@Message.ExtendedInfo"[0].MessageId' ${response_body_create_session_path} 2> /dev/null | tr '[:upper:]' '[:lower:]')${color_reset}"
    elif [ -f ${response_headers_create_session_path} ] && [ ! -s ${response_headers_create_session_path} ]; then
      echo "  ${color_red}- no headers received${color_reset}"
    fi
  else
    echo "  ${color_red}- connection timed out${color_reset}"
  fi
  if [ -f /tmp/ilo/${fqdn}/response-body-systems-1.json ]; then

    processor_count=$(jq -r .ProcessorSummary.Count /tmp/ilo/${fqdn}/response-body-systems-1.json)
    processor_model=$(jq -r .ProcessorSummary.Model /tmp/ilo/${fqdn}/response-body-systems-1.json | xargs)
    processor_health=$(jq -r .ProcessorSummary.Status.HealthRollup /tmp/ilo/${fqdn}/response-body-systems-1.json)

    memory_total=$(jq -r .MemorySummary.TotalSystemMemoryGiB /tmp/ilo/${fqdn}/response-body-systems-1.json)
    memory_health=$(jq -r .MemorySummary.Status.HealthRollup /tmp/ilo/${fqdn}/response-body-systems-1.json)

    power_state=$(jq -r .PowerState /tmp/ilo/${fqdn}/response-body-systems-1.json)
    indicator_led=$(jq -r .IndicatorLED /tmp/ilo/${fqdn}/response-body-systems-1.json)
    bios_version=$(jq -r .BiosVersion /tmp/ilo/${fqdn}/response-body-systems-1.json)
    ilo_hostname=$(jq -r .HostName /tmp/ilo/${fqdn}/response-body-systems-1.json)
    machine_model=$(jq -r .Model /tmp/ilo/${fqdn}/response-body-systems-1.json)
    machine_manufacturer=$(jq -r .Manufacturer /tmp/ilo/${fqdn}/response-body-systems-1.json)

    case ${power_state,,} in
      off)
        case ${hostname} in
          # this works but doesn't belong in an observer script.
          # left commented until i implement a power state fixer script.
          #bob|frootmig|effrafax)
          #  if curl \
          #    --silent \
          #    --header 'Content-Type: application/json' \
          #    --header 'OData-Version: 4.0' \
          #    --header "X-Auth-Token: ${token}" \
          #    --request POST \
          #    --data '{"ResetType":"ForceOn"}' \
          #    --output /tmp/ilo/${fqdn}/metrics-compute \
          #    --url https://ilo.${fqdn}/redfish/v1/Systems/1/Actions/ComputerSystem.Reset; then
          #    echo "  - power: 🔴 -> 🟢"
          #  else
          #    echo "  - power: 🔴 -> 🔴"
          #  fi
          #  ;;
          *)
            echo "  - power: 🔴"
            ;;
        esac
        ;;
      on)
        echo "  - power: 🟢"
        ;;
      *)
        echo "  - power: ${power_state,,}"
        ;;
    esac
    case ${indicator_led,,} in
      off)
        echo "  - indicator: ⚫"
        ;;
      on)
        echo "  - indicator: 🔵"
        ;;
      *)
        echo "  - indicator: ${indicator_led,,}"
        ;;
    esac
    echo "  - machine:"
    echo "    - model: ${machine_model,,}"
    echo "    - manufacturer: ${machine_manufacturer,,}"

    echo "  - ilo:"
    echo "    - hostname: ${ilo_hostname,,}"

    echo "  - bios:"
    echo "    - version: ${bios_version,,}"

    echo "  - processor:"
    echo "    - model: ${processor_model,,}"
    echo "    - count: ${processor_count}"
    echo "    - health: ${processor_health,,}"

    echo "  - memory:"
    echo "    - total: ${memory_total}"
    echo "    - health: ${processor_health,,}"

    echo "  - ethernet:"
    for path in $(ls /tmp/ilo/${fqdn}/response-body-systems-1-ethernet-interface-*.json); do
      filename=$(basename ${path})
      filename_without_extension=${filename%.*}

      interface_number=$(echo ${filename_without_extension} | cut -d '-' -f 7)
      interface_mac=$(jq -r .MACAddress ${path})
      interface_health=$(jq -r .Status.Health ${path})
      interface_state=$(jq -r .Status.State ${path})
      echo "    - interface: ${interface_number}"
      echo "      - mac: ${interface_mac,,}"
      if [ "${interface_health}" != "null" ]; then
        echo "      - health: ${interface_health,,}"
      fi
      if [ "${interface_state}" = "null" ]; then
        echo "      - state: disconnected"
      else
        echo "      - state: ${interface_state,,}"
      fi
    done
  fi
  #for path in ${response_headers_create_session_path} ${response_body_create_session_path}; do
  #  if [ -f ${path} ]; then
  #    rm ${path}
  #  fi
  #done
done
