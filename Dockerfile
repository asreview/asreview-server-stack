FROM ghcr.io/asreview/asreview:v1.6rc0

ARG CREATE_TABLES

RUN apt-get update \
    && apt-get install -y build-essential libpq-dev \
    && pip3 install --user gunicorn \
    && pip3 install --user psycopg2

COPY ./flask_config.toml /app
COPY ./init.sh /app
RUN ["chmod", "+x", "/app/init.sh"]

ENTRYPOINT ["/app/init.sh"]
