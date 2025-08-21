#!/usr/bin/env bash

declare -A chains=(
    [heisenberg]="^(allitnils|colin|rai)\\.thgttg\\.com$"
    [resonance]="^(bob|effrafax|frootmig)\\.thgttg\\.com$"
)

default_index_set_id=$(curl \
    --silent \
    --user admin:$(pass quantus/graylog/root) \
    --header 'X-Requested-By: cli' \
    --header 'Accept: application/json' \
    --header 'Content-Type: application/json' \
    --url https://logs.res.fm/api/system/indices/index_sets \
    | jq -r '.index_sets[] | select(.title=="Default index set") | .id')

echo "default index set id: ${default_index_set_id}"


for chain in "${!chains[@]}"; do

    # find stream
    stream_id=$(curl \
        --silent \
        --user admin:$(pass quantus/graylog/root) \
        --header 'X-Requested-By: cli' \
        --header 'Accept: application/json' \
        --header 'Content-Type: application/json' \
        --url https://logs.res.fm/api/streams \
        | jq -r --arg title ${chain} '.streams[] | select(.title == $title) | .id')
    if [ ${#stream_id} = 24 ]; then
        echo "found stream id: ${stream_id}, title: ${chain}"
    else
        # create stream
        stream_payload=$(jq \
            --compact-output \
            --null-input \
            --arg title ${chain} \
            --arg description "${chain} bootnodes" \
            --arg index_set_id ${default_index_set_id} \
            '{
                "title": $title,
                "description": $description,
                "matching_type": "AND",
                "remove_matches_from_default_stream": false,
                "index_set_id": $index_set_id
            }')
        echo "stream_payload: ${stream_payload}"
        stream_id=$(curl \
            --silent \
            --user admin:$(pass quantus/graylog/root) \
            --header 'X-Requested-By: cli' \
            --header 'Content-Type: application/json' \
            --request POST \
            --data "${stream_payload}" \
            --url https://logs.res.fm/api/streams \
            | jq -r .stream_id)
        echo "created stream id: ${stream_id}, title: ${chain}"
    fi
    if [ ${#stream_id} = 24 ]; then
        rules_response=$(curl \
            --silent \
            --user admin:$(pass quantus/graylog/root) \
            --header 'X-Requested-By: cli' \
            --header 'Accept: application/json' \
            --header 'Content-Type: application/json' \
            --url https://logs.res.fm/api/streams/${stream_id}/rules \
            | jq -c)
        rule_count=$(echo ${rules_response} | jq -r .total)
        echo "found ${rule_count} rules. stream id: ${stream_id}, title: ${chain}"
        if [ ${rule_count} = 2 ]; then
            continue
        fi
        # add rules
        for field in unit source; do
            case ${field} in
              unit)
                type=1
                value=resonance-node.service
                description="unit exact match"
                ;;
              *)
                type=2
                value=${chains[${chain}]}
                description="source host allowlist"
                ;;
            esac

            rule_payload=$(jq \
                --compact-output \
                --null-input \
                --arg type ${type} \
                --arg field ${field} \
                --arg value ${value} \
                --arg description "${description}" \
                '{
                    "type": ($type | tonumber),
                    "field": $field,
                    "value": $value,
                    "inverted": false,
                    "description": $description
                }')
            echo "rule_payload: ${rule_payload}"
            rule_id=$(curl \
                --silent \
                --user admin:$(pass quantus/graylog/root) \
                --header 'X-Requested-By: cli' \
                --header 'Content-Type: application/json' \
                --request POST \
                --data "${rule_payload}" \
                --url https://logs.res.fm/api/streams/${stream_id}/rules)
            echo "created rule id: ${rule_id}, stream: ${stream_id}"
        done
    fi
    if curl \
        --silent \
        --user admin:$(pass quantus/graylog/root) \
        --header 'X-Requested-By: cli' \
        --header 'Content-Type: application/json' \
        --request POST \
        --url https://logs.res.fm/api/streams/${stream_id}/resume; then
      echo "started stream id: ${stream_id}"
    fi
    unset stream_id
done
