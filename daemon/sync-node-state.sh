#!/usr/bin/env bash

# usage: curl -sL https://raw.githubusercontent.com/grenade/rubberneck/main/daemon/sync-node-state.sh | bash

tmp=$(mktemp -d)

_decode_property() {
  echo ${1} | base64 --decode | jq -r ${2}
}

apt_os=( debian ubuntu )
dnf_os=( centos fedora )

rubberneck_app=$(basename "${0}")
rubberneck_github_org=grenade
rubberneck_github_repo=rubberneck
rubberneck_github_token=$(yq -r .github.token ${HOME}/.rubberneck.yml)
if curl \
  --silent \
  --location \
  --output ${tmp}/${rubberneck_github_org}-${rubberneck_github_repo}-commits.json \
  --header "Accept: application/vnd.github+json" \
  --header "Authorization: Bearer ${rubberneck_github_token}" \
  https://api.github.com/repos/${rubberneck_github_org}/${rubberneck_github_repo}/commits; then
  rubberneck_github_latest_sha=$(jq -r .[0].sha ${tmp}/${rubberneck_github_org}-${rubberneck_github_repo}-commits.json)
  rubberneck_github_latest_date=$(jq -r .[0].commit.committer.date ${tmp}/${rubberneck_github_org}-${rubberneck_github_repo}-commits.json)
else
  echo "[init] error: failed to obtain commit list"
  exit 1
fi

ops_username=grenade
if [ "$(hostname -s)" = "kavula" ]; then
  ops_private_key=${HOME}/.ssh/id_${ops_username}
else
  ops_private_key=${HOME}/.ssh/id_ed25519
fi

curl \
  --silent \
  --location \
  --output ${tmp}/${rubberneck_github_org}-${rubberneck_github_repo}-contents-manifest.json \
  --header "Accept: application/vnd.github+json" \
  --header "Authorization: Bearer ${rubberneck_github_token}" \
  https://api.github.com/repos/${rubberneck_github_org}/${rubberneck_github_repo}/contents/manifest

echo "[init] repo: ${rubberneck_github_org}/${rubberneck_github_repo}"
echo "[init] commit: ${rubberneck_github_latest_sha} ${rubberneck_github_latest_date}"

if [ -z "${intent_list}" ]; then
  intents=( $(jq -r '.[] | select(.type == "dir") | .name' ${tmp}/${rubberneck_github_org}-${rubberneck_github_repo}-contents-manifest.json) )
else
  intents=()
  intents+=( "${intent_list[@]}" )
fi

