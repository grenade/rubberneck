#!/usr/bin/env bash

# on kavula
id resonance || sudo useradd --system --create-home --home-dir /var/lib/resonance --user-group resonance
sudo -u resonance ssh-keygen -o -a 100 -t ed25519 -f /var/lib/resonance/.ssh/id_resonance -C 'resonance ops <ops@res.fm>'
sudo -u resonance cat /var/lib/resonance/.ssh/id_resonance.pub
sudo curl \
    --fail \
    --silent \
    --location \
    --output /etc/systemd/system/sync-node-state@resonance.service \
    --url https://raw.githubusercontent.com/grenade/rubberneck/refs/heads/main/daemon/sync-node-state%40.service
sudo systemctl enable --now sync-node-state@resonance.service

# on target
id resonance || sudo useradd --system --create-home --home-dir /var/lib/resonance --user-group resonance
sudo -u resonance mkdir -p /var/lib/resonance/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGxhedWcnCqs5Kdw/aMgYH0ofFhKK9cH4bR3vlRQm6Rd" | sudo -u resonance tee /var/lib/resonance/.ssh/authorized_keys
