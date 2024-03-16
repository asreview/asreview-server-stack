FROM ghcr.io/asreview/asreview:v1.6rc0

# ADD THIS TO DEFAULT ASREVIEW DOCKERFILE

# ARG CREATE_TABLES

RUN apt-get update \
    && apt-get install -y build-essential libpq-dev \
    && pip3 install --user gunicorn \
    && pip3 install --user psycopg2

# COPY ./flask_config.toml /app

# RUN "${CREATE_TABLES}"

ENTRYPOINT [ "asreview" ]
