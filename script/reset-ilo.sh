#!/usr/bin/env bash

# see:
# - ilo 3: https://support.hpe.com/connect/s/softwaredetails?language=en_US&collectionId=MTX-588efdaa80f74606&tab=releaseNotes
# - ilo 4: https://support.hpe.com/connect/s/softwaredetails?language=en_US&collectionId=MTX-d8701885e8a84180&tab=releaseNotes
# - ilo 5: https://support.hpe.com/connect/s/softwaredetails?language=en_US&collectionId=MTX-8aa4f1e30dfc4417&tab=releaseNotes
# todo:
# - [x] delete users
# - [ ] reset administrator certificate/key

install_dependencies="${install_dependencies:=false}"
reset_password="${reset_password:=false}"
update_firmware="${update_firmware:=false}"
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
timezone=Europe/Sofia
timezone_alt='Athens, Bucharest, Cairo, Jerusalem'

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
fqdn_list+=( midgard.v8r.io )
fqdn_list+=( mitko.thgttg.com )
fqdn_list+=( novgorodian.thgttg.com )
fqdn_list+=( quordlepleen.thgttg.com )
fqdn_list+=( slartibartfast.thgttg.com )

color_red=$(tput setaf 1)
color_dim=$(tput dim)
color_reset=$(tput sgr0)

ilo_firmware_version_pattern='FIRMWARE_VERSION = "([^"]+)"'
ilo_firmware_date_pattern='FIRMWARE_DATE = "([^"]+)"'
ilo_firmware_processor_pattern='MANAGEMENT_PROCESSOR = "([^"]+)"'
ilo_firmware_license_pattern='LICENSE_TYPE = "([^"]+)"'

