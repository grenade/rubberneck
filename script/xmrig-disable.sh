#!/usr/bin/env bash

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

for fqdn in ${fqdn_list[@]}; do
  hostname=${fqdn%%.*}
  domain=${fqdn#*.}
  ssh ${hostname} '
    [ -f /etc/systemd/system/xmrig.service ] && sudo systemctl stop xmrig.service;
    [ -f /etc/systemd/system/xmrig.service ] && sudo systemctl disable xmrig.service;
    for artifact in /etc/sysctl.d/90-xmrig.conf /usr/local/bin/xmrig /etc/systemd/system/xmrig.service /tmp/xmrig-6.22.0-linux-static-x64.tar.gz; do
      [ -f ${artifact} ] && sudo rm ${artifact};
    done
  '
  exit_code=${?}
  [ ${exit_code} = 1 ] && echo "🔵 ${fqdn}"
  [ ${exit_code} = 0 ] && echo "🟢 ${fqdn}"
done
