
STOP REPLICA;
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST                   = 'alpha.miyamoto.pelagos.systems',
  SOURCE_PORT                   = 3306,
  SOURCE_USER                   = 'replica',
  SOURCE_AUTO_POSITION          = 1,
  SOURCE_SSL                    = 1,
  SOURCE_SSL_VERIFY_SERVER_CERT = 1,
  SOURCE_SSL_CA                 = '/var/lib/mysql/pelagos-ca.pem',
  SOURCE_SSL_CERT               = '/var/lib/mysql/pelagos-cert.pem',
  SOURCE_SSL_KEY                = '/var/lib/mysql/pelagos-key.pem',
  SOURCE_TLS_VERSION            = 'TLSv1.3';
START REPLICA;
