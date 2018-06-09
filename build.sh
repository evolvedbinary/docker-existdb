#!/bin/bash

: '
eXist-db Docker Image builder
Copyright (C) 2017 Evolved Binary Ltd

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
'

set -e
# set -x

SCRIPT_PATH="$( cd "$(dirname "$0")" ; pwd -P )"

TARGET="${SCRIPT_PATH}/target"
EXIST_CLONE="${TARGET}/exist"
EXIST_MINIMAL="${TARGET}/exist-minimal"
EXIST_MODS="${TARGET}"

##
# Shows the usage message and exits
##
exit_with_usage() {
	echo "Usage: ./build.sh [options] <branch>"
	echo ""
	echo "--no-experimental         Don't use experimental Docker features"
	echo "--minimal                 Create a minimal eXist-db server Docker image"
	echo "--no-recompile			Only perform docker build without rebuilding eXist-db"
	echo "--config <conf.xml>		Supply custom conf.xml"
	echo ""
	exit 1
}

##
# Given a built eXist-db Git clone, outputs the minimum needed to run eXist-db server
#
# @param $1 path to eXist-db clone folder
# @param $2 path to output folder
##
minify_exist() {
	EXIST_CLONE="${1}"
	EXIST_MINIMAL="${2}"

	copy_extension_libs() {
		EXTENSION_NAME="${1}"
		mkdir -p "${EXIST_MINIMAL}/extensions/${EXTENSION_NAME}"
		cp -r "${EXIST_CLONE}/extensions/${EXTENSION_NAME}/lib" "${EXIST_MINIMAL}/extensions/${EXTENSION_NAME}"
	}

	if [ ! -d "$EXIST_MINIMAL" ]
	then
		mkdir -p "${EXIST_MINIMAL}"
	else
		# make sure we start with a clean build
		rm -rf "${EXIST_MINIMAL}/*"
	fi

	# copy sundries
	cp "${EXIST_CLONE}/LICENSE" "${EXIST_CLONE}/README.md" "${EXIST_MINIMAL}"

	# copy base folders
	cp -r "${EXIST_CLONE}/autodeploy" "${EXIST_CLONE}/bin" "${EXIST_MINIMAL}"

	# copy base libs
	cp "${EXIST_CLONE}/start.jar" "${EXIST_CLONE}/exist.jar" "${EXIST_CLONE}/exist-optional.jar" "${EXIST_MINIMAL}"
	mkdir -p "${EXIST_MINIMAL}/lib"
	cp -r "${EXIST_CLONE}/lib/core" "${EXIST_CLONE}/lib/endorsed" "${EXIST_CLONE}/lib/optional" "${EXIST_CLONE}/lib/extensions" "${EXIST_CLONE}/lib/user" "${EXIST_CLONE}/lib/test" "${EXIST_MINIMAL}/lib"

	# copy config files
	cp "${EXIST_CLONE}/descriptor.xml" "${EXIST_CLONE}/log4j2.xml" "${EXIST_CLONE}/mime-types.xml" "${EXIST_MINIMAL}"

	# copy tools
	mkdir -p "${EXIST_MINIMAL}/tools"
	cp -r "${EXIST_CLONE}/tools/ant" "${EXIST_CLONE}/tools/aspectj" "${EXIST_CLONE}/tools/jetty" "${EXIST_MINIMAL}/tools"
	
	# copy webapp
	mkdir -p "${EXIST_MINIMAL}/webapp/WEB-INF"
	cp -r "${EXIST_CLONE}/webapp/404.html" "${EXIST_CLONE}/webapp/controller.xql" "${EXIST_CLONE}/webapp/logo.jpg" "${EXIST_CLONE}/webapp/resources" "${EXIST_MINIMAL}/webapp"
	cp -r "${EXIST_CLONE}/webapp/WEB-INF/betterform-version.info" "${EXIST_CLONE}/webapp/WEB-INF/catalog.xml" "${EXIST_CLONE}/webapp/WEB-INF/controller-config.xml" "${EXIST_CLONE}/webapp/WEB-INF/entities" "${EXIST_CLONE}/webapp/WEB-INF/web.xml" "${EXIST_MINIMAL}/webapp/WEB-INF"

	# copy extension libs
	copy_extension_libs modules
	copy_extension_libs betterform/main
	copy_extension_libs contentextraction
	copy_extension_libs webdav
	copy_extension_libs xprocxq/main
	copy_extension_libs xqdoc
	copy_extension_libs expath
	copy_extension_libs exquery
	copy_extension_libs exquery/restxq
	copy_extension_libs indexes/lucene
}

# Extract arguments
EXPERIMENTAL=YES          # YES to use Docker experimental features, NO otherwise
MINIMAL=NO                # YES to create a minimal eXist-db server Docker image,$ NO for a full image
SHOW_USAGE=NO             # YES to show the usage message, NO otherwise
NORECOMPILE=NO            # YES to only run docker build without building exist-db again
DOCKERFILE="Dockerfile"

