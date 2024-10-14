ifneq (,$(wildcard ./default.env))
    include ./default.env
    export
endif

DSUS = $$(id -u)
DSGR = $$(id -g)

install:
	@echo "install path: " ${INSTALL_PATH}
	@sudo mkdir -p ${INSTALL_PATH}/{config,secret,grafana-config,grafana-data,prometheus-data,loki-data,promtail-data}
	@sudo touch ${INSTALL_PATH}/grafana-config/grafana.ini
	@sudo chown -R ${DSUS}:${DSGR} ${INSTALL_PATH}
	@cp ./config/* ${INSTALL_PATH}/config/
	@cp ./secret/* ${INSTALL_PATH}/secret/

start:
	@docker-compose up -d --build

clear:
	@echo "clear path: " ${INSTALL_PATH}
	@sudo rm -rf ${INSTALL_PATH}