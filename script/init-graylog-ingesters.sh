#!/usr/bin/env bash

# create tcp ingester
curl \
    --silent \
    --user admin:$(pass quantus/graylog/root) \
    --header 'X-Requested-By: cli' \
    --header 'Content-Type: application/json' \
    --request POST \
    --data '{
        "title":"GELF TCP 12201",
        "type":"org.graylog2.inputs.gelf.tcp.GELFTCPInput",
        "global":true,
        "configuration": {
            "bind_address":"0.0.0.0",
            "port":12201,
            "recv_buffer_size":1048576,
            "tls_enable":false
        }
    }' \
    --url https://logs.res.fm/api/system/inputs

# create udp ingester
curl \
    --silent \
    --user admin:$(pass quantus/graylog/root) \
    --header 'X-Requested-By: cli' \
    --header 'Content-Type: application/json' \
    --request POST \
    --data '{
        "title":"GELF UDP 12201",
        "type":"org.graylog2.inputs.gelf.udp.GELFUDPInput",
        "global":true,
        "configuration": {
            "bind_address":"0.0.0.0",
            "port":12201,
            "recv_buffer_size":1048576
        }
    }' \
    --url https://logs.res.fm/api/system/inputs
