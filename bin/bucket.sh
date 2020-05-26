#!/bin/bash

. ./stack_commons.sh

FILES_DIR=../media_files
BUCKET_NAME=



aws s3 sync $FILES_DIR s3://$BUCKET_NAME --acl public-read