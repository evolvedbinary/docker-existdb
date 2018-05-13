FROM openjdk:8-jdk-alpine as builder

# Build-time metadata as defined at http://label-schema.org
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

LABEL name="minimal exist-db docker image with FO support" \
      vendor="exist-db.org" \
      maintainer="Duncan Paterson" \
      org.label-schema.url="https://exist-db.org" \
      org.label-schema.build-date="$BUILD_DATE" \
      org.label-schema.vcs-ref="$(git rev-parse --short HEAD)" \
      org.label-schema.vcs-url="https://github.com/duncdrum/exist-docker" \
      org.label-schema.schema-version="1.0"

# arguments can be referenced at build time
ARG BRANCH=develop

# ENV for builder
ENV BRANCH ${BRANCH}
ENV INSTALL_PATH /target

# Install tools required to build the project

RUN mkdir -p ${INSTALL_PATH}
WORKDIR ${INSTALL_PATH}
COPY build.sh build.sh

RUN apk add --no-cache --virtual .build-deps \
        augeas \
        bash \
        curl \
        git \
        ttf-dejavu \
        && bash ./build.sh --minimal ${BRANCH} \
        && rm -rf tmp \
        && apk del .build-deps


FROM gcr.io/distroless/java:latest

ARG MAX_MEM
ARG CACHE_MEM
ARG MAX_BROKER

# Adjust as necessary via run or build

ENV CACHE_MEM -Dorg.exist.db-connection.cacheSize=${CACHE_MEM:-256}M
ENV MAX_MEM -Xmx${MAX_MEM:-1856}M
ENV MAX_BROKER -Dorg.exist.db-connection.pool.max=${MAX_BROKER:-20}

# ENV for gcr
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64
ENV EXIST_HOME /exist
ENV DATA_DIR /exist-data

# VOLUME ${DATA_DIR}

WORKDIR ${EXIST_HOME}

# Add customized configuration files
# ADD ./src/conf.xml .
ADD ./src/log4j2.xml .
# ADD ./src/mime-types.xml .

# Copy compiled exist-db files
COPY --from=builder /target/exist-minimal .
COPY --from=builder /target/conf.xml ./conf.xml
COPY --from=builder /target/exist/webapp/WEB-INF/data ${DATA_DIR}

# Copy over dependancies for Apache FOP, which are lacking from gcr image

COPY --from=builder /usr/lib/jvm/java-1.8-openjdk/jre/lib/amd64/libfontmanager.so /usr/lib/jvm/java-8-openjdk-amd64/jre/lib/amd64/
COPY --from=builder /usr/lib/jvm/java-1.8-openjdk/jre/lib/amd64/libjavalcms.so /usr/lib/jvm/java-8-openjdk-amd64/jre/lib/amd64/
COPY --from=builder /usr/lib/liblcms2.so.2.0.8 /usr/lib/x86_64-linux-gnu/liblcms2.so.2
COPY --from=builder /usr/lib/libpng16.so.16.34.0 /usr/lib/x86_64-linux-gnu/libpng16.so.16
COPY --from=builder /usr/lib/libfreetype.so.6.15.0 /usr/lib/x86_64-linux-gnu/libfreetype.so.6

# does not seem to stick
ENV LANG C.UTF-8

# Port configuration
EXPOSE 8080
EXPOSE 8443

HEALTHCHECK CMD ["java", "-jar", "start.jar", "client", "--no-gui",  "--xpath", "system:get-version()"]

ENTRYPOINT ["java", "-Djava.awt.headless=true", "-jar", "start.jar", "jetty"]
CMD ["${CACHE_MEM}", "${MAX_BROKER}", "${MAX_MEM}"]
