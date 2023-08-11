
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST                   = 'alpha.miyamoto.pelagos.systems',
  SOURCE_PORT                   = 3306,
  SOURCE_USER                   = 'beta',
  SOURCE_SSL_CA                 = '/etc/ssl/ca.pem',
  SOURCE_SSL_CERT               = '/etc/ssl/cert.pem',
  #SOURCE_SSL_CAPATH             = '/etc/ssl/certs',
  SOURCE_SSL_KEY                = '/etc/ssl/key.pem',
  SOURCE_SSL_VERIFY_SERVER_CERT = 1,
  SOURCE_AUTO_POSITION          = 1;