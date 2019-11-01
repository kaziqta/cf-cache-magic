#!/bin/bash

#### Removal of page cache
find /path/to/cache -type f -type d -delete

#### Sitemap to be crawled
sitemap="https://domain.com/sitemap_index.xml"

#### Source for cloudflare auth - API key, email and zone ID
source .sec_env.sh

#### Purge the sitemap
curl -4 -s -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id:?}/purge_cache" \
            -H "X-Auth-Email: ${email:?}" \
            -H "X-Auth-Key: ${key:?}" \
            -H "Content-Type: application/json" \
            --data "{\"files\":[\"${sitemap}\"]}"
#### The loop - page cache prewarm and cloudflare page cache purge
for b in $(wget -q "${sitemap}" -O - | grep '^\s*<loc>' | sed 's/^\s*<loc>\(.*\)<\/loc>/\1/'); do
    curl -4 -s -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id:?}/purge_cache" \
        -H "X-Auth-Email: ${email:?}" \
        -H "X-Auth-Key: ${key:?}" \
        -H "Content-Type: application/json" \
        --data "{\"files\":[\"${b}\"]}"
    for i in $(wget -q "${b}" -O - | grep '^\s*<loc>' | sed 's/^\s*<loc>\(.*\)<\/loc>/\1/'); do
        sleep .3
        curl --silent "${i}" > /dev/null 2>&1 &
    done
done

#### The cloudflare purge magic - 20 domains per request 2 requests per second
count=0
LINKS=()
for b in $(wget -q "${sitemap}" -O - | grep '^\s*<loc>' | sed 's/^\s*<loc>\(.*\)<\/loc>/\1/'); do
    for i in $(wget -q "${b}" -O - | grep '^\s*<loc>' | sed 's/^\s*<loc>\(.*\)<\/loc>/\1/'); do
        LINKS+=($i)
        count=$((count+1))
    done
done
mod=$((count % 20))
if [ "$mod" -gt 0 ]; then
    ifmore=1
else
    ifmore=0
fi
cycles=($((count / 20)))
numbercycles=$((cycles + ifmore))
counter=0
x=","
for (( i=1; i <= "$numbercycles"; i++)); do
    START=${counter}
    if [ $i -eq "$numbercycles" ]; then
        END=$((counter+mod))
    else
        END=$((counter+20))
    fi

    for (( f="$START"; f <= "$((END - 1))";f++ )); do
        filesuse+="\"${LINKS[$f]}\"$x"
    done
    echo "failovete:"
    echo "${filesuse%?}"
    sleep 0.5
    curl -4 -s -X POST "https://api.cloudflare.com/client/v4/zones/${zone_id:?}/purge_cache" \
        -H "X-Auth-Email: ${email:?}" \
        -H "X-Auth-Key: ${key:?}" \
        -H "Content-Type: application/json" \
        --data "{\"files\":[${filesuse%?}]}"
    filesuse=""
    counter=$((counter+20))
done

