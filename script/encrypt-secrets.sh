#!/usr/bin/env bash

repo_path=${HOME}/git/grenade/rubberneck
recipient=872E0C00FDC2E9CE9AD7509285F3DBFFC1A8E01B

declare -a targets=()
targets+=( ${repo_path}/manifest/dimitar-talev/quordlepleen/var/lib/quilibrium/.node/config.yml )
targets+=( ${repo_path}/manifest/dimitar-talev/frootmig/etc/monero/monerod.conf )

for target in ${targets[@]}; do
    if [ -s ${target} ]; then
        if [ -s ${target}.gpg ]; then
            echo "encrypted secret exists, skipping: ${target}"
        elif gpg \
            --batch \
            --trust-model always\
            --encrypt \
            --recipient ${recipient} \
            --output ${target}.gpg \
            ${target}; then
            checksum=$(sha256sum ${target} | cut -d ' ' -f 1)
            echo "encrypted secret: ${target}, with checksum ${checksum} as ${target}.gpg"
        fi
    else
        echo "missing secret: ${target}"
    fi
done
