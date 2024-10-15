#!/usr/bin/env bash

#rm -fr /tmp/quil
mkdir -p /tmp/quil

artifacts=($(curl -sL https://releases.quilibrium.com/release | grep linux-amd64))
for artifact in ${artifacts[@]}; do
  echo "  -"
  echo "    source: https://releases.quilibrium.com/${artifact}"
  echo "    target: /var/lib/quilibrium/.local/bin/${artifact/node-2.0.0.3-linux-amd64/quilibrium}"

  if [ ! -s /tmp/quil/${artifact} ]; then
    curl -sLo /tmp/quil/${artifact} --url https://releases.quilibrium.com/${artifact}
  fi
  sha256=$(sha256sum /tmp/quil/${artifact} | cut -d ' ' -f 1)
  echo "    sha256: ${sha256}"
  echo "    chown: quilibrium:quilibrium"
  if [[ ! ${artifact} =~ "dgst" ]]; then
    echo "    chmod: '+x'"
  fi
  #echo "  manifest:"
  #for manifest in $(find  ~/git/grenade/rubberneck/manifest/dimitar-talev/quordlepleen/ -type f -name manifest.yml); do
  #  if grep quilibrium ${manifest} > /dev/null; then
  #    old_version=1.4.21
  #    new_version=2.0.0.1
  #    sed -i "s/${old_version}/${new_version}/g" ${manifest}
  #    echo "    -"
  #    echo "      manifest: ${manifest}"
  #    old_sha=$(yq --arg source https://releases.quilibrium.com/${artifact} '.file[] | select(.source == $source) | .sha256' ${manifest})
  #    if [ "${old_sha}" = "${sha256}" ]; then
  #      echo "      found: ${old_sha}"
  #    else
  #      sed -i "s/${old_sha}/${sha256}/g" ${manifest}
  #      echo "      replaced: ${old_sha} with ${sha256}"
  #    fi
  #    #git --git-dir ~/git/grenade/rubberneck/.git --work-tree ~/git/grenade/rubberneck add ${manifest}
  #  fi
  #done
done
