ca_cert_path=/home/grenade/git/grenade/rubberneck/static/var/lib/mysql/pelagos-ca.pem
ca_key_path=/home/grenade/manta/tls/pelagos-ca-key.pem

alpha_cert_path=/home/grenade/git/grenade/rubberneck/manifest/miyamoto.pelagos.systems/alpha/var/lib/mysql/pelagos-miyamoto-alpha-cert.pem
alpha_key_path=/home/grenade/manta/tls/pelagos-miyamoto-alpha-key.pem

beta_cert_path=/home/grenade/git/grenade/rubberneck/manifest/miyamoto.pelagos.systems/beta/var/lib/mysql/pelagos-miyamoto-beta-cert.pem
beta_key_path=/home/grenade/manta/tls/pelagos-miyamoto-beta-key.pem

# generate self-signed pelagos ca cert and key
openssl req \
  -new \
  -newkey ec \
  -noenc \
  -pkeyopt ec_paramgen_curve:prime256v1 \
  -x509 \
  -subj '/C=US/O=Manta/CN=Pelagos' \
  -days 3652 \
  -out ${ca_cert_path} \
  -keyout ${ca_key_path}

# generate pelagos-ca-signed miyamoto-alpha cert and key
openssl req \
  -new \
  -newkey ec \
  -noenc \
  -pkeyopt ec_paramgen_curve:prime256v1 \
  -x509 \
  -subj '/C=DE/O=Manta/CN=pelagos-miyamoto-alpha' \
  -days 365 \
  -CA ${ca_cert_path} \
  -CAkey ${ca_key_path} \
  -out ${alpha_cert_path} \
  -keyout ${alpha_key_path}

# generate pelagos-ca-signed miyamoto-beta cert and key
openssl req \
  -new \
  -newkey ec \
  -noenc \
  -pkeyopt ec_paramgen_curve:prime256v1 \
  -x509 \
  -subj '/C=FI/O=Manta/CN=pelagos-miyamoto-beta' \
  -days 365 \
  -CA ${ca_cert_path} \
  -CAkey ${ca_key_path} \
  -out ${beta_cert_path} \
  -keyout ${beta_key_path}
