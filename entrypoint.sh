#!/bin/sh
# Traccar on Railway — boot wrapper.
# 1. waits for MySQL (private network)
# 2. creates the traccar database if missing (replaces the MYSQL_DATABASE plugin var
#    so the template needs zero deploy-form prompts)
# 3. symlinks /opt/traccar/logs into the single persistent volume
# 4. execs Traccar exactly like the upstream image entrypoint

set -e

DB_HOST="${DB_HOST:-mysql.railway.internal}"
DB_USER="${DATABASE_USER:-root}"
DB_PASS="${DATABASE_PASSWORD:-}"

echo "[railway] waiting for MySQL at ${DB_HOST}:3306 ..."
i=0
while true; do
  if PROBE_ERR=$(mysql -h "$DB_HOST" -P 3306 -u"$DB_USER" -p"$DB_PASS" -e "SELECT 1;" 2>&1); then
    break
  fi
  i=$((i+1))
  if [ "$i" -le 2 ] || [ $((i % 6)) -eq 0 ]; then
    echo "[railway] probe #$i failed: $PROBE_ERR" | head -3
  fi
  if [ "$i" -ge 60 ]; then
    echo "[railway] MySQL not reachable after 5 minutes - giving up (Railway will restart)"
    exit 1
  fi
  sleep 5
done
echo "[railway] MySQL is up (waited $((i*5))s)"

echo "[railway] ensuring database 'traccar' exists"
mysql -h "$DB_HOST" -P 3306 -u"$DB_USER" -p"$DB_PASS" \
  -e "CREATE DATABASE IF NOT EXISTS traccar CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

echo "[railway] pointing /opt/traccar/logs into the persistent volume"
mkdir -p /opt/traccar/data/logs
rm -rf /opt/traccar/logs
ln -s /opt/traccar/data/logs /opt/traccar/logs

cd /opt/traccar
exec /opt/traccar/jre/bin/java -XX:+ExitOnOutOfMemoryError -Xmx768m -jar tracker-server.jar conf/traccar.xml
