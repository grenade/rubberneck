
CREATE USER 'replica'@'%'
  REQUIRE
    SUBJECT '/C=FI/O=Manta/CN=pelagos-miyamoto-beta'
  AND
    ISSUER '/C=US/O=Manta/CN=Pelagos';

GRANT REPLICATION SLAVE ON *.* TO 'replica'@'%';
