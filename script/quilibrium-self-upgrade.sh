#!/usr/bin/env bash

if ((EUID != 0)); then
  echo >&2 "script ($(basename ${0})) must be run as root."
  exit 1
fi

quilibrium_home=/var/lib/quilibrium
quilibrium_user=quilibrium
remote_artifacts=($(curl -sL https://releases.quilibrium.com/release | grep linux-amd64))
latest_version=$(echo ${remote_artifacts[0]} | cut -d \- -f 2)
for sig in ${quilibrium_home}/.local/bin/quilibrium.dgst.sig.{1..20}; do
    if [ -e ${sig} ]; then
        rm ${sig};
    fi
done;
for remote_artifact in ${remote_artifacts[@]}; do
    remote_artifact_url=https://releases.quilibrium.com/${remote_artifact}
    local_artifact_path=${quilibrium_home}/.local/bin/${remote_artifact}
    local_artifact_link=${quilibrium_home}/.local/bin/${remote_artifact/node-${latest_version}-linux-amd64/quilibrium}
    if [ ! -s ${local_artifact_path} ]; then
    	if sudo -u ${quilibrium_user} /usr/bin/curl \
            --fail \
            --location \
            --silent \
            --output ${local_artifact_path} \
            --url ${remote_artifact_url} \
            && [ -s ${local_artifact_path} ]; then
            echo "auto-updater: downloaded ${local_artifact_path} from ${remote_artifact_url}"
        else
            echo "auto-updater: failed to download ${local_artifact_path} from ${remote_artifact_url}"
        fi
    fi
    if [ "${remote_artifact}" = "node-${latest_version}-linux-amd64" ] && [ ! -x ${local_artifact_path} ]; then
        chmod +x ${local_artifact_path}
        chcon -Rv -u system_u -t bin_t ${local_artifact_path}
    fi
    sudo -u ${quilibrium_user} /usr/bin/ln -sfr ${local_artifact_path} ${local_artifact_link}
done
