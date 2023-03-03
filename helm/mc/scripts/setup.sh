#!/bin/bash

set -e

mc alias set ma http://ma-minio:9000 admin Passw0rd
mc alias set mb http://mb-minio:9000 admin Passw0rd
mc mb ma/bucket001
mc mb ma/bucket002
mc mb ma/bucket003
mc mb ma/bucket004
mc mb ma/bucket005
mc mb ma/bucket006
mc mb ma/bucket007
mc mb ma/bucket008
mc mb ma/bucket009
mc mb ma/bucket010
mc mb ma/bucket011
mc mb ma/bucket012

i=0
while [ $i -ne 10000 ]
do
    echo testing $i > /tmp/test$i.txt
    i=$(($i+1))
done

mc mirror /tmp/ ma/bucket002/

mc admin replicate add ma mb &
DELETING=true
while $DELETING;
do
    mc admin bucket remote rm ma/bucket002 --arn $(mc admin bucket remote ls ma/bucket002 | grep arn | tr -s ' ' | cut -d' ' -f3) && DELETING=false || DELETING=true
done
mc admin service restart ma

i=0
while [ $i -ne 1000 ]
do
    echo testing $i > /tmp/new$i.txt
    i=$(($i+1))
done
