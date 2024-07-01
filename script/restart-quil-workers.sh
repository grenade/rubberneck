#!/usr/bin/env bash

echo allitnils.thgttg.com
ssh allitnils.thgttg.com 'for core in {25..36}; do systemctl is-active quilibrium-worker@${core}.service || sudo systemctl restart quilibrium-worker@${core}.service; done'

echo gramathea.thgttg.com
ssh gramathea.thgttg.com 'for core in {37..96}; do systemctl is-active quilibrium-worker@${core}.service || sudo systemctl restart quilibrium-worker@${core}.service; done'

echo hawalius.thgttg.com
ssh hawalius.thgttg.com 'for core in {97..114}; do systemctl is-active quilibrium-worker@${core}.service || sudo systemctl restart quilibrium-worker@${core}.service; done'

echo krikkit.thgttg.com
ssh krikkit.thgttg.com 'for core in {115..132}; do systemctl is-active quilibrium-worker@${core}.service || sudo systemctl restart quilibrium-worker@${core}.service; done'

echo quordlepleen.thgttg.com
ssh quordlepleen.thgttg.com 'for core in {1..24}; do systemctl is-active quilibrium-worker@${core}.service || sudo systemctl restart quilibrium-worker@${core}.service; done'

echo slartibartfast.thgttg.com
ssh slartibartfast.thgttg.com 'for core in {193..204}; do systemctl is-active quilibrium-worker@${core}.service || sudo systemctl restart quilibrium-worker@${core}.service; done'

echo midgard.v8r.io
ssh midgard.v8r.io 'for core in {133..192}; do systemctl is-active quilibrium-worker@${core}.service || sudo systemctl restart quilibrium-worker@${core}.service; done'
