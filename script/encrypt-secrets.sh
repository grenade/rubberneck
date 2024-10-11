#!/usr/bin/env bash

repo_path=${HOME}/git/grenade/rubberneck
recipient=872E0C00FDC2E9CE9AD7509285F3DBFFC1A8E01B

declare -a targets=()
targets+=( ${repo_path}/manifest/dimitar-talev/quordlepleen/var/lib/quilibrium/.node/config.yml )
targets+=( ${repo_path}/manifest/dimitar-talev/frootmig/etc/monero/monerod.conf )
targets+=( ${repo_path}/manifest/dimitar-talev/mitko/etc/xmrig-proxy/config.json )
targets+=( ${repo_path}/static/etc/xmrig/config.json )

for target in ${targets[@]}; do
    if [ -s ${target} ]; then
        observed_sha256=$(sha256sum ${target} | cut -d ' ' -f 1 | tee ${target}.sha256)
        encrypted_sha256=$(cat ${target}.gpg.sha256 2> /dev/null)
        if [ -s ${target}.gpg ] && [ "${observed_sha256}" = "${encrypted_sha256}" ]; then
            echo "encrypted secret exists: ${target}.gpg, with checksum ${encrypted_sha256}"
        elif gpg \
            --batch \
            --yes \
            --trust-model always\
            --encrypt \
            --recipient ${recipient} \
            --output ${target}.gpg \
            ${target}; then
            echo ${observed_sha256} > ${target}.gpg.sha256
            echo "encrypted secret: ${target}, with checksum ${observed_sha256} as ${target}.gpg"
        fi
    else
        echo "missing secret: ${target}"
    fi
done
