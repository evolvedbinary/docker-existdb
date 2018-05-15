# docker-eXist (WIP)
minimal exist-db docker image with FO support

[![Build Status](https://travis-ci.org/duncdrum/exist-docker.svg?branch=master)](https://travis-ci.org/duncdrum/exist-docker)
[![](https://images.microbadger.com/badges/image/duncdrum/exist-docker.svg)](https://microbadger.com/images/duncdrum/exist-docker "Get your own image badge on microbadger.com")
[![](https://images.microbadger.com/badges/version/duncdrum/exist-docker.svg)](https://microbadger.com/images/duncdrum/exist-docker "Get your own version badge on microbadger.com")

This repository holds the source files for building a minimal docker image of the [exist-db](https://www.exist-db.org) xml database, automatically building from eXist's source code repo. It uses Google Cloud Platforms ["Distroless" Docker Images](https://github.com/GoogleCloudPlatform/distroless).


## Requirements
*   [Docker](https://www.docker.com): `18-stable`

## How to use
Pre-build images are available on [DockerHub](https://hub.docker.com/r/duncdrum/exist-docker/). There are two channels:
*   `stable` for the latest stable releases (coming soon™)
*   `latest` for last commit to the development branch.

To download the image run:
```bash
docker pull duncdrum/exist-docker:latest
docker run -it -d -p 8080:8080 -p 8443:8443 duncdrum/exist-docker:latest
```

You can now access eXist via [localhost:8080](localhost:8080) in your browser.
Try to stick with matching internal and external port assignments, to avoid unnecessary reloads and connection issues.

To stop the container issue:
```bash
docker stop exist
```

or if you omitted the `-d` flag earlier press `CTRL-C` inside the terminal showing the exist logs.

### Interacting with the running container
Containers build from this image run a periodical healtheck to make sure that eXist is operating normally. If `docker ps` reports `unhealthy` you can see a more detailed report  (where `exist` is the name of the container)
```bash
docker inspect --format='{{json .State.Health}}' exist
```

### Logging
There is a slight modification to eXist's logger to ease access to the logs via:
```bash
docker logs exist
```
This works best when providing the `-t` flag when running an image.

### Development use via `docker-compose`
Use of [docker compose](https://docs.docker.com/compose/) for local development or integration into a multi-container environment is strongly recommended.
```bash
# starting eXist
docker-compose up -d
# stop eXist
docker-compose down
```

Docker compose defines a data volume for eXist named `exist-data` so that changes to the container's apps persist through reboots. You can inspect the volume via:
```bash
docker volume inspect exist-data
```

You can configure additional volumes e.g. for backups, or additional services such as an nginx reverse proxy by modifying the `docker-compose.yml`, to suite your needs.

To update the exist-docker image from a newer version
```bash
docker-compose pull
```

### Caveat
As with normal installations, the password for the default dba user `admin` is empty. Change it via the [usermanager](http://localhost:8080/exist/apps/usermanager/index.html) or set the password to e.g. `123` from docker CLI:
```bash
docker exec exist java -jar start.jar client -q -u admin -P '' -x 'sm:passwd("admin", "123")'
```
Note: `123` is not a good password.

## Building the Image
To build the docker image run:
```bash
docker build .
```

This will build an eXist image with sensible defaults as specified in the Dockerfile. The image uses a multi-stage building approach, so you can customize the compilation of eXist, or the final image.

To interact with the compilation of eXist you can either modify the `build.sh` file directly, or if you prefer to work via docker stop the build process after the builder stage, via

```bash
docker build --target builder .
# Do your thing…
docker commit…
```

### Available Arguments and Defaults
eXist's cache size and maximum brokers can be configured at built time using the following syntax.
```bash
docker build --build-arg MAX_CACHE=312 MAX_BROKER=15 .
```

NOTE: Do to the fact that the final images does not provide a shell setting ENV variables for eXist has no effect.
```bash
# !This has no effect!
docker run -it -d -p8080:8080 -e MAX_BROKER=10 ae4d6d653d30
```

The preferred method to change your images to a customized cache or broker configuration is to edit the default values inside the Dockerfile used for building your images.

```bash
ARG MAX_BROKER=10
```

Alternatively you can edit, the configuration files in the `/src` folder to customize the eXist instance. Make your customizations and uncomment the following lines in the Dockerfile.
```bash
# Add customized configuration files
# ADD ./src/conf.xml .
# ADD ./src/log4j2.xml .
# ADD ./src/mime-types.xml .
```

These files only serve as a template. While upstream updates from eXist to them are rare, such upstream changes will be immediately mirrored here. Users are responsible to ensure that local changes in their forks / clones persist when syncing with this repo, e.g. by rebasing their own changes after pulling from upstream.

#### JVM configuration
This image uses advanced JVM configuration to set set the heap-size. Avoid passing `-Xmx` arguments to eXist's JVM to set maximum memory. This will lead to frequent crashes since java and Docker are not on the same page concerning available memory. Only use `-XX:MaxRAMFraction=1` to modify the memory available to the JVM. For production use it is recommended to increase the value to `2` or even `4`. The values express ratios, so setting it to `2` means half the container's memory will be available to the JVM, '4' means ¼,  etc.

To allocate e.g. 600mb to the container around the JVM use:
```bash
docker run -m 600m …
```

### Interacting with image via CLI
You can now interact with a running container as if it were a regular linux host, the name of the container in these examples is `exist`:

```bash
# Copy my-data.xml from running eXist to local folder
docker cp exist:/exist-data/apps/my-app/data/my-data.xml ./my-folder

# Using java syntax on a running eXist instances
docker exec exist java -jar start.jar client --no-gui --xpath "system:get-memory-max()"

# Interacting with the JVM
docker exec exist java -version
```
