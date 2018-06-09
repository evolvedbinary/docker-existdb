FROM openjdk:8-jdk-alpine as builder

# arguments can be referenced at build time chose master for the stable release channel
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
        && bash ./build.sh --minimal ${BRANCH} \
        && rm -rf tmp \
        && apk del .build-deps

FROM openjdk:8-jdk-slim as jdk
# Remove assistive_technologies capabilities from jdk (see below)
RUN sed -i "s|^assistive_technologies|#assistive_technologies|" /etc/java-8-openjdk/accessibility.properties

FROM gcr.io/distroless/java:latest

ARG CACHE_MEM
ARG MAX_BROKER

# Build-time metadata as defined at http://label-schema.org
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION="5.0.0-SNAPSHOT"

LABEL org.label-schema.build-date=${BUILD_DATE} \
      org.label-schema.name="exist-docker" \
      org.label-schema.description="minimal exist-db docker image with FO support" \
      org.label-schema.url="https://exist-db.org" \
      org.label-schema.vcs-ref=${VCS_REF} \
      org.label-schema.vcs-url="https://github.com/duncdrum/exist-docker" \
      org.label-schema.vendor="exist-db" \
      org.label-schema.version=$VERSION \
      org.label-schema.schema-version="1.0"


# ENV for gcr
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64
ENV EXIST_HOME /exist
ENV DATA_DIR /exist-data

# VOLUME ${DATA_DIR}

# Copy over dependancies for Apache FOP, missing from gcr's JRE
# Make sure JDK and gcr have matching java versions
COPY --from=jdk /usr/lib/jvm/java-1.8.0-openjdk-amd64/jre/lib/amd64/libfontmanager.so /usr/lib/jvm/java-8-openjdk-amd64/jre/lib/amd64/
COPY --from=jdk /usr/lib/jvm/java-1.8.0-openjdk-amd64/jre/lib/amd64/libjavalcms.so /usr/lib/jvm/java-8-openjdk-amd64/jre/lib/amd64/
COPY --from=jdk /usr/lib/x86_64-linux-gnu/liblcms2.so.2.0.8 /usr/lib/x86_64-linux-gnu/liblcms2.so.2
COPY --from=jdk /usr/lib/x86_64-linux-gnu/libfreetype.so.6.12.3 /usr/lib/x86_64-linux-gnu/libfreetype.so.6
COPY --from=jdk /usr/lib/x86_64-linux-gnu/libpng16.so.16.28.0 /usr/lib/x86_64-linux-gnu/libpng16.so.16

# Copy dependancies for Apache Batik (used by Apache FOP to handle SVG rendering)
COPY --from=jdk /usr/lib/x86_64-linux-gnu/libfontconfig.so.1.8.0 /usr/lib/x86_64-linux-gnu/libfontconfig.so.1
COPY --from=jdk /usr/share/fontconfig /usr/share/fontconfig
COPY --from=jdk /usr/share/fonts/truetype/dejavu /usr/share/fonts/truetype/dejavu
COPY --from=jdk /lib/x86_64-linux-gnu/libexpat.so.1 /lib/x86_64-linux-gnu/libexpat.so.1
COPY --from=jdk /etc/fonts /etc/fonts

# Copy previously removed accessibility.properties from JDK, or it will throw errors in SVG processing
COPY --from=jdk /etc/java-8-openjdk/accessibility.properties /etc/java-8-openjdk/accessibility.properties

WORKDIR ${EXIST_HOME}


# Copy compiled exist-db files
COPY --from=builder /target/exist-minimal .
COPY --from=builder /target/conf.xml ./conf.xml
COPY --from=builder /target/exist/webapp/WEB-INF/data ${DATA_DIR}

# Optionally add customised configuration files
# ADD ./src/conf.xml .
ADD ./src/log4j2.xml .
# ADD ./src/mime-types.xml .
# ADD ./src/exist-webapp-context.xml ./tools/jetty/webapps/
# ADD ./src/controller-config.xml ./webapp/WEB-INF/controller-config.xml

# Configure JVM for us in container (here there be dragons)
ENV JAVA_TOOL_OPTIONS -XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap -XX:MaxRAMFraction=1 -XX:+UseG1GC -XX:+UseStringDeduplication -Dfile.encoding=UTF8 -Djava.awt.headless=true -Dorg.exist.db-connection.cacheSize=${CACHE_MEM:-256}M -Dorg.exist.db-connection.pool.max=${MAX_BROKER:-20}

# Port configuration
EXPOSE 8080 8443

HEALTHCHECK CMD [ "java", "-jar", "start.jar", "client", "--no-gui",  "--xpath", "system:get-version()" ]

ENTRYPOINT [ "java", "-jar", "start.jar", "jetty" ]
