# Deploy ASReview LAB Server with authentication (Docker Compose)

> ⚠️ Deploying Docker containers in a public environment requires careful
  consideration of security implications. Exposing services without proper
  safeguards can lead to potential security vulnerabilities, unauthorized
  access, and data breaches.

This repository, ASReview Server Stack, contains a recipe for building an
authenticated version of the ASReview LAB application in Docker containers with
Docker Compose. It allows multiple users to access the application and create
private projects. Users need to sign up (with various authentication methods)
and sign in to access the application.

> ℹ️ Looking for a standalone Dockerfile with ASReview LAB, simulate, insights or
  datatools? (Perfect for local use or small applications) See
  https://asreview.readthedocs.io/en/stable/installation.html#install-with-docker
  or https://github.com/asreview/asreview/pkgs/container/asreview.

## Prerequisites

A deployment requires a server: a Linux machine with administrator
(`root`/`sudo`) access. The following software must be installed on this server:

- **Docker** and the **Docker Compose** plugin. Docker runs each part of the
  application in an isolated unit called a Docker container; Docker Compose
  starts and connects these Docker containers together.
- **git**, used to download (clone) this repository onto the server.

Installation procedures for this software differ per operating system. Follow the
official instructions for [Docker Engine](https://docs.docker.com/engine/install/)
and the [Docker Compose plugin](https://docs.docker.com/compose/install/); git is
available through the package manager of every common Linux distribution. The
[Preparing the server](#preparing-the-server) section gives a worked example for
Ubuntu. Once this software is installed, the remaining deployment steps are
identical across operating systems, because Docker runs the application in the
same way on each.

The two items above are sufficient for a basic deployment over plain HTTP. The
NGINX web server and the PostgreSQL database both run inside their own Docker
containers and are therefore installed automatically by Docker; they do not need
to be installed on the server separately.

Depending on the features required, the following are also needed:

- **A domain name**, with a DNS A record pointing to the server's IP address.
  This is required for HTTPS and optional otherwise. Without a domain name the
  application remains reachable by IP address over plain HTTP.
- **Certbot**, or another tool for obtaining TLS certificates. This is required
  only when the application is served over **HTTPS**. See [Upgrading security:
  migrate to HTTPS](#upgrading-security-migrate-to-https).
- **An SMTP service** such as [SendGrid](https://sendgrid.com/). This is
  required only for **email verification** and password-reset messages. See
  [Email verification](#email-verification-optional).
- **Open firewall ports**, at minimum the port on which the application is
  served (for example, port `80` for HTTP, or ports `80` and `443` for HTTPS).

## Preparing the server

The deployment requires Docker, the Docker Compose plugin, and git on the server,
as listed under [Prerequisites](#prerequisites). The commands in this section
install them on a fresh **Ubuntu** server, such as a DigitalOcean droplet or a
Hetzner Cloud VM. On other distributions, follow the official [Docker
installation instructions](https://docs.docker.com/engine/install/) instead; the
remaining sections are the same on every system.

### Install Docker

Connect to the server over SSH, then update the package list, remove any
conflicting older packages, and install Docker from its official repository:

```
$ sudo apt-get update
$ for pkg in docker.io docker-doc docker-compose docker-compose-v2 \
    podman-docker containerd runc; do sudo apt-get remove $pkg; done
$ sudo apt-get install ca-certificates curl gnupg
$ sudo install -m 0755 -d /etc/apt/keyrings
$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
$ sudo chmod a+r /etc/apt/keyrings/docker.gpg
$ echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
$ sudo apt-get update
$ sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Enter 'Y' if prompted. If questions about restarting services appear, select OK.
Verify that Docker and the Docker Compose plugin work:

```
$ sudo docker run hello-world
$ docker compose version
```

The first command should print a 'Hello from Docker' message. If the Compose
command is not found, install it explicitly with `sudo apt-get install
docker-compose-plugin`.

### Configure the firewall

As best practice, enable the firewall and open only the ports that are needed.
For the plain-HTTP [Quick start](#quick-start-http-without-a-domain-name), open
SSH and the frontend port (8080 by default):

```
$ sudo ufw default allow outgoing
$ sudo ufw default deny incoming
$ sudo ufw allow ssh
$ sudo ufw allow 8080
$ sudo ufw enable
```

The backend port (8081) does not need to be opened, because the backend is
reachable only from within the Docker network. For an HTTPS deployment, open
ports 80 and 443 instead (see [Upgrading security: migrate to
HTTPS](#upgrading-security-migrate-to-https)).

Cloud providers such as DigitalOcean and Hetzner apply a second, independent
firewall in their web console. When one is attached to the server, the same ports
must be opened there as well.

## Quick start (HTTP, without a domain name)

This section describes the quickest deployment: the application served over plain
HTTP and reached through the server's IP address, without a domain name or
certificates. Provided the [prerequisites](#prerequisites) are installed, the
steps below are identical on Ubuntu, Debian, CentOS, RHEL, and other common
distributions.

> ⚠️ Plain HTTP transmits all data, including passwords, unencrypted. This setup
  is suitable for testing or a trusted internal network. For any public-facing
  deployment, continue with [Upgrading security: migrate to
  HTTPS](#upgrading-security-migrate-to-https).

### 1. Get the code

Clone this repository onto the server and enter the created directory:

```
$ git clone https://github.com/asreview/asreview-server-stack.git
$ cd asreview-server-stack
```

All remaining commands are run from this directory.

### 2. Configure the environment

Three secret values are needed: a database password, a secret key, and a
password salt. On a system with OpenSSL installed, these can be generated as
follows:

```
$ openssl rand -base64 24   # database password
$ openssl rand -hex 32      # SECRET_KEY
$ openssl rand -hex 16      # SECURITY_PASSWORD_SALT
```

The configuration files described below are plain text and can be edited with any
text editor available on the server, for example `nano` (beginner-friendly) or
`vim`.

The `.env` file holds the deployment parameters. At a minimum, the PostgreSQL
password must be changed before deploying. The default frontend port is 8080;
setting it to 80 removes the port number from the application's URL.

```
FRONTEND_EXTERNAL_PORT=8080
BACKEND_EXTERNAL_PORT=8081

WORKERS=6

POSTGRES_PASSWORD="<the generated database password>"
POSTGRES_USER="postgres"
POSTGRES_DB="asreview_db"
```

See [Parameters in the .env file](#parameters-in-the-env-file) for a full
description of each parameter.

The `asreview_config.toml` file holds the application configuration. Before a
public deployment, the default `SECRET_KEY` and `SECURITY_PASSWORD_SALT` values
must be replaced with the generated `SECRET_KEY` and `SECURITY_PASSWORD_SALT`
values:

```
SECRET_KEY = "<the generated SECRET_KEY>"
SECURITY_PASSWORD_SALT = "<the generated SECURITY_PASSWORD_SALT>"
```

To require new users to verify their email address (and to enable password-reset
emails), see [Email verification](#email-verification-optional) before deploying.

### 3. Build and start the containers

The following command builds the ASReview Docker image and starts all three
Docker containers in attached mode, so that the log output remains visible:

```
$ docker compose up
```

The first build takes a few minutes. The deployment is ready once the log output
settles and the backend container reports that it is serving requests.

### 4. Verify and run in the background

While the containers run, navigate in a browser to the server's address and the
configured frontend port, for example `http://<server-IP>:8080` (or
`http://<server-IP>` when the port is set to 80). The ASReview LAB sign-in page
should appear. By default, account creation is enabled, so the first user can
register directly from the sign-in page.

Ensure that the frontend port is open in the server's firewall (see [Configure
the firewall](#configure-the-firewall)). On a cloud provider, the port must also
be opened in the provider's web-console firewall; this provider-level firewall is
the most common reason an application is unreachable even though the server's own
firewall allows the port.

Once the application responds, stop the attached containers with `Ctrl+C` and
start them again in detached (background) mode:

```
$ docker compose up -d
```

The application then keeps running after the terminal is closed and restarts
automatically if the server reboots.

## Email verification (optional)

By default, the application does not send email, and new accounts are usable
immediately. To require **email verification** of new accounts, and to enable
**password-reset** messages, the application needs access to an SMTP server.

Running a dedicated mail server is demanding, so an external SMTP relay service is
normally used. Many providers offer this, for example
[SendGrid](https://sendgrid.com/), [Mailgun](https://www.mailgun.com/),
[Amazon SES](https://aws.amazon.com/ses/), or an institutional mail server. The
exact steps to create relay credentials differ per provider and change over time,
so the chosen provider's own documentation should be followed. In all cases the
result is the same set of values: an SMTP host, a port, a username, and a password
or API key.

These values are entered in `asreview_config.toml`, where email verification is
also enabled:

```
EMAIL_VERIFICATION = true

MAIL_SERVER = "<the provider's SMTP host>"
MAIL_PORT = 465
MAIL_USE_TLS = false
MAIL_USE_SSL = true
MAIL_USERNAME = "<the provider's SMTP username>"
MAIL_PASSWORD = "<the provider's SMTP password or API key>"
MAIL_DEFAULT_SENDER = "no_reply@example.org"
```

The example above uses SSL on port 465. Some providers instead use STARTTLS on
port 587; in that case set `MAIL_PORT = 587`, `MAIL_USE_SSL = false`, and
`MAIL_USE_TLS = true`. The corresponding outbound port (465 or 587) must be open
for outbound connections in the server's firewall.

Most providers also require the sender address (`MAIL_DEFAULT_SENDER`) to be
verified before they deliver messages; the provider's documentation describes how.
After changing the configuration, restart the containers for the changes to take
effect.

## Upgrading security: migrate to HTTPS

This section assumes that the steps in the preceding sections have been completed and that the application runs correctly over plain HTTP.

For any public deployment, serving the application over HTTPS is strongly recommended. In this setup, the NGINX Docker container terminates HTTPS on port 443 and redirects plain HTTP (port 80) to it. The same certificates are also passed to the ASReview Docker container, so that Gunicorn serves the backend over TLS as well.

The following extra steps are required:
* Open ports 80 and 443 on the server.
* Obtain a domain name and TLS certificates for it.
* Adjust the configuration.

### Ports

The earlier sections used port 8080 for demonstration purposes. A secured application uses the default web ports 80 and 443, which must both be open. The backend port (8081) does not need to be opened, because the backend is reachable only from within the Docker network.

The firewall tool differs per distribution. On Ubuntu and Debian, using `ufw`:
```
$ sudo ufw allow 80
$ sudo ufw allow 443
```
As in [Preparing the server](#configure-the-firewall), cloud providers such as Hetzner and DigitalOcean require these ports to be opened in their separate web-console firewall as well.

### Domain name and certificates

The insecure version of the ASReview web application functions without a domain name; an IP address suffices. However, for a secure version, having a domain name is highly advisable. Ensure that there is an A record in the DNS linking the domain name to the server's IP address.

A detailed explanation of domain certificates and how to obtain them falls beyond the scope of this document. Usually an IT department provides them. An alternative is to obtain free certificates from Let's Encrypt using Certbot, as briefly explained below.

On the server, install [Certbot](https://certbot.eff.org/). The installation details differ per operating system; the Certbot website provides system-specific installation instructions. Once installed, shut down any web server running on the server and issue the following command:
```
$ sudo certbot certonly --standalone
```
Provide the requested email address, agree to the terms of service and enter the domain name when prompted. After completion, Certbot produces two important files: `fullchain.pem` and `privkey.pem`. On a Linux server these files can typically be found under `/etc/letsencrypt/live/<DOMAIN_NAME>/`. Copy both files into the `asreview-server-stack` folder.

### Update the configuration

Two files need to be adjusted: `asreview_config.toml` and `docker-compose.yml`. No change to the `.env` file is required; the application derives its public address from the incoming request, so no domain name has to be configured there.

#### 1. asreview_config.toml

Because the application is now served over HTTPS, the secure-cookie parameters must be enabled. Set both to `true`:
```
SESSION_COOKIE_SECURE = true
REMEMBER_COOKIE_SECURE = true
```

#### 2. docker-compose.yml

Two services change. The `asreview` service receives the certificate files and starts Gunicorn with them. The `server` (NGINX) service receives the certificates, listens on ports 80 and 443, and uses the HTTPS NGINX configuration file `asreview_https.conf` (already included in the repository) instead of `asreview.conf`.

Replace the `asreview` service with:
```
  asreview:
    build: .
    restart: always
    depends_on:
      database:
        condition: service_healthy
    volumes:
      - project-folder:/project_folder
      - ./asreview_config.toml:/app/asreview_config.toml
      - ./fullchain.pem:/app/fullchain.pem
      - ./privkey.pem:/app/privkey.pem
    environment:
      - ASREVIEW_LAB_API_URL=/
      - ASREVIEW_LAB_CONFIG_PATH=/app/asreview_config.toml
      - ASREVIEW_LAB_SQLALCHEMY_DATABASE_URI=postgresql+psycopg2://${POSTGRES_USER}:${POSTGRES_PASSWORD}@database:5432/${POSTGRES_DB}
    ports:
      - 127.0.0.1:${BACKEND_EXTERNAL_PORT}:5006
    entrypoint: []
    command: >
      bash -c "asreview auth-tool create-db
      && (asreview task-manager
      & gunicorn --certfile /app/fullchain.pem --keyfile /app/privkey.pem -w ${WORKERS} -b \"0.0.0.0:5006\" \"asreview.webapp.app:create_app()\")"
```

Replace the `server` service with:
```
  server:
    image: nginx:1.27
    restart: always
    ports:
      - 80:80
      - 443:443
    volumes:
      - ./asreview_https.conf:/etc/nginx/nginx.conf
      - ./fullchain.pem:/etc/pemfiles/fullchain.pem
      - ./privkey.pem:/etc/pemfiles/privkey.pem
    depends_on:
      - asreview
```
Unencrypted traffic to port 80 is automatically redirected to HTTPS on port 443.

### Restart

Recreate the containers so the new configuration takes effect:
```
$ docker compose down
$ docker compose up -d
```
The application is now served over HTTPS and can be reached at `https://<domain name>`.

## Reference

### How it works

ASReview Server Stack runs the application as three Docker containers,
orchestrated by [Docker Compose](https://docs.docker.com/compose/):

- a **PostgreSQL** database;
- the **ASReview** application, served by [Gunicorn](https://gunicorn.org/) as a
  WSGI server;
- an **NGINX** container acting as a reverse proxy in front of the application.

This mirrors a common, robust setup for a Flask application like ASReview LAB;
see the Flask documentation on [Deploying to
Production](https://flask.palletsprojects.com/en/3.0.x/deploying/) for
background.

The following files in the repository configure the deployment:

- `.env` — environment variables for all relevant (secret) parameters: ports,
  database credentials, and the number of Gunicorn workers.
- `docker-compose.yml` — the Docker Compose file that defines and connects the
  three containers.
- `asreview_config.toml` — the ASReview LAB configuration file (authentication
  options, secret key, email server settings, and so on).
- `asreview.conf` — the NGINX configuration used for plain HTTP.
- `asreview_https.conf` — the NGINX configuration used for HTTPS.

### Parameters in the .env file

The `.env` file contains parameters to deploy all containers. All variables that
end with the `_PORT` suffix refer to the Docker containers' external
network ports. The prefix of these variables explains for which container they
are used. Note that the external port of the frontend Docker container, the container
that is accessed directly by the end user, is 8080 and not 80. This can be changed to
80 to avoid port numbers in the URL of the ASReview LAB
application.

The value of the `WORKERS` parameter determines how many instances of the
ASReview application Gunicorn starts.

Variables prefixed with `POSTGRES` are intended for use with the PostgreSQL
database. The `_USER` and `_PASSWORD` variables represent the database user and
password, respectively. The `_DB` variable specifies the database name.

> ⚠️ The password in the `.env` file should be changed. When deploying
  Docker containers in a public environment, it is advisable to change the
  database user to something less predictable and to strengthen the password for
  enhanced security.

### Troubleshooting

If the containers are built and running, but the application is unresponsive,
consider the following guidelines:

If there is no response whatsoever (not even a white page with a spinner), check the URL
and the protocol used in the browser. Is HTTP used instead of
HTTPS, and is the correct port being used (`http://<IP-address>:8080`)? If
so, verify that the designated ports are actually open on the server (and, on a
cloud provider, in the provider's firewall as well).

If uploading a dataset fails with an error such as **HTTP 413 (Request Entity Too
Large)**, the file exceeds the maximum upload size enforced by the NGINX reverse
proxy. This limit is set by `client_max_body_size` in the active NGINX
configuration file — `asreview.conf` for HTTP, `asreview_https.conf` for HTTPS —
and defaults to `100M`. Increase it (for example to `500M`) and restart the
containers:
```
client_max_body_size 500M;
```
Very large or slow uploads can additionally exceed Gunicorn's default 30-second
worker timeout. If that occurs, add a longer timeout to the `gunicorn` command in
`docker-compose.yml`, for example `--timeout 120`.

In the `asreview_config.toml` the `SESSION_COOKIE_SAMESITE` parameter is set to the recommended
"Lax" value. In this Docker setup, it is assumed that both the backend and
frontend can be accessed using the same domain name or IP address. When this is
not the case, the value of `SESSION_COOKIE_SAMESITE` must be set to the
string "None". Although this is an unusual setup it may help when only the
backend and database containers are deployed and a different frontend runs on
another server.

By default, the Quick start serves the application over plain HTTP, which does not
support encryption. Because of this, the `SESSION_COOKIE_SECURE` and
`REMEMBER_COOKIE_SECURE` parameters in `asreview_config.toml` are set to `false`.
When the setup is adjusted to work with certificates, as described in [Upgrading
security: migrate to HTTPS](#upgrading-security-migrate-to-https), these values
must be set to `true`.
