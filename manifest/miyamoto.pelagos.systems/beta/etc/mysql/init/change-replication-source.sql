
STOP REPLICA;
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST                   = 'alpha.miyamoto.pelagos.systems',
  SOURCE_PORT                   = 3306,
  SOURCE_USER                   = 'beta',
  SOURCE_SSL                    = 1,
  SOURCE_SSL_CA                 = '/var/lib/mysql/lets-encrypt-ca.pem',
  SOURCE_SSL_CERT               = '/var/lib/mysql/lets-encrypt-cert.pem',
  SOURCE_SSL_KEY                = '/var/lib/mysql/lets-encrypt-key.pem',
  SOURCE_SSL_VERIFY_SERVER_CERT = 1,
  SOURCE_AUTO_POSITION          = 1;
START REPLICA;
