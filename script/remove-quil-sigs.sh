#!/usr/bin/env bash

for fqdn in {{allitnils,colin,gramathea,hawalius,krikkit,quordlepleen,slartibartfast}.thgttg.com,midgard.v8r.io}; do
  echo "${fqdn}"
  ssh ${fqdn} '
    sudo test -f /var/lib/quilibrium/.local/bin/quilibrium.dgst.sig.2 && sudo rm \
      /var/lib/quilibrium/.local/bin/quilibrium.dgst.sig.2;
    sudo test -f /var/lib/quilibrium/.local/bin/quilibrium.dgst.sig.9 && sudo rm \
      /var/lib/quilibrium/.local/bin/quilibrium.dgst.sig.9;
    sudo test -f /var/lib/quilibrium/.local/bin/quilibrium.dgst.sig.12 || sudo -u quilibrium curl \
      --output /var/lib/quilibrium/.local/bin/quilibrium.dgst.sig.12 \
      --url https://releases.quilibrium.com/node-1.4.20.1-linux-amd64.dgst.sig.12;
  '
done
