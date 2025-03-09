ifneq (,$(wildcard ./default.env))
    include ./default.env
    export
endif

DSUS = $$(id -u)
DSGR = $$(id -g)

install:
	@echo "installing"
	@mkdir -p ./.runtime/{config,secret,grafana-config,grafana-data,prometheus-data,loki-data,promtail-data}
	@touch ./.runtime/secret/{grafana_database_pass,node_exporter_pass,prometheus_pass}
	@touch ./.runtime/grafana-config/grafana.ini
	@chown -R ${DSUS}:${DSGR} ./.runtime
	@cp ./config/* ./.runtime/config/
	@cp ./default.env ./.env

uninstall:
	@echo "stopping docker"
	@docker-compose down --remove-orphans
	@docker volume prune --force
	@docker volume rm dev-stats_grafana-data dev-stats_grafana dev-stats_loki-data dev-stats_promtail-data dev-stats_prometheus-data --force
	@echo "clear path: ./.runtime"
	@rm -rf ./.runtime
	@echo "remove ./.env"
	@rm -f ./.env

start:
	@docker-compose up -d --build

stop:
	@docker-compose down --remove-orphans

