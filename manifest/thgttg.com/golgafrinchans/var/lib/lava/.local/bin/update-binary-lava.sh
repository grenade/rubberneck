#!/usr/bin/env bash

repo=lavanet/lava
#latest_tag=$(curl \
#  --silent \
#  --location \
#  --url https://api.github.com/repos/${repo}/tags \
#  | jq -r '.[0].name')
latest_tag=v0.21.1.2
binary_path=/var/lib/lava/.local/bin/lavad
binary_url=https://github.com/${repo}/releases/download/${latest_tag}/lavad-${latest_tag}-linux-amd64
config_path=/var/lib/lava/.lava/config
config_url=https://github.com/lavanet/lava-config/raw/main/testnet-2/default_lavad_config_files

[ -d $(dirname ${binary_path}) ] || mkdir -p $(dirname ${binary_path})

observed_version=$([ -x ${binary_path} ] && ${binary_path} version || echo "")
if [ "${observed_version}" = "${latest_tag:1}" ]; then
  echo "${binary_path} version ${observed_version} matches latest version at ${binary_url}"
elif curl \
  --silent \
  --location \
  --output ${binary_path} \
  --url ${binary_url} \
  && chmod +x ${binary_path}; then
  echo "${binary_path} version ${latest_tag:1} downloaded from ${binary_url}"
else
  echo "failed to download ${binary_path} version ${latest_tag:1} from ${binary_url}"
  exit 1
fi

for toml in {app,client,config}.toml; do
  path=${config_path}/${toml}
  url=${config_url}/${toml}
  if curl \
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
