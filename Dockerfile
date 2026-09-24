FROM traccar/traccar:6.15.3-alpine

# Static configuration is baked into the image so the template deploys with ZERO
# deploy-form inputs. Dynamic values (DATABASE_URL, DATABASE_PASSWORD, DB_HOST)
# are injected by Railway as variable expressions referencing the MySQL service.
#
# In env-var mode Traccar ignores its bundled traccar.xml entirely, so every
# setting Traccar needs must exist as an environment variable. WEB_PORT and
# OSMAND_PORT also pin the listeners deterministically (Railway injects a
# PORT variable when a TCP proxy exists; Traccar ignores PORT, this makes it explicit).
ENV CONFIG_USE_ENVIRONMENT_VARIABLES=true \
    DATABASE_DRIVER=com.mysql.cj.jdbc.Driver \
    DATABASE_USER=root \
    WEB_PORT=8082 \
    OSMAND_PORT=5055

# mysql client is used by the entrypoint to wait for MySQL and create the database
RUN apk add --no-cache mysql-client

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /opt/traccar
ENTRYPOINT ["/entrypoint.sh"]
