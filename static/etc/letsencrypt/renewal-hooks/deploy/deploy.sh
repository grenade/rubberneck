#!/bin/sh

cert_path=/etc/letsencrypt/live/$(hostname -f)
if [ -d ${cert_path} ] && [ -e ${cert_path}/privkey.pem ] && [ -e ${cert_path}/fullchain.pem ]; then

    # create mongod certs if mongod service enabled
    if systemctl list-unit-files mongod.service | grep 'mongod.service enabled' &> /dev/null; then
        echo "/etc/ssl/key+chain.pem created"
        if cat ${cert_path}/privkey.pem ${cert_path}/fullchain.pem > /etc/ssl/key+chain.pem; then
            if ln -sfr /etc/ssl/key+chain.pem /etc/ssl/mongod.pem; then
                echo "/etc/ssl/mongod.pem created"
            fi
            if systemctl is-active --quiet mongod.service; then
                systemctl restart mongod.service
            fi
        fi
    elif cat ${cert_path}/privkey.pem ${cert_path}/fullchain.pem > /etc/ssl/key+chain.pem; then
        echo "/etc/ssl/key+chain.pem created"
    fi

    # create postgres owned certs if postgres service enabled
    if systemctl list-unit-files postgresql.service | grep 'postgresql.service enabled' &> /dev/null; then
        if cp ${cert_path}/fullchain.pem /etc/ssl/fullchain.pem && cp ${cert_path}/privkey.pem /etc/ssl/privkey.pem; then
            echo "/etc/ssl/fullchain.pem created"
            echo "/etc/ssl/privkey.pem created"
            chown postgres:postgres /etc/ssl/fullchain.pem
            chown postgres:postgres /etc/ssl/privkey.pem
            chmod 600 /etc/ssl/privkey.pem
            if systemctl is-active --quiet postgresql.service; then
                systemctl restart postgresql.service
            fi
        fi
    fi

    # create mysql owned certs if mysql service enabled
    if systemctl list-unit-files mysql.service | grep 'mysql.service enabled' &> /dev/null; then
        if csplit \
            --prefix /tmp/cert \
            --elide-empty-files \
            /etc/letsencrypt/live/$(hostname -f)/fullchain.pem \
            '/-----BEGIN CERTIFICATE-----/' \
            '{*}' \
            && mv /tmp/cert01 /var/lib/mysql/lets-encrypt-ca.pem \
            && chown mysql:mysql /var/lib/mysql/lets-encrypt-ca.pem \
            && mv /tmp/cert00 /var/lib/mysql/lets-encrypt-cert.pem \
            && chown mysql:mysql /var/lib/mysql/lets-encrypt-cert.pem \
            && cp ${cert_path}/privkey.pem /var/lib/mysql/lets-encrypt-key.pem \
            && chmod 600 /var/lib/mysql/lets-encrypt-key.pem \
            && chown mysql:mysql /var/lib/mysql/lets-encrypt-key.pem; then
            echo "/var/lib/mysql/lets-encrypt-ca.pem created"
            echo "/var/lib/mysql/lets-encrypt-cert.pem created"
            echo "/var/lib/mysql/lets-encrypt-key created"
            if systemctl is-active --quiet mysql.service; then
                systemctl restart mysql.service
                mysql --login-path=root@localhost --execute='ALTER INSTANCE RELOAD TLS;'
            fi
        fi
    fi
fi
