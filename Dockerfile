FROM ghcr.io/asreview/asreview:v1.6rc1

ARG CREATE_TABLES

RUN apt-get update \
    && apt-get install -y libpq-dev \
    && pip3 install --user psycopg2

COPY ./init.sh /app
RUN ["chmod", "+x", "/app/init.sh"]

ENTRYPOINT ["/app/init.sh"]
