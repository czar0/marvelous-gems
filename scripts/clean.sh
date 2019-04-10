#!/bin/bash

source $(pwd)/.env

docker rm -f -v $(docker ps -a | grep -E "peer|dev-|orderer|ca|cli" | awk '{print $1}') 2>/dev/null
docker rmi $(docker images -qf "dangling=true") 2>/dev/null
docker rmi $(docker images | grep "^<none>" | awk "{print $3}") 2>/dev/null

data_path="$(pwd)/data"
if [ -d "$data_path" ]; then
    rm -rf $data_path
fi

exit 0