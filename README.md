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
*   `stable` for the latest stable releases (recommended for production)
*   `latest` for last commit to the development branch.

To download the image run:
```bash
docker pull duncdrum/exist-docker:latest
docker run -it -d -p 8080:8080 -p 8443:8443 duncdrum/exist-docker:latest
```

You can now access exist via [localhost:8080](localhost:8080) in your browser.
Try to stick with matching internal and external port assignments, to avoid unnecessary reloads and connection issues.

To stop the container issue:
```bash
docker stop exist
```

or if you omitted the `-d` flag earlier press `CTRL-C` inside the terminal showing the exist logs.

### Interacting with the running container


### Logging
There os a slight modification to eXist's logger to ease access to the logs.
```bash
docker logs exist
```

### Development use via `docker-compose`
Use of [docker compose](https://docs.docker.com/compose/) for local development or integration into a multi-container environment is strongly recommended.
```bash
# starting eXist
docker-compose up -d
# stop eXist
docker-compose down
```

Docker compose defines a data volume for eXist named `exist-data` so that changes to apps persist through reboots. You can inspect the volume via:
```bash
docker volume inspect exist-data
```

### Caveat
As with normal installations, the password for the default dba user `admin` is empty. Change it via the [usermanager](http://localhost:8080/exist/apps/usermanager/index.html) or set the password to e.g. `fancy-password` from docker CLI:
```bash
docker exec exist java -jar start.jar client -q -u admin -P admin -x \
 'sm:passwd("admin", "fancy-password")'
```


## Contributing and Modifying the Image
This image uses a multi-stage build approach, so you can customize the compilation of eXist, or the final image.

Do build the docker image run:
```bash
docker build .
```

### Available Arguments and Defaults
(WIP)

### Customizing the compilation of eXist
To interact with the compilation of exist you can modify the `build.sh` file directly, or if you prefer to work via docker stop the build process after the builder stage. The build file is currently processed by aureas

```bash
docker build --target builder .
```

You can now interact with the build as if it were a regular linux host, e.g.:

```bash
docker cp container_name:/target/conf.xml ./src
```

### Customizing the final image
If you wish to add additional volumes or want to configure the memory allocation of the final image you can either edit the `Dockerfile` or `docker-compose.yml` to suite your needs.

You can also provide memory arguments to the docker run and build commands directly, eg.

```bash
docker run -it -d -e MAX_MEM=768 exist
```
configures exist to run with a heapsize of 768m. This can be helpful for using exist on small instances such as AWS micro instances.

Since the distroless images does not provide a shell, the configuration files in the `/src` folder are there to simplify the configuration customization of your eXist instance. Make your customizations and uncomment the following lines in the Dockerfile.
```bash
# Add customized configuration files
# ADD ./src/conf.xml .
# ADD ./src/log4j2.xml .
# ADD ./src/mime-types.xml .
```

These configuration files are supposed to serve as a template. While upstream updates from eXist are rare, they will be immediately mirrored here. Users are responsible to ensure that local changes in their forks / clones persist when syncing with this repo, e.g. by rebasing their own changes after pulling from upstream.
