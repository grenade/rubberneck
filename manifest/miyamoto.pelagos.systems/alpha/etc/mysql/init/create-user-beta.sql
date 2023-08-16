
CREATE USER 'beta'@'%'
  REQUIRE
    SUBJECT '/CN=beta.miyamoto.pelagos.systems'
  AND
    ISSUER '/C=US/O=Let\'s Encrypt/CN=R3';
GRANT REPLICATION SLAVE ON *.* TO 'beta'@'%';
FLUSH PRIVILEGES;
