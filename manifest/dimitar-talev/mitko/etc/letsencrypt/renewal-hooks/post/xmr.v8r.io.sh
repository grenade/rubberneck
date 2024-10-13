#!/bin/bash

for pem_source in /etc/letsencrypt/live/xmr.v8r.io/{fullchain,privkey}.pem; do
    pem_target=/var/lib/p2pool/$(basename ${pem_source})
    cp ${pem_source} ${pem_target}
    chown p2pool:p2pool ${pem_target}
done
