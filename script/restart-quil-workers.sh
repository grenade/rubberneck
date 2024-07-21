#!/usr/bin/env bash

echo "- $(tput bold)quordlepleen.thgttg.com$(tput dim)"
ssh quordlepleen.thgttg.com '
  echo "  - quilibrium.service: $(systemctl is-active quilibrium.service) $(systemctl is-enabled quilibrium.service)";
  systemctl is-active --quiet quilibrium.service || sudo systemctl restart quilibrium.service;
  systemctl is-enabled --quiet quilibrium.service || sudo systemctl enable quilibrium.service;
  for core in {1..24}; do
    echo "  - quilibrium-worker@${core}.service: $(systemctl is-active quilibrium-worker@${core}.service) $(systemctl is-enabled quilibrium-worker@${core}.service)";
    systemctl is-active --quiet quilibrium-worker@${core}.service || sudo systemctl restart quilibrium-worker@${core}.service;
  done
'
echo $(tput sgr0)

echo "- $(tput bold)allitnils.thgttg.com$(tput dim)"
ssh allitnils.thgttg.com '
  for core in {25..36}; do
    echo "  - quilibrium-worker@${core}.service: $(systemctl is-active quilibrium-worker@${core}.service) $(systemctl is-enabled quilibrium-worker@${core}.service)";
    systemctl is-active --quiet quilibrium-worker@${core}.service || sudo systemctl restart quilibrium-worker@${core}.service;
  done
'
echo $(tput sgr0)

echo "- $(tput bold)gramathea.thgttg.com$(tput dim)"
ssh gramathea.thgttg.com '
  for core in {37..96}; do
    echo "  - quilibrium-worker@${core}.service: $(systemctl is-active quilibrium-worker@${core}.service) $(systemctl is-enabled quilibrium-worker@${core}.service)";
    systemctl is-active --quiet quilibrium-worker@${core}.service || sudo systemctl restart quilibrium-worker@${core}.service;
  done
'
echo $(tput sgr0)

echo "- $(tput bold)hawalius.thgttg.com$(tput dim)"
ssh hawalius.thgttg.com '
  for core in {97..114}; do
    echo "  - quilibrium-worker@${core}.service: $(systemctl is-active quilibrium-worker@${core}.service) $(systemctl is-enabled quilibrium-worker@${core}.service)";
    systemctl is-active --quiet quilibrium-worker@${core}.service || sudo systemctl restart quilibrium-worker@${core}.service;
  done
'
echo $(tput sgr0)

echo "- $(tput bold)krikkit.thgttg.com$(tput dim)"
ssh krikkit.thgttg.com '
  for core in {115..132}; do
    echo "  - quilibrium-worker@${core}.service: $(systemctl is-active quilibrium-worker@${core}.service) $(systemctl is-enabled quilibrium-worker@${core}.service)";
    systemctl is-active --quiet quilibrium-worker@${core}.service || sudo systemctl restart quilibrium-worker@${core}.service;
  done
'
echo $(tput sgr0)

echo "- $(tput bold)midgard.v8r.io$(tput dim)"
ssh midgard.v8r.io '
  for core in {133..192}; do
    echo "  - quilibrium-worker@${core}.service: $(systemctl is-active quilibrium-worker@${core}.service) $(systemctl is-enabled quilibrium-worker@${core}.service)";
    systemctl is-active --quiet quilibrium-worker@${core}.service || sudo systemctl restart quilibrium-worker@${core}.service;
  done
'
echo $(tput sgr0)

echo "- $(tput bold)slartibartfast.thgttg.com$(tput dim)"
ssh slartibartfast.thgttg.com '
  for core in {193..204}; do
    echo "  - quilibrium-worker@${core}.service: $(systemctl is-active quilibrium-worker@${core}.service) $(systemctl is-enabled quilibrium-worker@${core}.service)";
    systemctl is-active --quiet quilibrium-worker@${core}.service || sudo systemctl restart quilibrium-worker@${core}.service;
  done
'
echo $(tput sgr0)
