#!/usr/bin/env bash

if ((EUID != 0)); then
  echo >&2 "script ($(basename ${0})) must be run as root."
  exit 1
fi

#sudo setenforce 0
#sudo setenforce 1
#sudo systemctl stop quilibrium.service
for sig in ${quilibrium_home}/.local/bin/quilibrium.dgst.sig.{1..20}; do
    if sudo -u ${quilibrium_user} test -e ${sig}; then
        sudo -u ${quilibrium_user} rm ${sig};
    fi
done;
quilibrium_home=/var/lib/quilibrium
quilibrium_user=quilibrium
remote_artifacts=($(curl -sL https://releases.quilibrium.com/release | grep linux-amd64))
latest_version=$(echo ${remote_artifacts[0]} | cut -d \- -f 2)
for remote_artifact in ${remote_artifacts[@]}; do
    remote_artifact_url=https://releases.quilibrium.com/${remote_artifact}
    local_artifact_path=${quilibrium_home}/.local/bin/${remote_artifact}
    local_artifact_link=${quilibrium_home}/.local/bin/${remote_artifact/node-${latest_version}-linux-amd64/quilibrium}
    if sudo -u ${quilibrium_user} test -s ${local_artifact_path}; then
        echo "auto-updater: observed ${local_artifact_path}"
    else
        if sudo -u ${quilibrium_user} /usr/bin/curl \
            --fail \
            --silent \
            --location \
            --output ${local_artifact_path} \
            --url ${remote_artifact_url} \
            && sudo -u ${quilibrium_user} test -s ${local_artifact_path}; then
            echo "auto-updater: downloaded ${local_artifact_path} from ${remote_artifact_url}"
        else
            echo "auto-updater: failed to download ${local_artifact_path} from ${remote_artifact_url}"
        fi
    fi
    if sudo -u ${quilibrium_user} test -s ${local_artifact_path}; then
        sudo -u ${quilibrium_user} /usr/bin/ln -sfr ${local_artifact_path} ${local_artifact_link}
        if [ "${remote_artifact}" = "node-${latest_version}-linux-amd64" ]; then
            sudo -u ${quilibrium_user} chmod +x ${local_artifact_path}
            sudo semanage fcontext -a -t bin_t ${local_artifact_path} > /dev/null
            sudo chcon -v -u system_u -t bin_t ${local_artifact_path} > /dev/null
            sudo semanage fcontext -a -t bin_t ${local_artifact_link} > /dev/null
            sudo chcon -v -u system_u -t bin_t ${local_artifact_link} > /dev/null
        else
            sudo semanage fcontext -a -t var_lib_t ${local_artifact_path} > /dev/null
            sudo chcon -v -u system_u -t var_lib_t ${local_artifact_path} > /dev/null
            sudo semanage fcontext -a -t var_lib_t ${local_artifact_link} > /dev/null
            sudo chcon -v -u system_u -t var_lib_t ${local_artifact_link} > /dev/null
        fi
    elif sudo -u ${quilibrium_user} test -e ${local_artifact_path}; then
        echo "auto-updater: observed corrupted file ${local_artifact_path}"
        rm -f ${local_artifact_path}
        rm -f ${local_artifact_link}
    else
        echo "auto-updater: observed missing file ${local_artifact_path}"
        rm -f ${local_artifact_link}
    fi
done
#sudo systemctl start quilibrium.service
