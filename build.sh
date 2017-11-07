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
EXIST_MODS="${TARGET}"

# Extract arguments
EXPERIMENTAL=YES		# YES to use Docker experimental features, NO otherwise
for i in "$@"
do
case $i in
    -n|--no-experimental)
    EXPERIMENTAL=NO
    shift # past argument with no value
    ;;
    *)
            # unknown option
    ;;
esac
done
BRANCH_NAME="${1}"

CONTAINER_EXIST_PATH=/exist
CONTAINER_EXIST_DATA_PATH=/exist-data

if [ -z ${BRANCH_NAME} ]
then
	echo "You must specify a branch to build!"
	echo "Useage: ./build.sh <branch>"
	exit 1
fi
command -v git >/dev/null 2>&1 || { echo "An installation of Git client is required, but could not be found...  Aborting." >&2; exit 2; }
command -v java >/dev/null 2>&1 || { echo "An installation of Java 8 is required, but could not be found...  Aborting." >&2; exit 3; }
command -v augtool >/dev/null 2>&1 || { echo "An installation of Augeas (augtool) is required, but could not be found...  Aborting." >&2; exit 4; }

mkdir -p "${TARGET}"

# Either get or update from GitHub eXist-db
if [ ! -d "$EXIST_CLONE" ]
then
	git clone https://github.com/exist-db/exist.git "${EXIST_CLONE}"
	cd "${EXIST_CLONE}"
	git checkout "${BRANCH_NAME}"
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

# Build/Rebuild eXist-db
./build.sh clean && ./build.sh

# Back to the root
cd "${SCRIPT_PATH}"

# Create the updated conf.xml
if [ ! -d "$EXIST_MODS" ]
then
	mkdir "${EXIST_MODS}"
fi
UPDATED_CONF="${EXIST_MODS}/conf.xml"
cp "${EXIST_CLONE}/conf.xml" "${UPDATED_CONF}"

cat << EOF | augtool --noload --noautoload
set /augeas/load/xml/lens "Xml.lns"
set /augeas/load/xml/incl "${UPDATED_CONF}"
load
context /files/$UPDATED_CONF
set exist/db-connection/#attribute/files $CONTAINER_EXIST_DATA_PATH
set exist/db-connection/recovery/#attribute/journal-dir $CONTAINER_EXIST_DATA_PATH
save
EOF

# Build Docker image
EXPERIMENTAL_ARGS=""
if [ "$EXPERIMENTAL" == "YES" ]
then
	EXPERIMENTAL_ARGS="--squash"
fi

docker build \
  --build-arg VCS_REF=`git rev-parse --short HEAD` \
  --build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
  --rm --force-rm $EXPERIMENTAL_ARGS -t "evolvedbinary/exist-db:${BRANCH_NAME}" .

