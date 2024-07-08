#!/usr/bin/env bash

#rm -fr /tmp/quil
mkdir -p /tmp/quil

artifacts=($(curl -sL https://releases.quilibrium.com/release | grep linux-amd64))
for artifact in ${artifacts[@]}; do
  echo "-"
  echo "  artifact: ${artifact}"
  if [ ! -s /tmp/quil/${artifact} ]; then
    curl -sLo /tmp/quil/${artifact} --url https://releases.quilibrium.com/${artifact}
  fi
  sha256=$(sha256sum /tmp/quil/${artifact} | cut -d ' ' -f 1)
  echo "  sha256: ${sha256}"
  echo "  manifest:"
  for manifest in $(find  ~/git/grenade/rubberneck/manifest/dimitar-talev/**/ -type f -name manifest.yml); do
    if grep ${artifact} ${manifest} > /dev/null; then
      echo "    -"
      echo "      manifest: ${manifest}"
      old_sha=$(yq -r --arg source https://releases.quilibrium.com/${artifact} '.file[] | select(.source == $source) | .sha256' ${manifest})
      if [ "${old_sha}" = "${sha256}" ]; then
        echo "      found: ${old_sha}"
      else
        sed -i "s/${old_sha}/${sha256}/g" ${manifest}
        echo "      replaced: ${old_sha}"
      fi
      git --git-dir ~/git/grenade/rubberneck/.git --work-tree ~/git/grenade/rubberneck add ${manifest}
    fi
  done
done
