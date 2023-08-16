local_secrets_path=${HOME}/manta/tls
local_repo_path=${HOME}/git/grenade/rubberneck

remote_ca_path=/var/lib/mysql/pelagos-ca.pem
remote_cert_path=/var/lib/mysql/pelagos-cert.pem
remote_key_path=/var/lib/mysql/pelagos-key.pem

ca_cert_path=${local_repo_path}/static${remote_ca_path}
ca_key_path=${local_secrets_path}/pelagos-ca-key.pem
ca_cert_subject=/C=US/O=Manta/CN=Pelagos
ca_cert_validity=1460

source_hostname=alpha
source_domain=miyamoto.pelagos.systems
source_prefix=pelagos-miyamoto
source_country=DE
source_org=Manta
source_cert_path=${local_repo_path}/manifest/${source_domain}/${source_hostname}${remote_cert_path}
source_key_path=${local_secrets_path}/${source_prefix}-${source_hostname}-key.pem
source_cert_subject=/C=${source_country}/O=${source_org}/CN=${source_prefix}-${source_hostname}
source_cert_validity=90

replica_hostname=beta
replica_domain=miyamoto.pelagos.systems
replica_prefix=pelagos-miyamoto
replica_country=FI
replica_org=Manta
replica_cert_path=${local_repo_path}/manifest/${replica_domain}/${replica_hostname}${remote_cert_path}
replica_key_path=${local_secrets_path}/${replica_prefix}-${replica_hostname}-key.pem
replica_cert_subject=/C=${replica_country}/O=${replica_org}/CN=${replica_prefix}-${replica_hostname}
replica_cert_validity=90

elyptic_curve=prime256v1

# generate self-signed ca cert and key
if [ ! -e ${ca_key_path} ]; then
  mkdir -p $(dirname ${ca_cert_path}) $(dirname ${ca_key_path})
  openssl req \
    -new \
    -newkey ec \
    -noenc \
    -pkeyopt ec_paramgen_curve:${elyptic_curve} \
    -x509 \
    -subj ${ca_cert_subject} \
    -days ${ca_cert_validity} \
    -out ${ca_cert_path} \
    -keyout ${ca_key_path}
fi
rsync --rsync-path 'sudo rsync' -og --chown mysql:mysql -avz ${ca_cert_path} ${source_hostname}.${source_domain}:${remote_ca_path}
rsync --rsync-path 'sudo rsync' -og --chown mysql:mysql -avz ${ca_cert_path} ${replica_hostname}.${replica_domain}:${remote_ca_path}

# generate ca-signed source cert and key
if [ ! -e ${source_key_path} ]; then
  mkdir -p $(dirname ${source_cert_path}) $(dirname ${source_key_path})
  openssl req \
    -new \
    -newkey ec \
    -noenc \
    -pkeyopt ec_paramgen_curve:${elyptic_curve} \
    -x509 \
    -subj ${source_cert_subject} \
    -days ${source_cert_validity} \
    -CA ${ca_cert_path} \
    -CAkey ${ca_key_path} \
    -out ${source_cert_path} \
    -keyout ${source_key_path}
fi
rsync --rsync-path 'sudo rsync' -og --chown mysql:mysql -avz ${source_cert_path} ${source_hostname}.${source_domain}:${remote_cert_path}
rsync --rsync-path 'sudo rsync' -og --chown mysql:mysql --perms --chmod 600 -avz ${source_key_path} ${source_hostname}.${source_domain}:${remote_key_path}

# generate ca-signed replica cert and key
if [ ! -e ${replica_key_path} ]; then
  mkdir -p $(dirname ${replica_cert_path}) $(dirname ${replica_key_path})
  openssl req \
    -new \
    -newkey ec \
    -noenc \
    -pkeyopt ec_paramgen_curve:${elyptic_curve} \
    -x509 \
    -subj ${replica_cert_subject} \
    -days ${replica_cert_validity} \
    -CA ${ca_cert_path} \
    -CAkey ${ca_key_path} \
    -out ${replica_cert_path} \
    -keyout ${replica_key_path}
fi
rsync --rsync-path 'sudo rsync' -og --chown mysql:mysql -avz ${replica_cert_path} ${replica_hostname}.${replica_domain}:${remote_cert_path}
rsync --rsync-path 'sudo rsync' -og --chown mysql:mysql --perms --chmod 600 -avz ${replica_key_path} ${replica_hostname}.${replica_domain}:${remote_key_path}
