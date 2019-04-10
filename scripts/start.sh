#!/bin/sh

source $(pwd)/.env

hash docker || (echo "Please install docker first"; exit 1;)
hash docker-compose || (echo "Please install docker-compose first"; exit 1;)

docker-compose -f docker-compose.yaml down

docker-compose -f docker-compose.yaml up -d