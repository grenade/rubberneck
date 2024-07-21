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
domain=
for fqdn in ${fqdn_list[@]}; do
  domain=${fqdn#*.}
  sudo certbot certonly \
    --agree-tos \
    --no-eff-email \
    --noninteractive \
    --cert-name ${fqdn} \
    --expand \
    --allow-subset-of-names \
    --key-type ecdsa \
    --dns-cloudflare \
    --dns-cloudflare-credentials /root/.cloudflare/${domain} \
    --dns-cloudflare-propagation-seconds 60 \
    -m ops@${domain} \
    -d ${fqdn} \
    -d cockpit.${fqdn} \
    -d ilo.${fqdn}
done
