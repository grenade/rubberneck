#!/usr/bin/env bash

# usage: curl -sL https://raw.githubusercontent.com/grenade/rubberneck/main/daemon/sync-node-state.sh | bash

tmp=$(mktemp -d)

_decode_property() {
  echo ${1} | base64 --decode | jq -r ${2}
}

rubberneck_app=$(basename "${0}")
rubberneck_github_org=grenade
rubberneck_github_repo=rubberneck
rubberneck_github_token=$(yq -r .github.token ${HOME}/.rubberneck.yml)
#if [ -z "${rubberneck_github_token}" ] && which pass 2> /dev/null; then
#  rubberneck_github_token=$(pass github/grenade/hub-workstation)
#fi
curl -sL \
  -o ${tmp}/${rubberneck_github_org}-${rubberneck_github_repo}-commits.json \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${rubberneck_github_token}" \
  https://api.github.com/repos/${rubberneck_github_org}/${rubberneck_github_repo}/commits
rubberneck_github_latest_sha=$(jq -r .[0].sha ${tmp}/${rubberneck_github_org}-${rubberneck_github_repo}-commits.json)
rubberneck_github_latest_date=$(jq -r .[0].commit.committer.date ${tmp}/${rubberneck_github_org}-${rubberneck_github_repo}-commits.json)

#curl \
#  -sLo ${tmp}/org-members.json \
#  -H "Accept: application/vnd.github+json" \
#  -H "Authorization: Bearer ${rubberneck_github_token}" \
#  https://api.github.com/orgs/${rubberneck_github_org}/members

ops_username=grenade
ops_private_key=${HOME}/.ssh/id_ed25519

curl -sL \
  -o ${tmp}/${rubberneck_github_org}-${rubberneck_github_repo}-contents-manifest.json \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${rubberneck_github_token}" \
  https://api.github.com/repos/${rubberneck_github_org}/${rubberneck_github_repo}/contents/manifest

echo "[init] repo: ${rubberneck_github_org}/${rubberneck_github_repo}"
echo "[init] commit: ${rubberneck_github_latest_sha} ${rubberneck_github_latest_date}"

if [ -z "${chain_list}" ]; then
  domain_list=( $(jq -r '.[] | select(.type == "dir") | .name' ${tmp}/${rubberneck_github_org}-${rubberneck_github_repo}-contents-manifest.json) )
