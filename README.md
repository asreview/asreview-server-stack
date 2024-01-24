# ASReview server with authentication (Docker)

> ⚠️ Deploying Docker containers in a public environment requires careful consideration of security implications. Exposing services without proper safeguards can lead to potential security vulnerabilities, unauthorized access, and data breaches.

This repository contains a recipe for building an authenticated version of the ASReview LAB application in Docker containers. It allows multiple users to access the app and create private projects. It requires users to sign up and sign in to access the app.

> ℹ️ Looking for a Dockerfile with ASReview only (e.g., because you are looking for a standalone app on your computer for individual use)? See https://asreview.readthedocs.io/en/stable/installation.html#install-with-docker or https://github.com/asreview/asreview/pkgs/container/asreview. 

## Building an authenticated and email-verified version

If you would like to setup the ASReview application as a shared service, a more complicated container setup is required. A common, robust setup for a Flask/React application is to use [NGINX](https://www.nginx.com/) to serve the frontend and [Gunicorn](https://gunicorn.org/) to serve the backend. We build separate containers for a database (used for user accounts), and both front- and backend with [docker-compose](https://docs.docker.com/compose/).

For account verification, but also for the forgot-password feature, an email server is required. However, maintaining an email server can be demanding. If you want to avoid it, a third-party service like [SendGrid](https://sendgrid.com/) might be a good alternative. In this recipe, we use the SMTP Relay Service from Sendgrid: every email sent by the ASReview application will be relayed by this service. Sendgrid is free if you don't expect the application to send more than 100 emails per day. Receiving reply emails from end-users is not possible if you use the Relay service, but that might be irrelevant.

In this folder, you find 7 files of interest:
1. `.env` - An environment variable file for all relevant (secret) parameters (ports, frontend-domain, database, and Gunicorn related parameters)
2. `asreview.conf` - a configuration file used by NGINX.
3. `docker-compose.yml` - the docker compose file that will create the Docker containers.
4. `Dockerfile_backend` - Dockerfile for the backend, installs all Python-related software, including Gunicorn, and starts the backend server.
5. `Dockerfile_frontend` - Dockerfile for the frontend installs Node, the React frontend, and NGINX, and starts the NGINX server.
6. `flask_config.toml` - the configuration file for the ASReview application. Contains the necessary email configuration parameters to link the application to the Sendgrid Relay Service.
7. `wsgi.py` - a tiny Python file that serves the backend with Gunicorn.

### SendGrid

If you would like to use or try out [SendGrid](https://sendgrid.com/), go to their website, create an account, and sign in. Once signed in, click on "Email API" in the menu and subsequently click on the "Integration Guide" link. Then, choose "SMTP Relay", create an API key and copy the resulting settings (Server, Ports, Username and Password) in your `flask_config.toml` file. It's important to continue checking the "I've updated my settings" checkbox when it's visible __and__ click on the "Next: verify Integration" button before you build the Docker containers.

### Parameters in the .env file

The .env file contains all the necessary parameters to deploy all containers. All variables that end with the `_PORT` suffix refer to the containers' internal and external network ports. The prefix of these variables explains for which container they are used. Note that the external port of the frontend container, the container that will be directly used by the end-user, is 8080 and not 80. Change this to 80 if you don't want to use port numbers in the URL of the ASReview web application.

The `FLASK_MAIL_PASSWORD` refers to the password provided by the SendGrid Relay service, and the value of the `WORKERS` parameter determines how many instances of the ASReview app Gunicorn will start. Currently, the app works best with a single worker.

Variables prefixed with `POSTGRES` are intended for use with the PostgreSQL database. The `_USER` and `_PASSWORD` variables are self-explanatory, representing the database user and password, respectively. The `_DB` variable specifies the database name.

Please be aware that the provided password is quite weak. If deploying Docker containers in a public environment, it is advisable to modify the database user to something less predictable and strengthen the password for enhanced security.

### Creating and running the containers

From the __root__ folder of the app execute the `docker compose` command to start your docker containers in attached mode:

```
$ docker compose -f ./docker-compose.yml up --build
```

### Short explanation of the docker-compose workflow

Building the database container is straightforward; there is no Dockerfile involved. The container spins up a PostgreSQL database, protected by the username and password values in the `.env` file. The backend container depends on the database container to ensure the backend can only start when the database exists.

The frontend container uses a multi-stage Dockerfile. The first phase builds the React frontend and copies it to the second phase, which deploys a simple NGINX container. The `asreview.conf` file is used to configure NGINX to serve the frontend.

The backend container is more complicated. It also uses a multi-stage Dockerfile. In the first stage, all necessary Python/PostgreSQL-related software is installed, and the app is built. The app is copied into the second stage. During the second stage the `flask_config.toml` file is copied into the container and all missing parameters (database-uri and email password) are adjusted according to the values in the `.env` file. The path of this Flask configuration file will be communicated to the Flask app by an environment variable.\
Then a Gunicorn config file (`gunicorn.conf.py`) is created on the fly which sets the server port and the preferred amount of workers. After that, a second file is created: an executable shell script instructing the ASReview app to create the necessary tables in the database and start the Gunicorn server using the configuration described in the previous file.

Note that a user of this recipe only has to change the necessary values in the `.env` file and execute the `docker compose` command to spin up an ASReview service, without an encrypted HTTP protocol!

### Deploying on Digital Ocean

The following section describes how to deploy the authenticated application with verification on [Digital Ocean](https://www.digitalocean.com/). During the process a number of gotchas and solutions are explained. The deployment is done on a bare Droplet running Ubuntu 22.04 with 1 CPU, 2 GB memory and a 50 GB SSD disk. Root access is assumed.

First consideration is a (sub)domain name. If you have one, make sure the domain name points to the IP address of the Droplet.

Ssh into your Droplet, update the list of packages and install the software for Docker:
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
and enter 'Y'. If you get questions about restarting services just select OK. Verify if all is up and running by creating a test container:
```
$ sudo docker run hello-world
```
If all is well a message 'Hello from Docker' should appear with other information. Verify if Docker Compose is installed:
```
$ docker compose version
```
If this fails, install Docker Compose with:
```
$ sudo apt-get install docker-compose-plugin
```
Next up are ports. It's best practice to engage the firewall and open the ports we need. In this manual the frontend will run on port 8080 (deviating from the normal port 80), and the backend runs on 8081.
```
$ sudo ufw default allow outgoing
$ sudo ufw default deny incoming
$ sudo ufw allow ssh
$ sudo ufw allow 8080
$ sudo ufw allow 8081
$ sudo ufw enable
```
Clone the ASReview application in the root folder and ensure all tags are present:
```
$ cd
$ git clone https://github.com/asreview/asreview.git
$ cd asreview
$ git tag -l
```
Clone the ASReview Server Stack extension in the `asreview` folder: 
```
$ git clone https://github.com/asreview/asreview-server-stack.git
```
Next up is configuring the `.env` file in `~/asreview/asreview-server-stack`.




