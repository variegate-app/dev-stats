# Стек сервисов Grafana, Prometheus, Pushgateway, Loki и Promtail для Docker (compose)

Логи собираются со всех контейнеров без необходимости установки дополнительного ПО на ноды в кластере.
Метрики собираются с exporter'ов, которые устанавливаются отдельно (при необходимости).
Можно использовать также и на одной ноде (одной VM, одной машине) c docker compose.

## Быстрый старт

* Для docker compose

```bash
git clone git@github.com:variegate-app/dev-stats.git dev-stats && \
cd dev-stats && \
make install && \
make start
```

* Перейти в браузере по адресу [http:// **IP адрес сервера, на котором запущен стек** :3111](http://localhost:3111) (логин `admin` пароль `admin`)
* Расширенные labels не будут работать до внесения изменений в `/etc/docker/daemon.json`
* **Для корректной работы labels** необходимо внести в `/etc/docker/daemon.json` (на каждом хосте) настройку `log-driver` и `log-opts`
```json
{
   "metrics-addr":"0.0.0.0:9323",
   "log-driver": "json-file",
   "log-opts": {
     "labels-regex": "^.+"
  }
}
```
  * После внесения изменений в `/etc/docker/daemon.json` необходимо перезапустить docker daemon (`sudo systemctl restart docker`) для ОС, использующих systemctl
  * Для изменения логирования необходимо также перезапустить контейнеры (для compose и обычных контейнеров)

---
## Особенности конфигурации из примера

* В конфигурации `prometheus.yaml` указаны примеры сбора метрик с различных exporter'ов, для сбора метрик с них, последние необходимо установить и настроить (в противном случае, с отсутствующих не будут собираться метрики).

### Конфигурация отдельных сервисов

### Grafana

[Документация](https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/)

* Образ `grafana/grafana-oss:latest`
* Порт `3111`
* Для использования reserve proxy необходимо следовать [руководству](https://grafana.com/tutorials/run-grafana-behind-a-proxy/)
* Вместо редактирования `grafana.ini` домен и url можно указать в environment variables `GF_SERVER_DOMAIN`, `GF_SERVER_ROOT_URL`
* Начальный логин `admin` пароль `admin`

### Grafana image renderer

* Образ `grafana/grafana-image-renderer:latest`
* В основном сервисе (grafana) установить подключение к grafana image renderer:

```yaml
GF_RENDERING_SERVER_URL: "http://grafana-image-renderer:8081/render"
GF_RENDERING_CALLBACK_URL: "http://grafana:3000/"
GF_UNIFIED_ALERTING_SCREENSHOTS_CAPTURE: true
GF_LOG_FILTERS: "rendering:debug"
```

### Prometheus

[Документация](https://prometheus.io/docs/alerting/latest/configuration/)

* Образ `prom/prometheus:latest`
* Порт `9090`
* Команда: `command: ["--config.file=/etc/prometheus/prometheus.yaml", "--web.config.file=/etc/prometheus/web-config.yaml", "--web.enable-lifecycle"]` (`web.enable-lifecycle` для перечитывания `web-config` "на лету")

Пример `prometheus.yaml` (вместо `password` безопасно использовать `password_file` совместно с docker secrets)

```yaml
global:
  scrape_interval: 15s

scrape_configs:

# node exporter (https://github.com/prometheus/node_exporter)
- job_name: 'node'
  static_configs:
  - targets: ['192.168.100.2:9100', '192.168.100.4:9100', '192.168.100.6:9100'] # change 192.168.100.x to your nodes IPs
  basic_auth:
    username: 'admin' # change
    password: 'admin' # use password_file instead (docker secrets)
```

[Пример `web-config.yaml`](https://github.com/prometheus/prometheus/blob/main/documentation/examples/web-config.yaml) (используется для basic_auth)

* В данном примере один `web-config.yaml` будет использоваться и для prometheus и для pushgateway
* password_hash генерируется командой `htpasswd -nBC 10 "" | tr -d ':\n'` 
  * Если htpasswd не установлен: для Debian, Ubuntu `sudo apt install apache2-utils`
  * для ОС использующих yum `sudo yum install -y httpd-tools`

```yaml
basic_auth_users:
  admin: $2y$10$K7gXeAs0VbhjHMdlV1Hn0OlWcqIoK7P9s/dVKB3HoyYcLuscxSpXe # change "$2y$10..." to basic auth password_hash
```

* Время и максимальный объём хранимых логов можно настроить с помощь команд запуска `--storage.tsdb.retention.time=15d`, `--storage.tsdb.retention.size=0` (напр. `512MB`) 
  * [подробнее](https://prometheus.io/docs/prometheus/latest/storage/)

### Pushgateway

* Образ `prom/pushgateway:latest`
* Порт 9091
* Команда: `command: ["--web.config.file=/etc/prometheus/web-config.yaml", "--web.enable-lifecycle"]` (`web.enable-lifecycle` для перечитывания `web-config` "на лету")

В конфиг `prometheus.yaml` необходимо добавить в качестве target'а сервис pushgateway с `honor_labels: true`

```yaml
# pushgateway
- job_name: 'pushgateway'
  honor_labels: true
  static_configs:
  - targets: ['pushgateway:9091']
  basic_auth:
    username: 'admin' # change
    password: 'admin' # use password_file instead (docker secrets)
```

### Loki

* Образ `grafana/loki:latest`
* Порт 3100 
  * В примере порт закрыт, т.к. при использовании loki внутри docker обычно нет необходимости подключения к loki снаружи стека
  * При необходимости открыть порт: настроить авторизацию (например, средствами [nginx basic auth](https://docs.nginx.com/nginx/admin-guide/security-controls/configuring-http-basic-authentication/))
* Команда: `command: ["--config.file=/etc/loki/loki.yaml"]`

Содержимое стандартного файла конфигурации находится в контейнере в `/etc/loki/local-config.yaml`. Стандартный файл переопределяется командой `--config.file=/etc/loki/loki.yaml`

В стандартный файл можно добавить запрет отправки analytics:

```yaml
analytics:
  reporting_enabled: false
```

В конфигурации из примера переопределено значение `query_ingesters_within` для предотвращения проявления [grafana/loki/issues/6043](https://github.com/grafana/loki/issues/6043)

### Promtail

* Образ `grafana/promtail:latest`
* Команда: `["--config.file=/etc/promtail/promtail.yaml", "--config.expand-env=true"]`
* Сервис Promtail должен быть запущен по одному на каждой ноде, с контейнеров которой требуется собирать логи 
  * При этом, файл `/var/promtail/positions_${HOST_HOSTNAME}.yaml` (хранит позиции чтения файлов) уникальный для каждой ноды (в примере это достигается подстановкой ${HOST_HOSTNAME} в имя файла, но если вы не используете общий том для всех нод, то можно не брать во внимание эту особенность.

* В `promtail.yaml` можно использовать environment variables (например `custom_label: "${ENV}"`) для этого нужно передать дополнительно команду `-config.expand-env=true`