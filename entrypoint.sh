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

cd /opt/traccar
exec /opt/traccar/jre/bin/java -XX:+ExitOnOutOfMemoryError -Xmx768m -jar tracker-server.jar conf/traccar.xml
