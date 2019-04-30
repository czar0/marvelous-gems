#!/bin/sh

source $(pwd)/.env

hash docker || (echo "Please install docker first"; exit 1;)
hash docker-compose || (echo "Please install docker-compose first"; exit 1;)

# tier down any previous configuration
docker-compose -f docker-compose.yaml down
sh $(pwd)/scripts/clean.sh

# start the network from scratch
docker-compose -f docker-compose.yaml up -d