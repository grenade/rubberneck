#!/usr/bin/env bash

repo=lavanet/lava
#latest_tag=$(curl \
#  --silent \
#  --location \
#  --url https://api.github.com/repos/${repo}/tags \
#  | jq -r '.[0].name')

if ! [[ " $(id -Gn) " == *" systemd-journal "* ]]; then
  echo "add user: ${USER}, to group: systemd-journal with: 'sudo usermod -a -G systemd-journal ${USER}'"
  exit 1
fi
latest_upgrade_panic=$(journalctl \
  --unit lava.service \
  --grep UPGRADE \
  --lines 1 \
  --no-pager)
if [[ ${latest_upgrade_panic} =~ (panic: UPGRADE [\"](.*)[\"] NEEDED) ]]; then
  required_tag=${BASH_REMATCH[2]}
  echo "determined required version from system journal: ${required_tag}"
else
  #required_tag=v0.21.1.2
  required_tag=v0.23.5
  echo "using default required version: ${required_tag}"
fi

binary_path=/var/lib/lava/.local/bin/lavad
binary_url=https://github.com/${repo}/releases/download/${required_tag}/lavad-${required_tag}-linux-amd64
config_path=/var/lib/lava/.lava/config
config_url=https://github.com/lavanet/lava-config/raw/main/testnet-2/default_lavad_config_files

[ -d $(dirname ${binary_path}) ] || mkdir -p $(dirname ${binary_path})

observed_version=$([ -x ${binary_path} ] && ${binary_path} version || echo "")
if [ "${observed_version}" = "${required_tag:1}" ]; then
  echo "${binary_path} version ${observed_version} matches latest version at ${binary_url}"
elif curl \
  --silent \
  --location \
  --output ${binary_path} \
  --url ${binary_url} \
  && chmod +x ${binary_path}; then
  echo "${binary_path} version ${required_tag:1} downloaded from ${binary_url}"
else
  echo "failed to download ${binary_path} version ${required_tag:1} from ${binary_url}"
  exit 1
fi

for toml in {app,client,config}.toml; do
  path=${config_path}/${toml}
  url=${config_url}/${toml}
  if [ -f ${path} ]; then
    echo "${path} observed, download skipped (${url})"
  elif curl \
    --silent \
    --location \
    --output ${path} \
    --url ${url}; then
    echo "${path} downloaded from ${url}"
  else
    echo "failed to download ${path} from ${url}"
    exit 1
  fi
done
