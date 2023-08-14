
CREATE USER 'beta'@'%.miyamoto.pelagos.systems' REQUIRE SUBJECT 'CN=beta.miyamoto.pelagos.systems';
GRANT REPLICATION SLAVE ON *.* TO 'beta'@'%.miyamoto.pelagos.systems';
