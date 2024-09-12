#!/usr/bin/env bash

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

for fqdn in ${fqdn_list[@]}; do
  hostname=${fqdn%%.*}
  observed_hostname=$(ssh ${hostname} "
    [ -x /usr/sbin/hponcfg ] || sudo dnf install -y https://downloads.hpe.com/pub/softlib2/software1/pubsw-linux/p215998034/v109045/hponcfg-4.6.0-0.x86_64.rpm &> /dev/null;
    echo '<RIBCL VERSION=\"2.0\"><LOGIN USER_LOGIN=\"Administrator\" PASSWORD=\"\"><SERVER_INFO MODE=\"read\"><GET_SERVER_NAME /></SERVER_INFO></LOGIN></RIBCL>' | sudo hponcfg --input | grep SERVER_NAME | cut -d '\"' -f 2
  ")
  if [ "${hostname}" = "${observed_hostname}" ]; then
    echo "- ${fqdn}: ✅"
  else
    ssh ${hostname} "
      echo '<RIBCL VERSION=\"2.0\"><LOGIN USER_LOGIN=\"Administrator\" PASSWORD=\"\"><SERVER_INFO MODE=\"write\"><SERVER_NAME value=\"${hostname}\"/></SERVER_INFO></LOGIN></RIBCL>' | sudo hponcfg --input &> /dev/null
    "
    echo "- ${fqdn}: 🔨 (${observed_hostname} -> ${hostname})"
  fi
done
