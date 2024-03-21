# Deploy ASReview LAB Server with authentication (Docker Compose)

> ⚠️ Deploying Docker containers in a public environment requires careful
  consideration of security implications. Exposing services without proper
  safeguards can lead to potential security vulnerabilities, unauthorized
  access, and data breaches.

This repository, ASReview Server Stack, contains a recipe for building an
authenticated version of the ASReview LAB application in Docker containers in
Docker Compose. It allows multiple users to access the application and create
private projects. Users need to sign up (with various authentication methods)
and sign in to access the app.

> ℹ️ Looking for a standalone Dockerfile with ASReview LAB, simulate, insights or
  datatools? (Prefect for local use or small applications) See
  https://asreview.readthedocs.io/en/stable/installation.html#install-with-docker
  or https://github.com/asreview/asreview/pkgs/container/asreview.

## Installation

Install Docker and Docker Compose to deploy the server stack.

## Deploy to production

To run the ASReview LAB application as a shared service, a more complicated
container setup is adviced. A common, robust setup for a Flask application like
ASReview LAB is to use [Gunicorn](https://gunicorn.org/) as a WSGI server and
use [NGINX](https://www.nginx.com/) as a reverse proxy. See the Flask
documentation on [Deploying to
Production](https://flask.palletsprojects.com/en/3.0.x/deploying/) for more
information.

ASReview Server Stack consists of 3 containers: a database (PostgreSQL), an
ASReview, and a NGINX container. [Docker
Compose](https://docs.docker.com/compose/) is used to run and serve this
multi-container application. In this folder, you find the following files of
interest:

- `.env` - An environment variable file for all relevant (secret) parameters
  (ports, frontend-domain, database, and Gunicorn related parameters)
- `asreview.conf` - a NGINX configuration file
- `docker-compose.yml` - the Docker Compose file that will create the Docker
  containers
- `asreview_config.toml` - the ASReview LAB config file with, for example,
  authentication options and email server configuration.

### Running the containers

Make a clone or copy of the ASReview Server Stack folder. From the **root**
folder of the app execute the `docker compose` command to start your docker
containers in attached mode:

```
$ docker compose up
```

### Email server

For account verification, but also for the forgot-password feature, an email
server is required. However, maintaining an email server can be demanding. This can be avoided by using a third-party service like
[SendGrid](https://sendgrid.com/). Email server
settings can be set in the `asreview_config.toml` file.

#### SendGrid

In this recipe, we use the SMTP Relay Service from
[SendGrid](https://sendgrid.com/): every email sent by the ASReview application
will be relayed by this service. Sendgrid is free if you don't expect the
application to send more than 100 emails per day. Receiving reply emails from
end-users is not possible if you use the Relay service.

Create an account at Sendgrid. Sign in and click on "Email API" in the menu and
subsequently click on the "Integration Guide" link. Then, choose "SMTP Relay",
create an API key and copy the resulting settings (Server, Ports, Username and
Password) in your `asreview_config.toml` file. It's important to continue checking
the "I've updated my settings" checkbox when it's visible **and** click on the
"Next: verify Integration" button before you run the Docker containers.

It is also important to verify the reply address of any email the application
will send. While being logged in on the SendGrid website, click on "Settings" in
the menu, then on "Sender Authentication" and follow instructions.

### Parameters in the .env file

The `.env` file contains parameters to deploy all containers. All variables that
end with the `_PORT` suffix refer to the containers' external
network ports. The prefix of these variables explains for which container they
are used. Note that the external port of the frontend container, the container
that will be directly used by the end-user, is 8080 and not 80. Change this to
80 if you don't want to use port numbers in the URL of the ASReview LAB
application.

The value of the `WORKERS` parameter determines how many instances of the
ASReview app Gunicorn will start.

Variables prefixed with `POSTGRES` are intended for use with the PostgreSQL
database. The `_USER` and `_PASSWORD` variables represent the database user and
password, respectively. The `_DB` variable specifies the database name.

> ⚠️ Please be aware to change the password in the `.env` file. If deploying
  Docker containers in a public environment, it is advisable to modify the
  database user to something less predictable and strengthen the password for
  enhanced security.

### Deploying to cloud provider

#### Digital Ocean

The following section describes how to deploy the authenticated application with
email verification on [Digital Ocean](https://www.digitalocean.com/). The
deployment is done on a bare Droplet running Ubuntu 22.04 with 1 CPU, 2 GB of
memory and a 50 GB SSD disk. Root access is assumed.

First consideration is a (sub)domain name. If you have one, make sure the domain
name points to the IP address of the Droplet. In this description, the IP
address is used to reach the application through a browser.

Email verification (also handy for forgotten passwords) is used. For that, a
SendGrid password is required that comes from the [SendGrid setup](#sendgrid).

Ssh into your Droplet, update the list of packages and install the software for
Docker:

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
$ sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Enter 'Y' if prompted. If you get questions about restarting services just
select OK. Verify if all is up and running by creating a test container:

```
$ sudo docker run hello-world
```

If all is well a message 'Hello from Docker' should appear with other
information. Verify if Docker Compose is installed:

```
$ docker compose version
```

If this fails, install Docker Compose with:

```
$ sudo apt-get install docker-compose-plugin
```

Next up are ports. It's best practice to enable the firewall and open the ports
we need. In this manual the frontend will run on port 8080 (deliberately
deviating from the usual port 80), and the backend runs on 8081.

```
$ sudo ufw default allow outgoing
$ sudo ufw default deny incoming
$ sudo ufw allow ssh
$ sudo ufw allow 8080
$ sudo ufw allow 8081
$ sudo ufw enable
```

Clone the ASReview Server Stack extension in the `asreview` folder:

```
$ git clone https://github.com/asreview/asreview-server-stack.git
```

Next up is configuring the `.env` file in server stack folder. Substitute
`localhost` for the Droplet's IP address and enter the reserved external port
numbers:

```
FRONTEND_DOMAIN=http://<IP address of Droplet>

FRONTEND_EXTERNAL_PORT=8080
BACKEND_EXTERNAL_PORT=8081

POSTGRES_PASSWORD="<Postgres Password>"
POSTGRES_USER="postgres"
POSTGRES_DB="asreview_db"
```

With that out of the way, the containers can be build. Assuming the `asreview`
root folder is the working directory, enter the following command:

```
$ docker compose up
```

This probably takes a couple of minutes. Wait until all containers are accounted
for (spinning up the backend container takes a bit longer than the other
containers). Try to access the application by browsing to the IP address. Note
that the instance runs on http, **not** https. If all is well, stop the
containers and spin them up again in detached mode:

```
docker compose up -d
```

#### Trouble Shooting

If the containers are built and running, but the application is unresponsive,
consider the following guidelines:

If there is no response whatsoever (no white page with spinner) check the url
and the protocol that are used in the browser. Does it use http instead of
https, and is the correct port being used (`http://<IP-address>:8080`)? If
that's the case, verify if the designated ports are really open on the Droplet.

In the `asreview_config.toml` the `SESSION_COOKIE_SAMESITE` parameter is set to the recommended
"Lax" value. In this Docker setup, it is assumed that both the backend and
frontend can be accessed using the same domain name or IP address. When this is
not the case, don't forget to set the value of `SESSION_COOKIE_SAMESITE` to the
string "None". Although this is an unusual setup it may help if you only deploy
the backend and database containers and have a different frontend running on
another server.

Finally, this setup does not support encryption. Its purpose is to deploy the
application as easy and quickly as possible. Dealing with certificates will make
things more complex. Since the unencrypted HTTP protocol is used, in
`asreview_config.toml` the `SESSION_COOKIE_SECURE` and `REMEMBER_COOKIE_SECURE`
parameters are set to `false`. If the setup is tweaked to work with
certificates, it is obviously best practice to set the values to `true`.
