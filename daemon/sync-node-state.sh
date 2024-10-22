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
rubberneck_github_token=$(yq -r .github.token ${HOME}/.rubberneck.yml 2> /dev/null)
# todo: inspect token, exit if invalid
if curl \
  --silent \
  --location \
  --output ${tmp}/${rubberneck_github_org}-${rubberneck_github_repo}-commits.json \
  --header "Accept: application/vnd.github+json" \
  --header "Authorization: Bearer ${rubberneck_github_token}" \
  https://api.github.com/repos/${rubberneck_github_org}/${rubberneck_github_repo}/commits; then
  rubberneck_github_latest_sha=$(jq -r .[0].sha ${tmp}/${rubberneck_github_org}-${rubberneck_github_repo}-commits.json)
  rubberneck_github_latest_date=$(jq -r .[0].commit.committer.date ${tmp}/${rubberneck_github_org}-${rubberneck_github_repo}-commits.json)
  if [ "${#rubberneck_github_latest_sha}" = "40" ]; then
    echo "[init] repo: ${rubberneck_github_org}/${rubberneck_github_repo}"
    echo "[init] commit: ${rubberneck_github_latest_sha} ${rubberneck_github_latest_date}"
  else
    echo "[init] error: failed to obtain latest git sha"
    jq -c . ${tmp}/${rubberneck_github_org}-${rubberneck_github_repo}-commits.json
    exit 1
  fi
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
    mkdir -p ${tmp}/${fqdn}
    manifest_path=${tmp}/${intent}-${hostname}-manifest.yml
    if curl \
      --silent \
      --location \
      --output ${manifest_path} \
      https://raw.githubusercontent.com/${rubberneck_github_org}/${rubberneck_github_repo}/${rubberneck_github_latest_sha}/manifest/${intent}/${hostname}/manifest.yml; then
      domain=$(yq -r .domain ${manifest_path})
      ssh_port=$(yq -r '.ssh.port // 22' ${manifest_path})
      ssh_timeout=$(yq -r '.ssh.timeout // 3' ${manifest_path})
      fqdn=${hostname}.${domain}
      echo "[${fqdn}] manifest (${intent}/${hostname}) fetch suceeded"
      action=$(yq -r .action ${manifest_path})
      os=$(yq -r .os.name ${manifest_path})

      ssh -o ConnectTimeout=${ssh_timeout} -o StrictHostKeyChecking=accept-new -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} exit
      ssh_exit_code=$?
      if test ${ssh_exit_code} -ne 0; then
        echo "[${fqdn}] initial connection for user ${ops_username}, using ${ops_private_key}, on port ${ssh_port} failed with exit code: ${ssh_exit_code}"
        continue
      else
        echo "[${fqdn}] initial connection succeeded with exit code: ${ssh_exit_code}"
      fi

      user_list_as_base64=$(yq -r  '(.user//empty)|.[]|@base64' ${manifest_path})
      for user_as_base64 in ${user_list_as_base64[@]}; do
        username=$(_decode_property ${user_as_base64} .username)
        system=$(_decode_property ${user_as_base64} .system//false)
        home=$(_decode_property ${user_as_base64} .home)
        if [ "${home}" = "null" ]; then
          if [ "${username}" = "root" ]; then
            home=/root
          elif [ "${system}" = "true" ]; then
            home=/var/lib/${username}
          else
            home=/home/${username}
          fi
        fi
        mkdir -p ${tmp}/${fqdn}/${username}

        observation_error_log=${tmp}/${fqdn}/user-observation-error-${username}.log
        user_observed=$(ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} "id ${username} 2> /dev/null" 2> ${observation_error_log})
        user_observed_exit_code=$?
        if grep -q "timed out" ${observation_error_log} &> /dev/null; then
          echo "[${fqdn}:user:${username}] user observation failed due to connection timeout. observation error: $(cat ${observation_error_log} | tr '\n' ' ')"
          rm -f ${observation_error_log}
          continue
        elif [ $(grep . ${observation_error_log} | wc -l | cut -d ' ' -f 1) -gt 0 ]; then
          echo "[${fqdn}:user:${username}] user observation failed. observation error: $(cat ${observation_error_log} | tr '\n' ' ')"
          rm -f ${observation_error_log}
          continue
        elif [ "${user_observed_exit_code}" = "0" ]; then
          echo "[${fqdn}:user:${username}] user observed"
        elif [ "${action}" = "sync" ] && [ "${username}" != "root" ]; then
          if [ "${system}" = "true" ]; then
            user_create_command="sudo useradd --create-home --home-dir ${home} --user-group ${username}"
          else
            user_create_command="sudo useradd --system --create-home --home-dir ${home} --user-group ${username}"
          fi
          if ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} ${user_create_command}; then
            echo "[${fqdn}:user:${username}] user creation succeeded"
          else
            echo "[${fqdn}:user:${username}] user creation failed"
          fi
        else
          echo "[${fqdn}:user:${username}] user creation skipped"
        fi
        rm -f ${observation_error_log}

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
            if [ -s ${tmp}/authorized-keys-${authorized_user} ] || curl --fail --silent --location --output ${tmp}/authorized-keys-${authorized_user} --url https://github.com/${authorized_user}.keys 2> /dev/null; then
              while read authorized_key; do
                if [[ ${authorized_key} == ssh-ed25519* ]]; then
                  echo ${authorized_key} >> ${tmp}/${fqdn}/${username}/authorized_keys_raw
                fi
              done < ${tmp}/authorized-keys-${authorized_user}
            fi
          fi
        done
        if [ "${action}" = "sync" ]; then
          sort -u ${tmp}/${fqdn}/${username}/authorized_keys_raw > ${tmp}/${fqdn}/${username}/authorized_keys
          if [ -s ${tmp}/${fqdn}/${username}/authorized_keys ]; then
            if ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} "sudo mkdir -p ${home}/.ssh; sudo chown -R ${username}:${username} ${home}/.ssh"; then
              echo "[${fqdn}:${home}/.ssh] owner (${username}) verified"
            else
              echo "[${fqdn}:${home}/.ssh] owner (${username}) verification failed"
            fi
            chmod o-w ${tmp}/${fqdn}/${username}/authorized_keys
            if rsync -e "ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port}" -og --chown=${username}:${username} --rsync-path='sudo rsync' -a ${tmp}/${fqdn}/${username}/authorized_keys ${ops_username}@${fqdn}:${home}/.ssh/; then
              echo "[${fqdn}:${home}/.ssh/authorized_keys] sync suceeded"
            else
              echo "[${fqdn}:${home}/.ssh/authorized_keys] sync failed"
            fi
          fi
        else
          echo "[${fqdn}:${home}/.ssh/authorized_keys] sync skipped"
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
          repository_key_sha_observed=$(ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} "sha256sum ${repo_key_path}/${repository_name}.asc 2> /dev/null | cut -d ' ' -f 1")
          if [ "${repository_key_sha_expected}" = "${repository_key_sha_observed}" ]; then
            echo "[${fqdn}:repository ${repository_index}] repository key validation succeeded. target: ${repo_key_path}/${repository_name}.asc, source: ${repository_key_url}, sha256 expected: ${repository_key_sha_expected}, observed: ${repository_key_sha_observed}"
          elif ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} sudo curl --fail --silent --location --output ${repo_key_path}/${repository_name}.asc --url ${repository_key_url}; then
            echo "[${fqdn}:repository ${repository_index}] repository key download succeeded (${repo_key_path}/${repository_name}.asc, ${repository_key_url})"
          else
            echo "[${fqdn}:repository ${repository_index}] repository key download failed (${repo_key_path}/${repository_name}.asc, ${repository_key_url})"
          fi
        fi
        if ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} "echo '${repository_list}' | sudo dd of=${repo_list_path}/${repository_name}.${repo_list_ext}"; then
          echo "[${fqdn}:repository ${repository_index}] repository list creation succeeded (${repo_list_path}/${repository_name}.${repo_list_ext})"
        else
          echo "[${fqdn}:repository ${repository_index}] repository list creation failed (${repo_list_path}/${repository_name}.${repo_list_ext})"
        fi
      done

      package_list=$(yq -r '(.package//empty)|.[]' ${manifest_path})
      package_index=0
      observation_error_log=${tmp}/${fqdn}/package-install-observation-error.log
      for package in ${package_list[@]}; do
        package_install_observed=$(ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} "${package_verifier} ${package} 2> /dev/null | grep ${package} | cut -d '.' -f 1" 2> ${observation_error_log})
        if grep -q "timed out" ${observation_error_log} &> /dev/null; then
          echo "[${fqdn}:package ${package_index}] package install observation failed due to connection timeout. package: ${package}, observation error: $(cat ${observation_error_log} | tr '\n' ' ')"
          rm -f ${observation_error_log}
          continue
        elif [ $(grep . ${observation_error_log} | wc -l | cut -d ' ' -f 1) -gt 0 ]; then
          echo "[${fqdn}:package ${package_index}] package install observation failed. package: ${package}, observation error: $(cat ${observation_error_log} | tr '\n' ' ')"
          rm -f ${observation_error_log}
          continue
        elif [ "${package_install_observed}" = "${package}" ]; then
          echo "[${fqdn}:package ${package_index}] package install observed, package: ${package}"
        elif [ "${action}" = "sync" ]; then
          if ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} sudo ${package_manager} install -y ${package}; then
            echo "[${fqdn}:package ${package_index}] package install succeeded, package: ${package}"
          else
            echo "[${fqdn}:package ${package_index}] package install failed, package: ${package}"
          fi
        else
          echo "[${fqdn}:package ${package_index}] package install skipped, package: ${package}"
        fi
        rm -f ${observation_error_log}
        package_index=$((package_index+1))
      done

      if [[ ${dnf_os[@]} =~ ${os} ]]; then
        observation_error_log=${tmp}/${fqdn}/firewall-exception-observation-error.log
        firewall_port_proto_list=$(yq -r '(.firewall.port//empty)|.[]' ${manifest_path})
        firewall_port_proto_index=0
        for firewall_port_proto in ${firewall_port_proto_list[@]}; do
          firewall_exception_observed=$(ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} "sudo firewall-cmd --list-ports --permanent 2> /dev/null | tr ' ' '\n' | grep ${firewall_port_proto}" 2> ${observation_error_log})
          if grep -q "timed out" ${observation_error_log} &> /dev/null; then
            echo "[${fqdn}:firewall_port_proto ${firewall_port_proto_index}] firewall exception observation failed due to connection timeout. port/protocol: ${firewall_port_proto}, observation error: $(cat ${observation_error_log} | tr '\n' ' ')"
            rm -f ${observation_error_log}
            continue
          elif [ $(grep . ${observation_error_log} | wc -l | cut -d ' ' -f 1) -gt 0 ]; then
            echo "[${fqdn}:firewall_port_proto ${firewall_port_proto_index}] firewall exception observation failed. port/protocol: ${firewall_port_proto}, observation error: $(cat ${observation_error_log} | tr '\n' ' ')"
            rm -f ${observation_error_log}
            continue
          elif [ "${firewall_port_proto}" = "${firewall_exception_observed}" ]; then
            echo "[${fqdn}:firewall_port_proto ${firewall_port_proto_index}] allow rule observed: ${firewall_port_proto}"
          elif [ "${action}" = "sync" ]; then
            if ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} "sudo firewall-cmd --zone=FedoraServer --add-port=${firewall_port_proto} --permanent && sudo firewall-cmd --reload"; then
              echo "[${fqdn}:firewall_port_proto ${firewall_port_proto_index}] allow rule added: ${firewall_port_proto}"
            else
              echo "[${fqdn}:firewall_port_proto ${firewall_port_proto_index}] allow rule add failed: ${firewall_port_proto}"
            fi
          else
            echo "[${fqdn}:firewall_port_proto ${firewall_port_proto_index}] allow rule add skipped: ${firewall_port_proto}"
          fi
          rm -f ${observation_error_log}
          firewall_port_proto_index=$((firewall_port_proto_index+1))
        done
      else
        echo "[${fqdn}] unsupported os for firewall configuration."
      fi

      command_list_as_base64=$(yq -r '(.command//empty)|.[]|@base64' ${manifest_path})
      command_index=0
      for command_as_base64 in ${command_list_as_base64[@]}; do
        command_error_log=${tmp}/${fqdn}/command-${command_index}-error.log
        command=$(echo ${command_as_base64} | base64 --decode)
        if [ "${action}" = "sync" ]; then
          ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} "${command}" &> ${command_error_log}
          command_exit_code=$?
          if [ ${command_exit_code} -eq 0 ]; then
            echo "[${fqdn}:command ${command_index}] exit code: ${command_exit_code}, command: ${command}"
          else
            echo "[${fqdn}:command ${command_index}] exit code: ${command_exit_code}, command: ${command}, error: $(cat ${command_error_log} | tr '\n' ' ')"
          fi
          rm -f ${command_error_log}
        else
          echo "[${fqdn}:command ${command_index}] skipped"
        fi
        command_index=$((command_index+1))
      done

      archive_list_as_base64=$(yq -r  '.archive//empty' ${manifest_path} | jq -r '.[] | @base64')
      archive_index=0
      observation_error_log=${tmp}/${fqdn}/archive-checksum-observation-error.log
      for archive_as_base64 in ${archive_list_as_base64[@]}; do
        archive_source=$(_decode_property ${archive_as_base64} .source)
        archive_target=$(_decode_property ${archive_as_base64} .target)
        archive_target_ext=${archive_target##*.}
        archive_sha256_expected=$(_decode_property ${archive_as_base64} .sha256)
        archive_extract_list_as_base64=$(_decode_property ${archive_as_base64} '(.extract//empty)|.[]|@base64')
        archive_extract_index=0
        for archive_extract_as_base64 in ${archive_extract_list_as_base64[@]}; do
          archive_extract_source=$(_decode_property ${archive_extract_as_base64} .source)
          archive_extract_target=$(_decode_property ${archive_extract_as_base64} .target)
          case ${archive_target_ext} in
            bz2)
              if [[ ${archive_extract_source} == */* ]]; then
                strip_components="${archive_extract_source//[^\/]}"
                archive_extract_command="sudo tar --extract --bzip2 --file ${archive_target} --directory $(dirname ${archive_extract_target}) --strip-components ${#strip_components} ${archive_extract_source}"
              else
                archive_extract_command="sudo tar --extract --bzip2 --file ${archive_target} --directory $(dirname ${archive_extract_target}) ${archive_extract_source}"
              fi
              ;;
            gz)
              if [[ ${archive_extract_source} == */* ]]; then
                strip_components="${archive_extract_source//[^\/]}"
                archive_extract_command="sudo tar --extract --gzip --file ${archive_target} --directory $(dirname ${archive_extract_target}) --strip-components ${#strip_components} ${archive_extract_source}"
              else
                archive_extract_command="sudo tar --extract --gzip --file ${archive_target} --directory $(dirname ${archive_extract_target}) ${archive_extract_source}"
              fi
              ;;
            zip)
              if [[ ${archive_extract_source} == */* ]]; then
                archive_extract_command="sudo unzip -j ${archive_target} ${archive_extract_source} -d $(dirname ${archive_extract_target})"
              else
                archive_extract_command="sudo unzip ${archive_target} ${archive_extract_source} -d $(dirname ${archive_extract_target})"
              fi
              ;;
            *)
              archive_extract_command=false
              ;;
          esac
          archive_extract_sha256_expected=$(_decode_property ${archive_extract_as_base64} .sha256)
          archive_extract_sha256_observed=$(ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} "sudo sha256sum ${archive_extract_target} 2> /dev/null | cut -d ' ' -f 1" 2> ${observation_error_log})
          if grep -q "timed out" ${observation_error_log} &> /dev/null; then
            echo "[${fqdn}:archive-extract ${archive_index}/${archive_extract_index}] sha256 observation failed due to connection timeout. target: ${archive_extract_target}, source: ${archive_extract_source}, sha256 expected: ${archive_extract_sha256_expected}, observation error: $(cat ${observation_error_log} | tr '\n' ' ')"
            rm -f ${observation_error_log}
            continue
          elif [ $(grep . ${observation_error_log} | wc -l | cut -d ' ' -f 1) -gt 0 ]; then
            echo "[${fqdn}:archive-extract ${archive_index}/${archive_extract_index}] sha256 observation failed. target: ${archive_extract_target}, source: ${archive_extract_source}, sha256 expected: ${archive_extract_sha256_expected}, observation error: $(cat ${observation_error_log} | tr '\n' ' ')"
            rm -f ${observation_error_log}
            continue
          elif [ ${#archive_extract_sha256_expected} -eq 64 ] && [ ${#archive_extract_sha256_observed} -eq 64 ] && [ "${archive_extract_sha256_expected}" = "${archive_extract_sha256_observed}" ]; then
            echo "[${fqdn}:archive-extract ${archive_index}/${archive_extract_index}] sha256 validation succeeded. target: ${archive_extract_target}, source: ${archive_extract_source}, sha256 expected: ${archive_extract_sha256_expected}, observed: ${archive_extract_sha256_observed}"
          elif [ ${#archive_extract_sha256_expected} -eq 64 ]; then
            echo "[${fqdn}:archive-extract ${archive_index}/${archive_extract_index}] sha256 validation failed. target: ${archive_extract_target}, source: ${archive_extract_source}, sha256 expected: ${archive_extract_sha256_expected}, observed: ${archive_extract_sha256_observed}"
            archive_sha256_observed=$(ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} "sudo sha256sum ${archive_target} 2> /dev/null | cut -d ' ' -f 1" 2> ${observation_error_log})
            if [ "${archive_sha256_expected}" = "${archive_sha256_observed}" ]; then
              echo "[${fqdn}:archive ${archive_index}] sha256 validation succeeded. target: ${archive_target}, source: ${archive_source}, sha256 expected: ${archive_sha256_expected}, observed: ${archive_sha256_observed}"
            elif ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} curl --fail --silent --location --output ${archive_target} --url ${archive_source}; then
              echo "[${fqdn}:archive ${archive_index}] download succeeded (${archive_target}, ${archive_source})"
            else
              echo "[${fqdn}:archive ${archive_index}] download failed (${archive_target}, ${archive_source})"
              rm -f ${observation_error_log}
              continue
            fi
            archive_extract_pre_command_list_as_base64=$(_decode_property ${archive_extract_as_base64} '(.command.pre//empty)|.[]|@base64')
            archive_extract_pre_command_index=0
            for archive_extract_pre_command_as_base64 in ${archive_extract_pre_command_list_as_base64[@]}; do
              command=$(echo ${archive_extract_pre_command_as_base64} | base64 --decode)
              echo "[${fqdn}:archive-extract ${archive_index}/${archive_extract_index}, pre command ${archive_extract_pre_command_index}] ${command}"
              if [ "${action}" = "sync" ]; then
                ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} "${command}" &> /dev/null
                command_exit_code=$?
                echo "[${fqdn}:archive-extract ${archive_index}/${archive_extract_index}, pre command ${archive_extract_pre_command_index}] exit code: ${command_exit_code}, command: ${command}"
              else
                echo "[${fqdn}:archive-extract ${archive_index}/${archive_extract_index}, pre command ${archive_extract_pre_command_index}] skipped"
              fi
              archive_extract_pre_command_index=$((archive_extract_pre_command_index+1))
            done
            if [ "${archive_extract_command}" != "false" ] && ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} "${archive_extract_command} > /dev/null"; then
              echo "[${fqdn}:archive-extract ${archive_index}/${archive_extract_index}] archive extract succeeded. source: ${archive_target}/${archive_extract_source}, target: ${archive_extract_target}"
              # todo: handle chown/chmod
              archive_extract_post_command_list_as_base64=$(_decode_property ${archive_extract_as_base64} '(.command.post//empty)|.[]|@base64')
              archive_extract_post_command_index=0
              for archive_extract_post_command_as_base64 in ${archive_extract_post_command_list_as_base64[@]}; do
                command=$(echo ${archive_extract_post_command_as_base64} | base64 --decode)
                echo "[${fqdn}:archive-extract ${archive_index}/${archive_extract_index}, post command ${archive_extract_post_command_index}] ${command}"
                if [ "${action}" = "sync" ]; then
                  ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} "${command}" &> /dev/null
                  command_exit_code=$?
                  echo "[${fqdn}:archive-extract ${archive_index}/${archive_extract_index}, post command ${archive_extract_post_command_index}] exit code: ${command_exit_code}, command: ${command}"
                else
                  echo "[${fqdn}:archive-extract ${archive_index}/${archive_extract_index}, post command ${archive_extract_post_command_index}] skipped"
                fi
                archive_extract_post_command_index=$((archive_extract_post_command_index+1))
              done
            elif [ "${archive_extract_command}" = "false" ]; then
              echo "[${fqdn}:archive-extract ${archive_index}/${archive_extract_index}] archive extract skipped. no implementation for ${archive_target_ext} file extraction. source: ${archive_target}/${archive_extract_source}, target: ${archive_extract_target}"
            else
              echo "[${fqdn}:archive-extract ${archive_index}/${archive_extract_index}] archive extract failed. source: ${archive_target}/${archive_extract_source}, target: ${archive_extract_target}"
            fi
          fi
          rm -f ${observation_error_log}
          archive_extract_index=$((archive_extract_index+1))
        done
        archive_index=$((archive_index+1))
      done

      file_list_as_base64=$(yq -r  '.file//empty' ${manifest_path} | jq -r '.[] | @base64')
      file_index=0
      observation_error_log=${tmp}/${fqdn}/file-checksum-observation-error.log
      for file_as_base64 in ${file_list_as_base64[@]}; do
        file_source=$(_decode_property ${file_as_base64} .source)
        file_source_ext=${file_source##*.}
        file_target=$(_decode_property ${file_as_base64} .target)
        file_chown=$(_decode_property ${file_as_base64} .chown)
        file_chmod=$(_decode_property ${file_as_base64} .chmod)
        file_sha256_expected=$(_decode_property ${file_as_base64} .sha256)

        if [ ${#file_sha256_expected} -eq 64 ]; then
          # checksum provided.
          # manifest contains a sha256 checksum for file. require a matching sha256 checksum observation.
          file_sha256_observed=$(ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} "sudo sha256sum ${file_target} 2> /dev/null | cut -d ' ' -f 1" 2> ${observation_error_log})
          if grep -q "timed out" ${observation_error_log} &> /dev/null; then
            echo "[${fqdn}:file ${file_index}] sha256 observation failed due to connection timeout. target: ${file_target}, source: ${file_source}, sha256 expected: ${file_sha256_expected}, observation error: $(cat ${observation_error_log} | tr '\n' ' ')"
            rm -f ${observation_error_log}
            continue
          elif [ $(grep . ${observation_error_log} | wc -l | cut -d ' ' -f 1) -gt 0 ]; then
            echo "[${fqdn}:file ${file_index}] sha256 observation failed. target: ${file_target}, source: ${file_source}, sha256 expected: ${file_sha256_expected}, observation error: $(cat ${observation_error_log} | tr '\n' ' ')"
            rm -f ${observation_error_log}
            continue
          fi
          rm -f ${observation_error_log}
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
          file_shagit_observed=$(ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} "sudo git hash-object ${file_target} 2> /dev/null" 2> ${observation_error_log})
          if grep -q "timed out" ${observation_error_log} &> /dev/null; then
            echo "[${fqdn}:file ${file_index}] git sha observation failed. target: ${file_target}, source: ${file_source}, git sha expected: ${file_shagit_expected}, observation error: $(head -n 1 ${observation_error_log})"
            rm -f ${observation_error_log}
            continue
          fi
          rm -f ${observation_error_log}
        fi

        if [ ${#file_sha256_expected} -eq 64 ] && [ ${#file_sha256_observed} -eq 64 ] && [ "${file_sha256_expected}" = "${file_sha256_observed}" ]; then
          # observed sha256 checksum is valid and matches expected sha256 checksum
          echo "[${fqdn}:file ${file_index}] sha256 validation succeeded. target: ${file_target}, source: ${file_source}, sha256 expected: ${file_sha256_expected}, observed: ${file_sha256_observed}"
        elif [ ${#file_shagit_expected} -eq 40 ] && [ ${#file_shagit_observed} -eq 40 ] && [ "${file_shagit_expected}" = "${file_shagit_observed}" ]; then
          # observed git sha is valid and matches expected git sha
          echo "[${fqdn}:file ${file_index}] git sha validation succeeded. target: ${file_target}, source: ${file_source}, git sha expected: ${file_shagit_expected}, observed: ${file_shagit_observed}"
        else
          if [ ${#file_sha256_expected} -eq 64 ]; then
            echo "[${fqdn}:file ${file_index}] sha256 validation failed. target: ${file_target}, source: ${file_source}, sha256 expected: ${file_sha256_expected}, observed: ${file_sha256_observed}"
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
              ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} "${command}" &> /dev/null
              command_exit_code=$?
              echo "[${fqdn}:file ${file_index}, pre command ${command_index}] exit code: ${command_exit_code}, command: ${command}"
            else
              echo "[${fqdn}:file ${file_index}, pre command ${command_index}] skipped"
            fi
            command_index=$((command_index+1))
          done
          if [ "${action}" = "sync" ]; then
            if [ "${file_source_ext}" = "gpg" ] && [ ${#file_sha256_expected} -eq 64 ]; then
              tmp_file_path=/tmp/$(uuidgen)
              if curl --fail --silent --location --url ${file_source} | gpg --quiet --decrypt > ${tmp_file_path}; then
                echo "[${fqdn}:file ${file_index}] secret fetch (${file_source}) and decrypt (${file_target}) suceeded"
                rsync_optional_args=()
                if [ -n ${file_chown} ] && [ ${file_chown} != null ]; then
                  rsync_optional_args+=( "--chown=${file_chown}" )
                fi
                if [ -n ${file_chmod} ] && [ ${file_chmod} != null ]; then
                  rsync_optional_args+=( "--chmod=${file_chmod}" )
                fi
                if rsync $(echo ${rsync_optional_args[@]}) \
                  --archive \
                  --rsync-path='sudo rsync' \
                  --rsh="ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port}" \
                  ${tmp_file_path} \
                  ${ops_username}@${fqdn}:${file_target}; then
                  echo "[${fqdn}:file ${file_index}] secret sync (${file_target}) suceeded"
                  file_post_command_list_as_base64=$(_decode_property ${file_as_base64} '(.command.post//empty)|.[]|@base64')
                  command_index=0
                  for file_post_command_as_base64 in ${file_post_command_list_as_base64[@]}; do
                    command=$(echo ${file_post_command_as_base64} | base64 --decode)
                    ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} "${command}" &> /dev/null
                    command_exit_code=$?
                    echo "[${fqdn}:file ${file_index}, post command ${command_index}] exit code: ${command_exit_code}, command: ${command}"
                    command_index=$((command_index+1))
                  done
                else
                  echo "[${fqdn}:file ${file_index}] secret sync (${file_target}) failed"
                fi
              else
                echo "[${fqdn}:file ${file_index}] secret fetch (${file_source}) and decrypt (${file_target}) failed"
              fi
              wipe -s -f ${tmp_file_path}
            elif ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} sudo curl --fail --silent --location --output ${file_target} --url ${file_source}; then
              echo "[${fqdn}:file ${file_index}] download succeeded (${file_target}, ${file_source})"
              if [ -n ${file_chown} ] && [ ${file_chown} != null ]; then
                if ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} sudo chown ${file_chown} ${file_target}; then
                  echo "[${fqdn}:file ${file_index}] chown succeeded: ${file_chown}, ${file_target}"
                else
                  echo "[${fqdn}:file ${file_index}] chown failed: ${file_chown}, ${file_target}"
                fi
              fi
              if [ -n ${file_chmod} ] && [ ${file_chmod} != null ]; then
                if ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} sudo chmod ${file_chmod} ${file_target}; then
                  echo "[${fqdn}:file ${file_index}] chmod succeeded: ${file_chmod}, ${file_target}"
                else
                  echo "[${fqdn}:file ${file_index}] chmod failed: ${file_chmod}, ${file_target}"
                fi
              fi
              file_post_command_list_as_base64=$(_decode_property ${file_as_base64} '(.command.post//empty)|.[]|@base64')
              command_index=0
              for file_post_command_as_base64 in ${file_post_command_list_as_base64[@]}; do
                command=$(echo ${file_post_command_as_base64} | base64 --decode)
                ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} "${command}" &> /dev/null
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
        unset file_source_ext
        unset file_target
        unset file_sha256_expected
        unset file_shagit_expected
        file_index=$((file_index+1))
      done

      service_list_as_base64=$(yq -r  '.service//empty' ${manifest_path} | jq -r '.[] | @base64')
      service_index=0
      observation_error_log=${tmp}/${fqdn}/service-checksum-observation-error.log
      for service_as_base64 in ${service_list_as_base64[@]}; do
        service_source=$(_decode_property ${service_as_base64} .source)
        service_target=$(_decode_property ${service_as_base64} .target)
        service_unit=$(basename ${service_target})
        service_sha256_expected=$(_decode_property ${service_as_base64} .sha256)

        if [ ${#service_sha256_expected} -eq 64 ]; then
          service_sha256_observed=$(ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} "sudo sha256sum ${service_target} 2> /dev/null | cut -d ' ' -f 1" 2> ${observation_error_log})
          if grep -q "timed out" ${observation_error_log} &> /dev/null; then
            echo "[${fqdn}:service ${service_index}] sha256 observation failed due to connection timeout. target: ${service_target}, source: ${service_source}, sha256 expected: ${service_sha256_expected}, observation error: $(cat ${observation_error_log} | tr '\n' ' ')"
            rm -f ${observation_error_log}
            continue
          elif [ $(grep . ${observation_error_log} | wc -l | cut -d ' ' -f 1) -gt 0 ]; then
            echo "[${fqdn}:service ${service_index}] sha256 observation failed. target: ${service_target}, source: ${service_source}, sha256 expected: ${service_sha256_expected}, observation error: $(cat ${observation_error_log} | tr '\n' ' ')"
            rm -f ${observation_error_log}
            continue
          fi
          rm -f ${observation_error_log}
        elif [[ ${service_source} == "https://raw.githubusercontent.com/"* ]]; then
          service_source_owner=$(echo ${service_source} | cut -d '/' -f 4)
          service_source_repo=$(echo ${service_source} | cut -d '/' -f 5)
          service_source_rev=$(echo ${service_source} | cut -d '/' -f 6)
          service_source_path=$(echo ${service_source} | cut -d '/' -f 7-)
          service_shagit_expected=$(curl \
            --silent \
            --location \
            --header 'X-GitHub-Api-Version: 2022-11-28' \
            --header 'Accept: application/vnd.github.object' \
            --header "Authorization: Bearer ${rubberneck_github_token}" \
            --url "https://api.github.com/repos/${service_source_owner}/${service_source_repo}/contents/${service_source_path}?ref=${service_source_rev}" \
            | jq -r '.sha')
          service_shagit_observed=$(ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} "sudo git hash-object ${service_target} 2> /dev/null" 2> ${observation_error_log})
          if grep -q "timed out" ${observation_error_log} &> /dev/null; then
            echo "[${fqdn}:service ${service_index}] git sha observation failed. target: ${service_target}, source: ${service_source}, git sha expected: ${service_shagit_expected}, observation error: $(head -n 1 ${observation_error_log})"
            rm -f ${observation_error_log}
            continue
          fi
          rm -f ${observation_error_log}
        fi

        if [ ${#service_sha256_expected} -eq 64 ] && [ ${#service_sha256_observed} -eq 64 ] && [ "${service_sha256_expected}" = "${service_sha256_observed}" ]; then
          # observed sha256 checksum is valid and matches expected sha256 checksum
          echo "[${fqdn}:service ${service_index}] sha256 validation succeeded. target: ${service_target}, source: ${service_source}, sha256 expected: ${service_sha256_expected}, observed: ${service_sha256_observed}"
        elif [ ${#service_shagit_expected} -eq 40 ] && [ ${#service_shagit_observed} -eq 40 ] && [ "${service_shagit_expected}" = "${service_shagit_observed}" ]; then
          # observed git sha is valid and matches expected git sha
          echo "[${fqdn}:service ${service_index}] git sha validation succeeded. target: ${service_target}, source: ${service_source}, git sha expected: ${service_shagit_expected}, observed: ${service_shagit_observed}"
        else
          if [ ${#service_sha256_expected} -eq 64 ]; then
            echo "[${fqdn}:service ${service_index}] sha256 validation failed. target: ${service_target}, source: ${service_source}, sha256 expected: ${service_sha256_expected}, observed: ${service_sha256_observed}"
          elif [ ${#service_shagit_expected} -eq 40 ]; then
            echo "[${fqdn}:service ${service_index}] git sha validation failed. target: ${service_target}, source: ${service_source}, git sha expected: ${service_shagit_expected}, observed: ${service_shagit_observed}"
          else
            echo "[${fqdn}:service ${service_index}] validation failed. target: ${service_target}, source: ${service_source}"
          fi
          service_pre_command_index=0
          declare -a service_pre_command_list=()
          if [[ ${service_unit} == *@.service ]]; then
            service_pre_command_list+=( "sudo systemctl stop '$(echo ${service_unit} | cut -d '@' -f 1)@*.service'" )
          else
            service_pre_command_list+=( "sudo systemctl stop ${service_unit}" )
          fi
          for service_pre_command in ${service_pre_command_list[@]}; do
            echo "[${fqdn}:service ${service_index}, pre command ${service_pre_command_index}] ${service_pre_command}"
            if [ "${action}" = "sync" ]; then
              ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} "${service_pre_command}" &> /dev/null
              command_exit_code=$?
              echo "[${fqdn}:service ${service_index}, pre command ${service_pre_command_index}] exit code: ${command_exit_code}, command: ${service_pre_command}"
            else
              echo "[${fqdn}:service ${service_index}, pre command ${service_pre_command_index}] skipped"
            fi
            service_pre_command_index=$((service_pre_command_index+1))
          done
          if [ "${action}" = "sync" ]; then
            if ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} sudo curl --fail --silent --location --output ${service_target} --url ${service_source}; then
              echo "[${fqdn}:service ${service_index}] download succeeded (${service_target}, ${service_source})"
              declare -a service_post_command_list=()
              service_post_command_index=0
              if [[ ${service_unit} == *@.service ]]; then
                service_instance_active_list=$(_decode_property ${service_as_base64} '(.state.active//empty)|.[]')
                for service_instance in ${service_instance_active_list[@]}; do
                  service_instance_unit=$(echo ${service_unit} | cut -d '@' -f 1)@${service_instance}.service
                  service_post_command_list+=( "sudo systemctl start ${service_instance_unit}" )
                done
                service_instance_enable_list=$(_decode_property ${service_as_base64} '(.state.enable//empty)|.[]')
                for service_instance in ${service_instance_enable_list[@]}; do
                  service_instance_unit=$(echo ${service_unit} | cut -d '@' -f 1)@${service_instance}.service
                  service_post_command_list+=( "sudo systemctl enable ${service_instance_unit}" )
                done
              else
                service_state_active=$(_decode_property ${service_as_base64} '.state.active')
                if [ "${service_state_active}" = "true" ]; then
                  service_post_command_list+=( "sudo systemctl start ${service_unit}" )
                fi
                service_state_enable=$(_decode_property ${service_as_base64} '.state.enable')
                if [ "${service_state_enable}" = "true" ]; then
                  service_post_command_list+=( "sudo systemctl enable ${service_unit}" )
                fi
              fi
              for service_post_command in ${service_post_command_list[@]}; do
                ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} "${service_post_command}" &> /dev/null
                command_exit_code=$?
                echo "[${fqdn}:service ${service_index}, post command ${service_post_command_index}] exit code: ${command_exit_code}, command: ${service_post_command}"
                service_post_command_index=$((service_post_command_index+1))
              done
            else
              echo "[${fqdn}:service ${service_index}] download failed (${service_target}, ${service_source})"
            fi
          fi
        fi
        # create commands to ensure service is active and enabled if configured to be
        declare -a service_command_list=()
        service_command_index=0
        if [[ ${service_unit} == *@.service ]]; then
          service_instance_active_list=$(_decode_property ${service_as_base64} '(.state.active//empty)|.[]')
          for service_instance in ${service_instance_active_list[@]}; do
            service_instance_unit=$(echo ${service_unit} | cut -d '@' -f 1)@${service_instance}.service
            service_command_list+=( "systemctl is-active ${service_instance_unit} || sudo systemctl start ${service_instance_unit}" )
          done
          service_instance_enable_list=$(_decode_property ${service_as_base64} '(.state.enable//empty)|.[]')
          for service_instance in ${service_instance_enable_list[@]}; do
            service_instance_unit=$(echo ${service_unit} | cut -d '@' -f 1)@${service_instance}.service
            service_command_list+=( "systemctl is-enabled ${service_instance_unit} || sudo systemctl enable ${service_instance_unit}" )
          done
        else
          service_state_active=$(_decode_property ${service_as_base64} '.state.active')
          if [ "${service_state_active}" = "true" ]; then
            service_command_list+=( "systemctl is-active ${service_unit} || sudo systemctl start ${service_unit}" )
          fi
          service_state_enable=$(_decode_property ${service_as_base64} '.state.enable')
          if [ "${service_state_enable}" = "true" ]; then
            service_command_list+=( "systemctl is-enabled ${service_unit} || sudo systemctl enable ${service_unit}" )
          fi
        fi
        for service_command in ${service_command_list[@]}; do
          ssh -o ConnectTimeout=${ssh_timeout} -i ${ops_private_key} -p ${ssh_port} ${ops_username}@${fqdn} "${service_command}" &> /dev/null
          command_exit_code=$?
          echo "[${fqdn}:service ${service_index}, command ${service_command_index}] exit code: ${command_exit_code}, command: ${service_command}"
          service_command_index=$((service_command_index+1))
        done
        unset service_source
        unset service_target
        unset service_unit
        unset service_sha256_expected
        unset service_shagit_expected
        service_index=$((service_index+1))
      done
    else
      echo "[${intent}/${hostname}] manifest fetch failed"
    fi
  done
done
rm -rf ${tmp}
