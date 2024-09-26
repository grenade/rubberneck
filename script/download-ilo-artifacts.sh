#!/usr/bin/env bash

script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
manifest_path=${script_dir}/ilo-artifacts.yml

_decode_property() {
  echo ${1} | base64 --decode | jq -r ${2}
}

ilo_versions=$(yq --raw-output '[.[].target | split("/")[-4] | sub("\\ilo";"")] | sort | unique | .[]' ${manifest_path})
for ilo_version in ${ilo_versions[@]}; do
  echo "ilo ${ilo_version}"
  firmware_versions=$(yq --arg ilo_verson ${ilo_version} '[.[] | select((.target | split("/")[-4]) == ("ilo" + $ilo_verson)) | .target | split("/")[-2] | tonumber] | sort | unique | .[]' ${manifest_path})
  for firmware_version in ${firmware_versions[@]}; do
    echo "  v${firmware_version}"
    artifact_extensions=$(yq \
      --raw-output \
      --arg ilo_version ${ilo_version} \
      --arg firmware_version ${firmware_version} \
      '[ .[] | select(((.target | split("/")[-4]) == ("ilo" + $ilo_version)) and ((.target | split("/")[-2]) == $firmware_version)) | .target | split(".")[-1] ] | sort | unique | .[]' \
      ${manifest_path})
    for artifact_extension in ${artifact_extensions[@]}; do
      echo "    ${artifact_extension}"
      artifacts_base64=$(yq \
        --raw-output \
        --arg ilo_version ${ilo_version} \
        --arg firmware_version ${firmware_version} \
        --arg artifact_extension ${artifact_extension} \
        '.[] | select(((.target | split("/")[-4]) == ("ilo" + $ilo_version)) and ((.target | split("/")[-2]) == $firmware_version) and (.target | endswith($artifact_extension))) | @base64' \
        ${manifest_path})
      for artifact_base64 in ${artifacts_base64[@]}; do
        artifact_source=$(_decode_property ${artifact_base64} .source)
        artifact_target=$(_decode_property ${artifact_base64} .target)
        artifact_sha256=$(_decode_property ${artifact_base64} .sha256)
        download_status="checksum validated"
        download_attempts=0
        while [ "$(sha256sum ${artifact_target} 2> /dev/null | cut -d ' ' -f 1)" != "${artifact_sha256}" ] && ((download_attempts < 3)); do
          mkdir -p $(dirname ${artifact_target})
          download_attempts=$((download_attempts + 1))
          # todo (debug):
          # - why does only the third attempt succeed when downloading pdf files?
          # - why is the checksum always wrong on the first check of pdf files even though it validated successfully (on the third download attempt) of the preceeding script run?
          if curl \
            --fail \
            --location \
            --silent \
            --output ${artifact_target} \
            --url ${artifact_source} \
            && [ "$(sha256sum ${artifact_target} 2> /dev/null | cut -d ' ' -f 1)" = "${artifact_sha256}" ]; then
            download_status="download ${download_attempts} succeeded"
          else
            download_status="download ${download_attempts} failed"
          fi
        done
        echo "      -"
        echo "        source: ${artifact_source}"
        echo "        target: ${artifact_target}"
        echo "        sha256: ${artifact_sha256}"
        echo "        status: ${download_status}"
      done
    done
  done
done
