#!/bin/sh
# Traccar on Railway — boot wrapper.
# 1. waits for MySQL and creates the traccar database if missing (CreateDb helper,
#    compiled against the image's own JDBC driver — replaces the MYSQL_DATABASE
#    plugin var so the template needs zero deploy-form prompts)
# 2. symlinks /opt/traccar/logs into the single persistent volume
# 3. execs Traccar exactly like the upstream image entrypoint

set -e

echo "[railway] pointing /opt/traccar/logs into the persistent volume"
mkdir -p /opt/traccar/data/logs
rm -rf /opt/traccar/logs
ln -s /opt/traccar/data/logs /opt/traccar/logs

echo "[railway] waiting for MySQL and ensuring database 'traccar' exists ..."
/opt/traccar/jre/bin/java -cp '/opt/traccar/lib/*:/opt/traccar' CreateDb

# TCP front for the device-ingest port (see HealthMux.java)
if [ -n "${PORT:-}" ] && [ "${PORT}" != "${WEB_PORT:-8082}" ]; then
  /opt/traccar/jre/bin/java -cp /opt/traccar HealthMux &
  echo "[railway] HealthMux started on PORT=${PORT}"
fi

# Run Traccar in the background, wait for the web server, then seed the default
# admin account through Traccar's own API (only succeeds while the users table is
# empty, i.e. on the very first boot — later boots get 401 and ignore it).
cd /opt/traccar
/opt/traccar/jre/bin/java -XX:+ExitOnOutOfMemoryError -Xmx768m -jar tracker-server.jar conf/traccar.xml &
APP_PID=$!

echo "[railway] waiting for the Traccar web server ..."
i=0
while ! wget -q -O /dev/null http://127.0.0.1:8082/api/health 2>/dev/null; do
  i=$((i+1))
  if [ "$i" -ge 120 ]; then
    echo "[railway] web server did not come up in time - giving up (Railway will restart)"
    kill "$APP_PID" 2>/dev/null
    exit 1
  fi
  sleep 5
done

echo "[railway] ensuring default admin account exists"
wget -q -O /dev/null --header "Content-Type: application/json" \
  --post-data '{"name":"Administrator","email":"admin","password":"admin"}' \
  http://127.0.0.1:8082/api/users 2>/dev/null \
  && echo "[railway] default admin seeded (admin/admin - CHANGE IT after first login)" \
  || echo "[railway] users already exist, skipping admin seed"

wait "$APP_PID"
