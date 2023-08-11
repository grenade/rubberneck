
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST                   = 'alpha.miyamoto.pelagos.systems',
  SOURCE_PORT                   = 3306,
  SOURCE_USER                   = 'beta',
  SOURCE_SSL_CA                 = '/etc/ssl/chain.pem',
  SOURCE_SSL_CERT               = '/etc/ssl/cert.pem',
  SOURCE_SSL_KEY                = '/etc/ssl/key.pem',
  SOURCE_SSL_CIPHER             = 'TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256',
  SOURCE_SSL_VERIFY_SERVER_CERT = 1,
  SOURCE_TLS_VERSION            = 'TLSv1.3',
  SOURCE_AUTO_POSITION          = 1;