for fqdn in ${fqdn_list[@]}; do
  hostname=${fqdn%%.*}
  domain=${fqdn#*.}
  password=$(${script_dir}/get-ilo-password.sh ${fqdn})

  if [ "${install_dependencies}" = "true" ] || [ "${install_dependencies}" = "1" ]; then
    ssh ${hostname} '[ -x /usr/sbin/hponcfg ] || sudo dnf install -y https://downloads.hpe.com/pub/softlib2/software1/pubsw-linux/p215998034/v109045/hponcfg-4.6.0-0.x86_64.rpm &> /dev/null'
  fi

  get_fw_version=$(ssh ${hostname} "echo '<RIBCL VERSION=\"2.0\"><LOGIN USER_LOGIN=\"Administrator\" PASSWORD=\"${password}\"><RIB_INFO MODE=\"read\"><GET_FW_VERSION /></RIB_INFO></LOGIN></RIBCL>' | sudo hponcfg --input")

  if [[ ${get_fw_version} =~ ${ilo_firmware_version_pattern} ]]; then
    ilo_firmware_version=${BASH_REMATCH[1]}
  else
    unset ilo_firmware_version
  fi
  if [[ ${get_fw_version} =~ ${ilo_firmware_date_pattern} ]]; then
    ilo_firmware_date=${BASH_REMATCH[1]}
  else
    unset ilo_firmware_date
  fi
  if [[ ${get_fw_version} =~ ${ilo_firmware_processor_pattern} ]]; then
    ilo_firmware_processor=${BASH_REMATCH[1]}
    ilo_version="${ilo_firmware_processor: -1}"
  else
    unset ilo_firmware_processor
    unset ilo_version
  fi
  if [[ ${get_fw_version} =~ ${ilo_firmware_license_pattern} ]]; then
    ilo_firmware_license=${BASH_REMATCH[1]}
  else
    unset ilo_firmware_license
  fi
  echo "- ${fqdn} ${color_dim}(ilo ${ilo_version})${color_reset}"
  echo "  - ilo firmware:"
  case ${ilo_version} in
    3)
      case ${ilo_firmware_version} in
        1.15)
          if [ "${update_firmware}" = "true" ] || [ "${update_firmware}" = "1" ]; then
            # firmware 1.1x must be upgraded to 1.28 before being upgraded to newer versions in order to add support for newer image signature algorithms
            # see: https://community.hpe.com/t5/server-management-remote-server/hp-advisory-says-to-update-to-ilo-3-1-57-or-later-yet-1-55-is/m-p/6102521/highlight/true#M7345
            ssh ${hostname} '
              curl -fL -o /tmp/CP016462.scexe https://downloads.hpe.com/pub/softlib2/software1/sc-linux-fw-ilo/p1255562964/v73832/CP016462.scexe;
              chmod +x /tmp/CP016462.scexe;
              sudo /tmp/CP016462.scexe -s;
            '
            echo "    🔨 version: ${ilo_firmware_version} -> 1.28"
          fi
          ;;
        *)
          if [ "${ilo_firmware_version}" = "1.94" ]; then
            echo "    ✅ version: ${ilo_firmware_version}"
          elif [ "${update_firmware}" = "true" ] || [ "${update_firmware}" = "1" ]; then
            ssh ${hostname} '
              curl -fL -o /tmp/CP046328.scexe https://downloads.hpe.com/pub/softlib2/software1/sc-linux-fw-ilo/p1573561412/v189986/CP046328.scexe;
              chmod +x /tmp/CP046328.scexe;
              sudo /tmp/CP046328.scexe -s;
            '
            echo "    🔨 version: ${ilo_firmware_version} -> 1.94"
          else
            echo "    🔨 version: ${ilo_firmware_version}"
          fi
          ;;
      esac
      ;;
    4)
      if [ "${ilo_firmware_version}" = "2.82" ]; then
        echo "    ✅ version: ${ilo_firmware_version}"
      elif [ "${update_firmware}" = "true" ] || [ "${update_firmware}" = "1" ]; then
        ssh ${hostname} '
          curl -fL -o /tmp/CP053894.scexe https://downloads.hpe.com/pub/softlib2/software1/sc-linux-fw-ilo/p192122427/v218149/CP053894.scexe;
          chmod +x /tmp/CP053894.scexe;
          sudo /tmp/CP053894.scexe -s;
        '
        echo "    🔨 version: ${ilo_firmware_version} -> 2.82"
      else
        echo "    🔨 version: ${ilo_firmware_version}"
      fi
      ;;
    5)
      if [ "${ilo_firmware_version}" = "3.07" ]; then
        echo "    ✅ version: ${ilo_firmware_version}"
      elif [ "${update_firmware}" = "true" ] || [ "${update_firmware}" = "1" ]; then
        ssh ${hostname} '
          sudo dnf install -y https://downloads.hpe.com/pub/softlib2/software1/sc-linux-fw-ilo/p1342933511/v251410/RPMS/x86_64/firmware-ilo5-3.07-1.1.x86_64.rpm;
          sudo /usr/lib/x86_64-linux-gnu/scexe-compat/CP062165.scexe -s;
        '
        echo "    🔨 version: ${ilo_firmware_version} -> 3.07"
      else
        echo "    🔨 version: ${ilo_firmware_version}"
      fi
      ;;
  esac

  echo "    - date: $(date --date="${ilo_firmware_date}" --iso)"
  echo "    - processor: ${ilo_firmware_processor}"
  echo "    - license: ${ilo_firmware_license/${ilo_firmware_license% *} /}"

  if [ "${reset_password}" = "true" ] || [ "${reset_password}" = "1" ]; then
    ssh ${hostname} "echo '<RIBCL VERSION=\"2.0\"><LOGIN USER_LOGIN=\"Administrator\" PASSWORD=\"${password}\"><USER_INFO MODE=\"write\"><MOD_USER USER_LOGIN=\"Administrator\"><PASSWORD value=\"${password}\"/></MOD_USER></USER_INFO></LOGIN></RIBCL>' | sudo hponcfg --input &> /dev/null"
  fi

  observed_user_list=$(ssh ${hostname} "echo '<RIBCL VERSION=\"2.0\"><LOGIN USER_LOGIN=\"Administrator\" PASSWORD=\"${password}\"><USER_INFO MODE=\"read\"><GET_ALL_USERS /></USER_INFO></LOGIN></RIBCL>' | sudo hponcfg --input | sed --quiet '/USER_LOGIN/p' | grep -oE '\"([^\" ]+)\"' | tr -d '\"'")
  for observed_user in ${observed_user_list[@]}; do
    if [ "${observed_user}" != "Administrator" ]; then
      ssh ${hostname} "echo '<RIBCL VERSION=\"2.0\"><LOGIN USER_LOGIN=\"Administrator\" PASSWORD=\"${password}\"><USER_INFO MODE=\"write\"><DELETE_USER USER_LOGIN=\"${observed_user}\"/></USER_INFO></LOGIN></RIBCL>' | sudo hponcfg --input &> /dev/null"
      echo "  🔨 user removed: ${observed_user}"
    fi
  done

  observed_ilo_timezone=$(ssh ${hostname} "echo '<RIBCL VERSION=\"2.0\"><LOGIN USER_LOGIN=\"Administrator\" PASSWORD=\"${password}\"><RIB_INFO MODE=\"read\"><GET_NETWORK_SETTINGS /></RIB_INFO></LOGIN></RIBCL>' | sudo hponcfg --input | grep TIMEZONE | cut -d '\"' -f 2")
  if [ "${timezone}" = "${observed_ilo_timezone}" ] || [ "${timezone_alt}" = "${observed_ilo_timezone}" ]; then
    echo "  ✅ ilo timezone"
  else
    ssh ${hostname} "echo '<RIBCL VERSION=\"2.0\"><LOGIN USER_LOGIN=\"Administrator\" PASSWORD=\"${password}\"><RIB_INFO MODE=\"write\"><MOD_NETWORK_SETTINGS><TIMEZONE value=\"${timezone}\"/></MOD_NETWORK_SETTINGS></RIB_INFO></LOGIN></RIBCL>' | sudo hponcfg --input &> /dev/null"
    echo "  🔨 ilo timezone: ${observed_ilo_timezone} -> ${timezone}"
  fi

  observed_ilo_hostname=$(ssh ${hostname} "echo '<RIBCL VERSION=\"2.0\"><LOGIN USER_LOGIN=\"Administrator\" PASSWORD=\"${password}\"><RIB_INFO MODE=\"read\"><GET_NETWORK_SETTINGS /></RIB_INFO></LOGIN></RIBCL>' | sudo hponcfg --input | grep DNS_NAME | cut -d '\"' -f 2")
  if [ "ilo-${hostname}" = "${observed_ilo_hostname}" ]; then
    echo "  ✅ ilo hostname"
  else
    ssh ${hostname} "echo '<RIBCL VERSION=\"2.0\"><LOGIN USER_LOGIN=\"Administrator\" PASSWORD=\"${password}\"><RIB_INFO MODE=\"write\"><MOD_NETWORK_SETTINGS><DNS_NAME value=\"ilo-${hostname}\"/></MOD_NETWORK_SETTINGS></RIB_INFO></LOGIN></RIBCL>' | sudo hponcfg --input &> /dev/null"
    echo "  🔨 ilo hostname: ${observed_ilo_hostname} -> ilo-${hostname}"
  fi

  observed_ilo_domain=$(ssh ${hostname} "echo '<RIBCL VERSION=\"2.0\"><LOGIN USER_LOGIN=\"Administrator\" PASSWORD=\"${password}\"><RIB_INFO MODE=\"read\"><GET_NETWORK_SETTINGS /></RIB_INFO></LOGIN></RIBCL>' | sudo hponcfg --input | grep '<DOMAIN_NAME' | cut -d '\"' -f 2")
  if [ "${domain}" = "${observed_ilo_domain}" ]; then
    echo "  ✅ ilo domain"
  else
    ssh ${hostname} "echo '<RIBCL VERSION=\"2.0\"><LOGIN USER_LOGIN=\"Administrator\" PASSWORD=\"${password}\"><RIB_INFO MODE=\"write\"><MOD_NETWORK_SETTINGS><DHCP_DOMAIN_NAME value=\"N\"/><DOMAIN_NAME value=\"${domain}\"/></MOD_NETWORK_SETTINGS></RIB_INFO></LOGIN></RIBCL>' | sudo hponcfg --input &> /dev/null"
    echo "  🔨 ilo domain: ${observed_ilo_domain} -> ${domain}"
  fi

  observed_hostname=$(ssh ${hostname} "echo '<RIBCL VERSION=\"2.0\"><LOGIN USER_LOGIN=\"Administrator\" PASSWORD=\"${password}\"><SERVER_INFO MODE=\"read\"><GET_SERVER_NAME /></SERVER_INFO></LOGIN></RIBCL>' | sudo hponcfg --input | grep SERVER_NAME | cut -d '\"' -f 2")
  if [ "${hostname}" = "${observed_hostname}" ]; then
    echo "  ✅ hostname"
  else
    ssh ${hostname} "echo '<RIBCL VERSION=\"2.0\"><LOGIN USER_LOGIN=\"Administrator\" PASSWORD=\"${password}\"><SERVER_INFO MODE=\"write\"><SERVER_NAME value=\"${hostname}\"/></SERVER_INFO></LOGIN></RIBCL>' | sudo hponcfg --input &> /dev/null"
    echo "  🔨 hostname: ${observed_hostname} -> ${hostname}"
  fi

  if [ "${ilo_firmware_version}" != "1.15" ]; then
    observed_fqdn=$(ssh ${hostname} "echo '<RIBCL VERSION=\"2.0\"><LOGIN USER_LOGIN=\"Administrator\" PASSWORD=\"${password}\"><SERVER_INFO MODE=\"read\"><GET_SERVER_FQDN /></SERVER_INFO></LOGIN></RIBCL>' | sudo hponcfg --input | grep SERVER_FQDN | cut -d '\"' -f 2")
    if [ "${fqdn}" = "${observed_fqdn}" ]; then
      echo "  ✅ fqdn"
    else
      ssh ${hostname} "echo '<RIBCL VERSION=\"2.0\"><LOGIN USER_LOGIN=\"Administrator\" PASSWORD=\"${password}\"><SERVER_INFO MODE=\"write\"><SERVER_FQDN value=\"${fqdn}\"/></SERVER_INFO></LOGIN></RIBCL>' | sudo hponcfg --input &> /dev/null"
      echo "  🔨 fqdn: ${observed_fqdn} -> ${fqdn}"
    fi
  fi
done