for intent in ${intents[@]}; do
  echo "[sync] intent: ${intent}"
  curl \
    --silent \
    --location \
    --output ${tmp}/${rubberneck_github_org}-${rubberneck_github_repo}-contents-manifest-${intent}.json \
    --header "Accept: application/vnd.github+json" \
    --header "Authorization: Bearer ${rubberneck_github_token}" \
    https://api.github.com/repos/${rubberneck_github_org}/${rubberneck_github_repo}/contents/manifest/${intent}
  host_list=$(jq -r '.[] | select(.type == "dir") | .name' ${tmp}/${rubberneck_github_org}-${rubberneck_github_repo}-contents-manifest-${intent}.json)
  for hostname in ${host_list[@]}; do
    manifest_path=${tmp}/${intent}-${hostname}-manifest.yml
    if curl \
      --silent \
      --location \
      --output ${manifest_path} \
      https://raw.githubusercontent.com/${rubberneck_github_org}/${rubberneck_github_repo}/${rubberneck_github_latest_sha}/manifest/${intent}/${hostname}/manifest.yml; then
      domain=$(yq -r .domain ${manifest_path})
      fqdn=${hostname}.${domain}
      echo "[${intent}/${fqdn}] manifest fetch suceeded"
      action=$(yq -r .action ${manifest_path})
      os=$(yq -r .os.name ${manifest_path})

      if ! ssh -o ConnectTimeout=1 -o StrictHostKeyChecking=accept-new -i ${ops_private_key} ${ops_username}@${fqdn} exit; then
        ssh_exit_code=$?
        echo "[${ops_username}@${fqdn}] initial connection failed with exit code: ${ssh_exit_code}"
        continue
      else
        ssh_exit_code=$?
        echo "[${ops_username}@${fqdn}] initial connection succeeded with exit code: ${ssh_exit_code}"
      fi

      user_list_as_base64=$(yq -r  '(.user//empty)|.[]|@base64' ${manifest_path})
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
            if rsync -e "ssh -o ConnectTimeout=1 -i ${ops_private_key}" -og --chown=${username}:${username} --rsync-path='sudo rsync' -a ${tmp}/${fqdn}/${username}/authorized_keys ${ops_username}@${fqdn}:${remote_path}; then
              echo "[${fqdn}:${remote_path}authorized_keys] sync suceeded"
            else
              echo "[${fqdn}:${remote_path}authorized_keys] sync failed"
            fi
          fi
        else
          echo "[${fqdn}:${remote_path}authorized_keys] sync skipped"
        fi
      done

      if [[ ${dnf_os[@]} =~ ${os} ]]; then
        package_manager=dnf
        package_verifier='dnf list installed'
        repo_list_path=/etc/yum.repos.d
        repo_list_ext=repo
      elif [[ ${apt_os[@]} =~ ${os} ]]; then
        package_manager=apt-get
        package_verifier='dpkg-query -W'
        repo_key_path=/etc/apt/trusted.gpg.d
        repo_list_path=/etc/apt/sources.list.d
        repo_list_ext=list
      else
        echo "[${fqdn}] unsupported os for package installation. no package manager configured."
        continue
      fi

      repository_list_as_base64=$(yq -r  '.repository//empty' ${manifest_path} | jq -r '.[] | @base64')
      repository_index=0
      for repository_as_base64 in ${repository_list_as_base64[@]}; do
        repository_name=$(_decode_property ${repository_as_base64} .name)
        repository_list=$(_decode_property ${repository_as_base64} .list)
        # dnf key urls should be in the .repo file. ie: `cat /etc/yum.repos.d/*.repo | grep gpgkey`
        if [[ ${dnf_os[@]} =~ ${os} ]]; then
          repository_key_url=$(_decode_property ${repository_as_base64} .key.url)
          repository_key_sha_expected=$(_decode_property ${repository_as_base64} .key.sha)
          repository_key_sha_observed=$(ssh -o ConnectTimeout=1 -i ${ops_private_key} ${ops_username}@${fqdn} "sha256sum ${repo_key_path}/${repository_name}.asc 2> /dev/null | cut -d ' ' -f 1")
          if [ "${repository_key_sha_expected}" = "${repository_key_sha_observed}" ]; then
            echo "[${fqdn}:repository ${repository_index}] repository key validation succeeded. target: ${repo_key_path}/${repository_name}.asc, source: ${repository_key_url}, sha256 expected: ${repository_key_sha_expected}, observed: ${repository_key_sha_observed}"
          elif ssh -o ConnectTimeout=1 -i ${ops_private_key} ${ops_username}@${fqdn} sudo curl -sLo ${repo_key_path}/${repository_name}.asc ${repository_key_url}; then
            echo "[${fqdn}:repository ${repository_index}] repository key download succeeded (${repo_key_path}/${repository_name}.asc, ${repository_key_url})"
          else
            echo "[${fqdn}:repository ${repository_index}] repository key download failed (${repo_key_path}/${repository_name}.asc, ${repository_key_url})"
          fi
        fi
        if ssh -o ConnectTimeout=1 -i ${ops_private_key} ${ops_username}@${fqdn} "echo '${repository_list}' | sudo dd of=${repo_list_path}/${repository_name}.${repo_list_ext}"; then
          echo "[${fqdn}:repository ${repository_index}] repository list creation succeeded (${repo_list_path}/${repository_name}.${repo_list_ext})"
        else
          echo "[${fqdn}:repository ${repository_index}] repository list creation failed (${repo_list_path}/${repository_name}.${repo_list_ext})"
        fi
      done

      package_list=$(yq -r '(.package//empty)|.[]' ${manifest_path})
      package_index=0
      for package in ${package_list[@]}; do
        if ssh -o ConnectTimeout=1 -i ${ops_private_key} ${ops_username}@${fqdn} ${package_verifier} ${package} &> /dev/null; then
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


      command_list_as_base64=$(yq -r '(.command//empty)|.[]|@base64' ${manifest_path})
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

      file_list_as_base64=$(yq -r  '.file//empty' ${manifest_path} | jq -r '.[] | @base64')
      file_index=0
      for file_as_base64 in ${file_list_as_base64[@]}; do
        file_source=$(_decode_property ${file_as_base64} .source)
        file_target=$(_decode_property ${file_as_base64} .target)
        file_sha256_expected=$(_decode_property ${file_as_base64} .sha256)

        if [ ${#file_sha256_expected} -eq 64 ]; then
          # checksum provided.
          # manifest contains a sha256 checksum for file. require a matching sha256 checksum observation.
          file_sha256_observed=$(ssh -o ConnectTimeout=1 -i ${ops_private_key} ${ops_username}@${fqdn} "sudo sha256sum ${file_target} 2> /dev/null | cut -d ' ' -f 1")
        elif [[ ${file_source} == "https://raw.githubusercontent.com/"* ]]; then
          # eg: https://raw.githubusercontent.com/Manta-Network/rubberneck/main/config/calamari.seabird.systems/c2/etc/systemd/system/calamari.service
          # no checksum provided. checksum is discoverable from github repository.
          # file_source is a raw github file. fetch git sha of file from github. require a matching git sha observation.
          file_source_owner=$(echo ${file_source} | cut -d '/' -f 4)
          file_source_repo=$(echo ${file_source} | cut -d '/' -f 5)
          file_source_rev=$(echo ${file_source} | cut -d '/' -f 6)
          file_source_path=$(echo ${file_source} | cut -d '/' -f 7-)
          file_shagit_expected=$(curl \
            --silent \
            --location \
            --header 'X-GitHub-Api-Version: 2022-11-28' \
            --header 'Accept: application/vnd.github.object' \
            --header "Authorization: Bearer ${rubberneck_github_token}" \
            --url "https://api.github.com/repos/${file_source_owner}/${file_source_repo}/contents/${file_source_path}?ref=${file_source_rev}" \
            | jq -r '.sha')
          file_shagit_observed=$(ssh -o ConnectTimeout=1 -i ${ops_private_key} ${ops_username}@${fqdn} "sudo git hash-object ${file_target} 2> /dev/null")
        fi

        if [ ${#file_sha256_expected} -eq 64 ] && [ ${#file_sha256_observed} -eq 64 ] && [ "${file_sha256_expected}" = "${file_sha256_observed}" ]; then
          # observed sha256 checksum is valid and matches expected sha256 checksum
          echo "[${fqdn}:file ${file_index}] sha256 validation succeeded. target: ${file_target}, source: ${file_source}, sha256 expected: ${file_sha256_expected}, observed: ${file_sha256_observed}"
        elif [ ${#file_shagit_expected} -eq 40 ] && [ ${#file_shagit_observed} -eq 40 ] && [ "${file_shagit_expected}" = "${file_shagit_observed}" ]; then
          # observed git sha is valid and matches expected git sha
          echo "[${fqdn}:file ${file_index}] git sha validation succeeded. target: ${file_target}, source: ${file_source}, git sha expected: ${file_shagit_expected}, observed: ${file_shagit_observed}"
        else
          if [ ${#file_sha256_expected} -eq 64 ]; then
            echo "[${fqdn}:file ${file_index}] sha256  validation failed. target: ${file_target}, source: ${file_source}, sha256 expected: ${file_sha256_expected}, observed: ${file_sha256_observed}"
          elif [ ${#file_shagit_expected} -eq 40 ]; then
            echo "[${fqdn}:file ${file_index}] git sha validation failed. target: ${file_target}, source: ${file_source}, git sha expected: ${file_shagit_expected}, observed: ${file_shagit_observed}"
          else
            echo "[${fqdn}:file ${file_index}] validation failed. target: ${file_target}, source: ${file_source}"
          fi
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
        unset file_source
        unset file_target
        unset file_sha256_expected
        unset file_shagit_expected
        file_index=$((file_index+1))
      done
    else
      echo "[${intent}/${hostname}] manifest fetch failed"
    fi
  done
done
