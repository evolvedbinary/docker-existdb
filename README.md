# eXist-db Docker Image Builder

[![Build Status](https://travis-ci.org/evolvedbinary/docker-existdb.svg?branch=master)](https://travis-ci.org/evolvedbinary/docker-existdb)
[![](https://images.microbadger.com/badges/version/evolvedbinary/exist-db.svg)](https://microbadger.com/images/evolvedbinary/exist-db "Get your own version badge on microbadger.com")
[![](https://images.microbadger.com/badges/image/evolvedbinary/exist-db.svg)](https://microbadger.com/images/evolvedbinary/exist-db "Get your own image badge on microbadger.com")

This repository contains the build files for creating [eXist-db](https://www.exist-db.org) [Docker](https://docker.com) images.

## Requirements

1. [Docker Toolbox](https://www.docker.com/products/docker-toolbox)
2. [Git](https://git-scm.com/download)
3. [Java 8](http://www.oracle.com/technetwork/java/javase/downloads/index.html)
4. [Augeas](http://augeas.net/) (Mac users: `brew install augeas`)

## Building a Docker Image

Pre-built [eXist-db Docker images](http://docker.io/evolvedbinary/exist-db) have been published on Docker Hub. You can skip to [Running an eXist-db Docker Image](#running) if you just want to use the provided Docker images.

You can use the `./build.sh` script which will clone or update eXist-db from GitHub into the subfolder `target/exist`. You must specify either the branch or tag that you wish to build the Docker image for. Example usage:

```bash
$ git clone https://github.com/evolvedbinary/docker-existdb.git

$ cd docker-existdb
$ ./build.sh eXist-3.5.0
```

## Running an eXist-db Docker Image

<a name="running"/>
eXist-db inside the Docker container is listening on TCP ports `8080` for HTTP and `8443` for HTTPS. To access these you have to map them to ports of your choosing on your host machine. For example if we wanted to interactively run an eXist-db Docker container and map the ports to `9080` and `9443` on your host system, you would run the following:


```bash
$ docker run -it -p 9080:8080 -p 9443:8443 evolvedbinary/exist-db:eXist-3.5.0
```

You can now connect to the eXist-db running inside the Docker container from your host machine using ports `9080` and `9443`.

To shutdown the eXist-db server running in the Docker container, you can either: 

1. Simply press `Ctrl-C` in the interactive terminal hosting the Docker container.
2. Run `$ docker stop <container name>`. You can get the "container name" by running `$ docker ps` and examining the "NAMES" column of the output. 

### Using local storage for eXist-db data

You can also run a Docker container that uses a non-container filesystem for storage. One of the options is to use a folder on the host machine to hold the eXist-db data directory.
This can be useful if you need to share data between the Container and the Host. *WARNING:* you should never write or read to the host folder whilst the container is running, otherwise you risk corrupting your eXist-db database.

For example is you wanted to keep eXist-db's data in the host folder `/Users/bob/docker-exist-data/01` you would launch a container using something like:

```bash
$ docker run -it -p 9080:8080 -p 9443:8443 --volume /Users/bob/docker-exist-data/01:/exist-data evolvedbinary/exist-db:eXist-3.5.0
```

*NOTE:* This approach adds further overhead to I/O performance.


