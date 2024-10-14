#!/bin/bash
DSUS=$(id -u) && \
DSGR=$(id -g) && \
DSPATH='/usr/local/dev-stats' && \
sudo rm -rf $DSPATH && \
sudo mkdir -p $DSPATH/{config,grafana-config,grafana-data,prometheus-data,loki-data,promtail-data} && \
sudo touch $DSPATH/grafana-config/grafana.ini && \
sudo chown -R $DSUS:$DSGR $DSPATH && \
sudo rm -rf ./dev-stats && \
git clone git@github.com:variegate-app/dev-stats.git dev-stats && \
cd dev-stats && \
cp config/* $DSPATH/config/ && \
docker-compose -f docker-compose.yaml up -d

# create docker secret first: docker secret create [OPTIONS] SECRET [file|-]
# https://docs.docker.com/engine/reference/commandline/secret_create/
# if you create secret from stdin use Ctrl+D after input, do not use Enter
