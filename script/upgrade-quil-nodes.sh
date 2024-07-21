#!/usr/bin/env bash

os=linux
arch=amd64
release_files=($(curl -sL https://releases.quilibrium.com/release | grep ${os}-${arch}))
expected_version=$(echo ${release_files[0]} | sed 's/node-//' | sed "s/-${os}-${arch}//")
echo "expected version: ${expected_version}"

for release_file in ${release_files[@]}; do
  echo "-"
  echo "  file: ${release_file}"
  if test -s /tmp/${release_file} || curl \
    --silent \
    --location \
    --output /tmp/${release_file} \
    --url https://releases.quilibrium.com/${release_file}; then
    expected_sha256=$(sha256sum /tmp/${release_file} | cut -d ' ' -f 1)
    echo "  expected sha256: ${expected_sha256}"
    echo "  observations:"
    for fqdn in {{allitnils,colin,gramathea,hawalius,krikkit,quordlepleen,slartibartfast}.thgttg.com,midgard.v8r.io}; do
      echo "  -"
      echo "    fqdn: ${fqdn}"
      deployed_path=/var/lib/quilibrium/.local/bin/$(echo ${release_file/node/quilibrium} | sed "s/-${expected_version}-${os}-${arch}//")
      echo "    path: ${deployed_path}"
      observed_sha256=$(ssh ${fqdn} sudo -u quilibrium sha256sum ${deployed_path} | cut -d ' ' -f 1)
      if [ ${observed_sha256} = ${expected_sha256} ]; then
        checksum_status=✔️
      else
        checksum_status=❌
      fi
      echo "    observed sha256: ${checksum_status} ${observed_sha256}"
      if [ ${observed_sha256} != ${expected_sha256} ]; then
        ssh ${fqdn} "
          systemctl is-active quilibrium.service && sudo systemctl stop quilibrium.service
          sudo systemctl stop 'quilibrium-worker@*.service'
          sudo -u quilibrium curl -sLo ${deployed_path} https://releases.quilibrium.com/${release_file}
        "
      fi
    done
  fi
done

for fqdn in {{allitnils,colin,gramathea,hawalius,krikkit,quordlepleen,slartibartfast}.thgttg.com,midgard.v8r.io}; do
  echo "- ${fqdn}"
  ssh ${fqdn} '
    for sig in /var/lib/quilibrium/.local/bin/quilibrium.dgst.sig.{5,12}; do
      if sudo test -f ${sig} && sudo rm ${sig}; then
        echo "deleted ${sig}"
      fi
    done
  '
done

#for fqdn in {{allitnils,colin,gramathea,hawalius,krikkit,quordlepleen,slartibartfast}.thgttg.com,midgard.v8r.io}; do
#  observed_version=$(ssh ${fqdn} sudo -u quilibrium /var/lib/quilibrium/.local/bin/quilibrium --config /var/lib/quilibrium/.node --signature-check=0 --node-info 2> /dev/null | grep Version | cut -d ' ' -f 2)
#  echo "- ${fqdn}: quilibrium ${observed_version}"
#  ssh ${fqdn} "
#    for sig in /var/lib/quilibrium/.local/bin/quilibrium.dgst.sig.*; do
#    done
#    sudo test -f /var/lib/quilibrium/.local/bin/quilibrium.dgst.sig.2 && sudo rm \
#      /var/lib/quilibrium/.local/bin/quilibrium.dgst.sig.2;
#    sudo test -f /var/lib/quilibrium/.local/bin/quilibrium.dgst.sig.9 && sudo rm \
#      /var/lib/quilibrium/.local/bin/quilibrium.dgst.sig.9;
#    sudo test -f /var/lib/quilibrium/.local/bin/quilibrium.dgst.sig.12 || sudo -u quilibrium curl \
#      --output /var/lib/quilibrium/.local/bin/quilibrium.dgst.sig.12 \
#      --url https://releases.quilibrium.com/node-1.4.21-linux-amd64.dgst.sig.12;
#  "
#done
