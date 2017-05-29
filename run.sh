#!/bin/bash

if [ "$#" -ne 1 ]
then
  echo "Usage: run.sh /path/to/data/"
  exit 1
fi

docker run -it --rm --name pgsql_mbox_download -v "$1":/data -e DATA_DIR=/data pgsql_mbox_download