else
  curl -sL \
    -o ${tmp}/blockchains.json \
    https://5eklk8knsd.execute-api.eu-central-1.amazonaws.com/prod/blockchains
  domain_list=()
  for chain in ${chain_list[@]}; do
    if [[ ${chain} == *"/"* ]]; then
      chain_domain_list=$(jq --arg name ${chain##*/} --arg relay ${chain%%/*} -r '.blockchains[] | select(.name == $name and .relay == $relay) | .domains[]' ${tmp}/blockchains.json)
    else
      chain_domain_list=$(jq --arg name ${chain} -r '.blockchains[] | select(.name == $name) | .domains[]' ${tmp}/blockchains.json)
    fi
    domain_list+=( "${chain_domain_list[@]}" )
  done
fi

for domain in ${domain_list[@]}; do
  echo "[sync] domain: ${domain}"
  curl -sL \
    -o ${tmp}/${rubberneck_github_org}-${rubberneck_github_repo}-contents-manifest-${domain}.json \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${rubberneck_github_token}" \
    https://api.github.com/repos/${rubberneck_github_org}/${rubberneck_github_repo}/contents/manifest/${domain}
  host_list=$(jq -r '.[] | select(.type == "dir") | .name' ${tmp}/${rubberneck_github_org}-${rubberneck_github_repo}-contents-manifest-${domain}.json)
  for hostname in ${host_list[@]}; do
    fqdn=${hostname}.${domain}
    if curl -sL \
      -o ${tmp}/${fqdn}-manifest.yml \
      https://raw.githubusercontent.com/${rubberneck_github_org}/${rubberneck_github_repo}/${rubberneck_github_latest_sha}/manifest/${domain}/${hostname}/manifest.yml; then
      echo "[${fqdn}] manifest fetch suceeded"
      action=$(yq -r .action ${tmp}/${fqdn}-manifest.yml)
      os=$(yq -r .os.name ${tmp}/${fqdn}-manifest.yml)
      if [ "${os}" = "fedora" ]; then
        package_manager=dnf
      else
        package_manager=apt
      fi

      user_list_as_base64=$(yq -r  '(.user//empty)|.[]|@base64' ${tmp}/${fqdn}-manifest.yml)
      for user_as_base64 in ${user_list_as_base64[@]}; do
        username=$(_decode_property ${user_as_base64} .username)
        mkdir -p ${tmp}/${fqdn}/${username}

        authorized_key_list_as_base64=$(_decode_property ${user_as_base64} '(.authorized.keys//empty)|.[]|@base64')
        for authorized_key_as_base64 in ${authorized_key_list_as_base64[@]}; do
          authorized_key=$(echo ${authorized_key_as_base64} | base64 --decode)
          echo ${authorized_key} >> ${tmp}/${fqdn}/${username}/authorized_keys_raw
        done
        authorized_user_list_as_base64=$(_decode_property ${user_as_base64} '(.authorized.users//empty)|.[]|@base64')
        for authorized_user_as_base64 in ${authorized_user_list_as_base64[@]}; do
          authorized_user=$(echo ${authorized_user_as_base64} | base64 --decode)
          #is_org_member=$(jq --arg login ${authorized_user} '. | any((.login | ascii_downcase) == ($login | ascii_downcase))' ${tmp}/org-members.json)
          is_org_member=true
          echo "[${fqdn}:user:${username}] user: ${authorized_user}, in org: ${is_org_member}"
          if [ "${authorized_user}" = "manta-ops" ] || [ "${is_org_member}" = "true" ]; then
            if [ -s ${tmp}/authorized-keys-${authorized_user} ] || curl -sLo ${tmp}/authorized-keys-${authorized_user} https://github.com/${authorized_user}.keys 2> /dev/null; then
              while read authorized_key; do
                if [[ ${authorized_key} == ssh-ed25519* ]]; then
                  echo ${authorized_key} >> ${tmp}/${fqdn}/${username}/authorized_keys_raw
                fi
              done < ${tmp}/authorized-keys-${authorized_user}
            fi
          fi
        done
        if [ "${action}" = "sync" ]; then
          if [ "${username}" = "root" ]; then
            remote_path=/root/.ssh/
          else
            remote_path=/home/${username}/.ssh/
          fi
          sort -u ${tmp}/${fqdn}/${username}/authorized_keys_raw > ${tmp}/${fqdn}/${username}/authorized_keys
          if [ -s ${tmp}/${fqdn}/${username}/authorized_keys ]; then
            chmod o-w ${tmp}/${fqdn}/${username}/authorized_keys
            if rsync -e "ssh -o ConnectTimeout=1 -o StrictHostKeyChecking=accept-new -i ${ops_private_key}" -og --chown=${username}:${username} --rsync-path='sudo rsync' -a ${tmp}/${fqdn}/${username}/authorized_keys ${ops_username}@${fqdn}:${remote_path}; then
              echo "[${fqdn}:${remote_path}authorized_keys] sync suceeded"
            else
              echo "[${fqdn}:${remote_path}authorized_keys] sync failed"
            fi
          fi
        else
          echo "[${fqdn}:${remote_path}authorized_keys] sync skipped"
        fi
      done

      package_list=$(yq -r '(.package//empty)|.[]' ${tmp}/${fqdn}-manifest.yml)
      package_index=0
      for package in ${package_list[@]}; do
        if ssh -o ConnectTimeout=1 -i ${ops_private_key} ${ops_username}@${fqdn} dpkg-query -W ${package} &> /dev/null; then
          echo "[${fqdn}:package ${package_index}] install detected, package: ${package}"
        elif [ "${action}" = "sync" ]; then
          if ssh -o ConnectTimeout=1 -i ${ops_private_key} ${ops_username}@${fqdn} sudo ${package_manager} install -y ${package}; then
            echo "[${fqdn}:package ${package_index}] install succeeded, package: ${package}"
          else
            echo "[${fqdn}:package ${package_index}] install failed, package: ${package}"
          fi
        else
          echo "[${fqdn}:package ${package_index}] install skipped, package: ${package}"
        fi
        package_index=$((package_index+1))
      done


      command_list_as_base64=$(yq -r '(.command//empty)|.[]|@base64' ${tmp}/${fqdn}-manifest.yml)
      command_index=0
      for command_as_base64 in ${command_list_as_base64[@]}; do
        command=$(echo ${command_as_base64} | base64 --decode)
        if [ "${action}" = "sync" ]; then
          ssh -o ConnectTimeout=1 -i ${ops_private_key} ${ops_username}@${fqdn} "${command}" &> /dev/null
          command_exit_code=$?
          echo "[${fqdn}:command ${command_index}] exit code: ${command_exit_code}, command: ${command}"
        else
          echo "[${fqdn}:command ${command_index}] skipped"
        fi
        command_index=$((command_index+1))
      done

      file_list_as_base64=$(yq -r  '.file//empty' ${tmp}/${fqdn}-manifest.yml | jq -r '.[] | @base64')
      file_index=0
      for file_as_base64 in ${file_list_as_base64[@]}; do
        file_source=$(_decode_property ${file_as_base64} .source)
        file_target=$(_decode_property ${file_as_base64} .target)
        file_sha256_expected=$(_decode_property ${file_as_base64} .sha256)
        file_sha256_observed=$(ssh -o ConnectTimeout=1 -i ${ops_private_key} ${ops_username}@${fqdn} "sha256sum ${file_target} 2> /dev/null | cut -d ' ' -f 1")

        #if [ ${#file_sha256_expected} -eq 64 ]; then
        #  # checksum provided.
        #  # manifest contains a sha256 checksum for file. require a matching sha256 checksum observation.
        #  file_sha256_observed=$(ssh -o ConnectTimeout=1 -i ${ops_private_key} ${ops_username}@${fqdn} "sha256sum ${file_target} 2> /dev/null | cut -d ' ' -f 1")
        #elif [[ ${file_source} == "https://raw.githubusercontent.com/"* ]]; then
        #  # eg: https://raw.githubusercontent.com/grenade/rubberneck/main/manifest/calamari.seabird.systems/c2/etc/systemd/system/calamari.service
        #  # no checksum provided. checksum is discoverable from github repository.
        #  # file_source is a raw github file. fetch git sha of file from github. require a matching git sha observation.
        #  file_source_repo=$(echo ${file_source} | cut -d '/' -f 4,5)
        #  file_source_rev=$(echo ${file_source} | cut -d '/' -f 6)
        #  file_source_path=$(echo ${file_source} | cut -d '/' -f 7-)
        #else
        #  # no checksum provided. checksum is not discoverable.
        #fi

        if [ "${file_sha256_expected}" = "${file_sha256_observed}" ]; then
          echo "[${fqdn}:file ${file_index}] validation succeeded. target: ${file_target}, source: ${file_source}, sha256 expected: ${file_sha256_expected}, observed: ${file_sha256_observed}"
        else
          echo "[${fqdn}:file ${file_index}] validation failed. target: ${file_target}, source: ${file_source}, sha256 expected: ${file_sha256_expected}, observed: ${file_sha256_observed}"
          file_pre_command_list_as_base64=$(_decode_property ${file_as_base64} '(.command.pre//empty)|.[]|@base64')
          command_index=0
          for file_pre_command_as_base64 in ${file_pre_command_list_as_base64[@]}; do
            command=$(echo ${file_pre_command_as_base64} | base64 --decode)
            echo "[${fqdn}:file ${file_index}, pre command ${command_index}] ${command}"
            if [ "${action}" = "sync" ]; then
              ssh -o ConnectTimeout=1 -i ${ops_private_key} ${ops_username}@${fqdn} "${command}" &> /dev/null
              command_exit_code=$?
              echo "[${fqdn}:file ${file_index}, pre command ${command_index}] exit code: ${command_exit_code}, command: ${command}"
            else
              echo "[${fqdn}:file ${file_index}, pre command ${command_index}] skipped"
            fi
            command_index=$((command_index+1))
          done
          if [ "${action}" = "sync" ]; then
            if ssh -o ConnectTimeout=1 -i ${ops_private_key} ${ops_username}@${fqdn} sudo curl -sLo ${file_target} ${file_source}; then
              echo "[${fqdn}:file ${file_index}] download succeeded (${file_target}, ${file_source})"
              file_post_command_list_as_base64=$(_decode_property ${file_as_base64} '(.command.post//empty)|.[]|@base64')
              command_index=0
              for file_post_command_as_base64 in ${file_post_command_list_as_base64[@]}; do
                command=$(echo ${file_post_command_as_base64} | base64 --decode)
                ssh -o ConnectTimeout=1 -i ${ops_private_key} ${ops_username}@${fqdn} "${command}" &> /dev/null
                command_exit_code=$?
                echo "[${fqdn}:file ${file_index}, post command ${command_index}] exit code: ${command_exit_code}, command: ${command}"
                command_index=$((command_index+1))
              done
            else
              echo "[${fqdn}:file ${file_index}] download failed (${file_target}, ${file_source})"
            fi
          fi
        fi
        file_index=$((file_index+1))
      done
    else
      echo "[${fqdn}] manifest fetch failed"
    fi
  done
done
