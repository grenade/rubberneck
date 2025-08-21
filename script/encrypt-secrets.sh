#!/usr/bin/env bash

repo_path=${HOME}/git/grenade/rubberneck

declare -a targets=()
#targets+=( ${repo_path}/manifest/dimitar-talev/quordlepleen/var/lib/quilibrium/.node/config.yml )
#targets+=( ${repo_path}/manifest/dimitar-talev/frootmig/etc/monero/monerod.conf )
#targets+=( ${repo_path}/manifest/dimitar-talev/mitko/etc/xmrig-proxy/config.json )
#targets+=( ${repo_path}/static/etc/xmrig/config.json )
#targets+=( ${repo_path}/manifest/resonance/trillian/etc/gitlab-runner/config-qbtc-dev-ubuntu-rust.toml )
#targets+=( ${repo_path}/manifest/resonance/trillian/etc/gitlab-runner/config-resonance-fedora-ci.toml )
#targets+=( ${repo_path}/manifest/resonance/trillian/etc/gitlab-runner/config-resonance-fedora-infra.toml )
#targets+=( ${repo_path}/manifest/resonance/trillian/etc/gitlab-runner/config-resonance-ubuntu-ci.toml )
#targets+=( ${repo_path}/manifest/resonance/trillian/etc/gitlab-runner/config-resonance-ubuntu-infra.toml )
#targets+=( ${repo_path}/manifest/resonance/trillian/etc/gitlab-runner/config-resonance-ubuntu-rust.toml )
targets+=( ${repo_path}/manifest/resonance/zaphod/etc/graylog/graylog.env )
targets+=( ${repo_path}/manifest/resonance/zaphod/etc/opensearch/opensearch.env )
targets+=( ${repo_path}/manifest/resonance/zaphod/etc/oauth2-proxy/oauth2-proxy.env )

for target in ${targets[@]}; do
    if [ -s ${target} ]; then
        case "${target}" in
            ${repo_path}/manifest/resonance/*)
                # resonance
                recipient=5423ED2D79DA063B851A589CE0EBF17F94536628
                ;;
            *)
                # kavula
                recipient=872E0C00FDC2E9CE9AD7509285F3DBFFC1A8E01B
                ;;
        esac
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
