#!/usr/bin/env bash
# Restore drill, part 2 (the app): InvoiceNinja on amanita from the backups pulled from the Pi, with the
# Pi's exact images (by digest) and its own compose file, .env and nginx config. App, MySQL and Redis sit
# on an internal network with no way out; only nginx also joins a normal one, to serve 127.0.0.1:8012
# (the APP_URL the .env names). Data lives in docker volumes: `down` removes everything.
#   up:    hosts/raspi/drills/invoiceninja-app.sh up
#   down:  hosts/raspi/drills/invoiceninja-app.sh down
set -euo pipefail
S=${XDG_RUNTIME_DIR:-/tmp}
D=$S/drill-ninja
P=drill-ninja
dc() { docker compose -p "$P" -f "$D/drill.yml" --env-file "$D/.env" "$@"; }

if [ "${1:-}" = down ]; then
  dc down -v --remove-orphans 2>&1 | tail -2
  rm -rf "$D"
  echo "drill removed"
  exit 0
fi

b=/mnt/backup/current/invoiceninja_rpi
cfg=$(ls -t $b/configs/invoiceninja-config-*.tar.gz | head -1)
files=$(ls -t $b/invoiceninja/files-*.tar.gz | head -1)
dump=$(ls -t $b/invoiceninja/db-*.sql.gz | head -1)
echo "from: $(basename "$cfg"), $(basename "$files"), $(basename "$dump")"

rm -rf "$D"
mkdir -p "$D"
umask 077
tar xzf "$cfg" -C "$D" docker-compose.yml .env nginx

# the Pi's compose, with its images pinned to what runs there, nothing restarting, and no way out
nix shell nixpkgs#yq-go -c yq '
  del(.services.app.build)
  | .services.app.image = "invoiceninja/invoiceninja-debian@sha256:bc39f58b632353ef591eb5411ad1da77229105ffce4347482904349171adca5b"
  | .services.nginx.image = "nginx@sha256:b2e814d28359e77bd0aa5fed1939620075e4ffa0eb20423cc557b375bd5c14ad"
  | .services.mysql.image = "mysql@sha256:32cdfd01c2996419a2ff4ced7234c06af60a63e714e182e3cc5966182b67034c"
  | .services.redis.image = "redis@sha256:73734b014e53b3067916918b70718ca188c16895511a272a020c9a71084eecda"
  | .services[].restart = "no"
  | .services.nginx.ports = ["127.0.0.1:8012:80"]
  | .services.nginx.networks = ["app-network", "web"]
  | .networks."app-network".internal = true
  | .networks.web = {"driver": "bridge"}
  | .volumes = {"app_cache": {}, "app_public": {}, "app_storage": {}, "mysql_data": {}, "redis_data": {}}
' "$D/docker-compose.yml" > "$D/drill.yml"

dc pull -q
dc create 2>&1 | tail -1
# the backed-up public/ and storage/ into the drill's volumes
docker run --rm -v "${P}_app_public:/p" -v "${P}_app_storage:/s" -v "$files:/f.tgz:ro" \
  "invoiceninja/invoiceninja-debian@sha256:bc39f58b632353ef591eb5411ad1da77229105ffce4347482904349171adca5b" \
  sh -c 'mkdir /tmp/x && tar xzf /f.tgz -C /tmp/x && cp -a /tmp/x/public/. /p/ && cp -a /tmp/x/storage/. /s/ && echo "files: $(find /s -type f | wc -l) in storage"' 2>/dev/null \
  || docker run --rm --entrypoint sh -v "${P}_app_public:/p" -v "${P}_app_storage:/s" -v "$files:/f.tgz:ro" \
  "invoiceninja/invoiceninja-debian@sha256:bc39f58b632353ef591eb5411ad1da77229105ffce4347482904349171adca5b" \
  -c 'mkdir /tmp/x && tar xzf /f.tgz -C /tmp/x && cp -a /tmp/x/public/. /p/ && cp -a /tmp/x/storage/. /s/ && echo "files: $(find /s -type f | wc -l) in storage"'

dc up -d mysql redis 2>&1 | tail -1
for _ in $(seq 1 60); do
  [ "$(docker inspect -f '{{.State.Health.Status}}' "$P-mysql-1" 2>/dev/null)" = healthy ] && break
  docker exec "$P-mysql-1" sh -c 'MYSQL_PWD="$MYSQL_PASSWORD" mysql -u"$MYSQL_USER" -e "select 1" "$MYSQL_DATABASE"' >/dev/null 2>&1 && break
  sleep 3
done
gunzip -c "$dump" | docker exec -i "$P-mysql-1" sh -c 'MYSQL_PWD="$MYSQL_PASSWORD" mysql -u"$MYSQL_USER" "$MYSQL_DATABASE"'
echo "database: imported"

dc up -d 2>&1 | tail -1
for _ in $(seq 1 60); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8012/ || true)
  case $code in 200|302) break ;; esac
  sleep 5
done
echo "http://localhost:8012 -> $code"
printf 'app reaching the internet: '
docker exec "$P-app-1" sh -c 'curl -s -m 5 -o /dev/null -w "%{http_code}" https://www.google.com 2>/dev/null || echo "blocked, as intended"'
echo
dc ps --format '{{.Service}}: {{.Status}}'
