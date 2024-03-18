#!/bin/bash

# create tables
asreview auth-tool create-db --db-uri=${ASREVIEW_LAB_SQLALCHEMY_DATABASE_URI}

# start gunicorn
gunicorn -w ${WORKERS} -b "0.0.0.0:5006" "asreview.webapp.app:create_app()"