for i in "$@"
do
case $i in
    -n|--no-experimental)
    EXPERIMENTAL=NO
	shift
    ;;
    -m|--minimal)
    MINIMAL=YES
	shift
    ;;
    -nr|--no-recompile)
    NORECOMPILE=YES
	shift
    ;;
    -c|--config)
	CUSTOM_CONF="$1";
        shift
    ;;
    -h|--help)
    SHOW_USAGE=YES
	shift
    ;;
    *)
            # unknown option
    ;;
esac
done

if [ "$MINIMAL" == "YES" ]; then SUFFIX="$SUFFIX-minimal"; fi
DOCKERFILE="${DOCKERFILE}${SUFFIX}"
BRANCH_NAME="${1}"

CONTAINER_EXIST_PATH=/exist
CONTAINER_EXIST_DATA_PATH=/exist-data

if [ "$SHOW_USAGE" == "YES" ]
then
	exit_with_usage
fi

if [ -z ${BRANCH_NAME} ]
then
	echo "You must specify a branch to build!"
	echo ""
	exit_with_usage
fi

if [ ! "$NORECOMPILE" == "YES" ]
then
	command -v git >/dev/null 2>&1 || { echo "An installation of Git client is required, but could not be found...  Aborting." >&2; exit 2; }
	command -v java >/dev/null 2>&1 || { echo "An installation of Java 8 is required, but could not be found...  Aborting." >&2; exit 3; }
	if [ ! -f "${CUSTOM_CONF}" ]
	then
		command -v augtool >/dev/null 2>&1 || { echo "An installation of Augeas (augtool) is required, but could not be found...  Aborting." >&2; exit 4; }
	fi
fi

if [ ! -d "$TARGET" ]
then
  mkdir -p "${TARGET}"
fi


# Either get or update from GitHub eXist-db
if [ ! -d "$EXIST_CLONE" ]
then
	NORECOMPILE=NO
	git clone https://github.com/exist-db/exist.git "${EXIST_CLONE}"
	cd "${EXIST_CLONE}"
	git checkout "${BRANCH_NAME}"
else
	if [ "$NORECOMPILE" == "YES" ]
	then
	  echo "Not re-building eXist-db, --docker-only option selected"
	else
  		cd "${EXIST_CLONE}"
		git fetch origin
		git checkout "${BRANCH_NAME}"
		if git describe --exact-match --tags HEAD > /dev/null
		then
			# this is a tag, don't need to rebase (update)
			echo "On tag: ${BRANCH_NAME}"
		else
			# this is a branch, rebase to make sure we are up to date
			git rebase "origin/${BRANCH_NAME}"
			echo "Updated branch: ${BRANCH_NAME}"
		fi
	fi
fi

if [ "$NORECOMPILE" != "YES" ]
then
	# Build/Rebuild eXist-db
	cd "${EXIST_CLONE}"
	EXIST_HOME="${EXIST_CLONE}" ./build.sh clean && EXIST_HOME="${EXIST_CLONE}" ./build.sh
fi

# Back to the root
cd "${SCRIPT_PATH}"

# Create the updated conf.xml
if [ ! -d "$EXIST_MODS" ]
then
	mkdir "${EXIST_MODS}"
fi

UPDATED_CONF="${EXIST_MODS}/conf.xml"
if [ -f "$CUSTOM_CONF" ]
then
	cp "${CUSTOM_CONF}" "${UPDATED_CONF}"
else
	cp "${EXIST_CLONE}/conf.xml" "${UPDATED_CONF}"

	cat << EOF | augtool --noload --noautoload
set /augeas/load/xml/lens "Xml.lns"
set /augeas/load/xml/incl "${UPDATED_CONF}"
load
set /files/$UPDATED_CONF/exist/db-connection/#attribute/files $CONTAINER_EXIST_DATA_PATH
set /files/$UPDATED_CONF/exist/db-connection/recovery/#attribute/journal-dir $CONTAINER_EXIST_DATA_PATH
save
EOF

fi

# should we minify the eXist-db we put into the Docker Image?
if [ "$MINIMAL" == "YES" ]
then
	echo "Minifying to $EXIST_MINIMAL"
	minify_exist "$EXIST_CLONE" "$EXIST_MINIMAL"
fi

# Build Docker image
EXPERIMENTAL_ARGS=""
if [ "$EXPERIMENTAL" == "YES" ]
then
	EXPERIMENTAL_ARGS="--squash"
fi

BRANCH_NAME="${BRANCH_NAME}${SUFFIX}"

if [ ! -f "$DOCKERFILE" ]
then
	echo "A Dockerfile for this combination of options does not exist. $DOCKERFILE does not exist."
else
	docker build \
	  --build-arg VCS_REF=`git rev-parse --short HEAD` \
	  --build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
	  --rm --force-rm $EXPERIMENTAL_ARGS -t "evolvedbinary/exist-db:${BRANCH_NAME}" --file "${DOCKERFILE}" . 1> build.log 2> errors.log
fi
