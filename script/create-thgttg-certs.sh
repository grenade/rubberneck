#!/usr/bin/env bash

for fqdn in {allitnils,colin,gramathea,hawalius,krikkit,novgorodian,slartibartfast}.thgttg.com; do
  sudo certbot certonly \
    -m ops@thgttg.com \
    --agree-tos \
    --no-eff-email \
    --noninteractive \
    --cert-name ${fqdn} \
    --expand \
    --allow-subset-of-names \
    --key-type ecdsa \
    --dns-cloudflare \
    --dns-cloudflare-credentials /root/.cloudflare/thgttg.com \
    --dns-cloudflare-propagation-seconds 60 \
    -d ${fqdn} \
    -d cockpit.${fqdn}
done
