#!/bin/bash

set -e

mc alias set ma http://ma-minio:9000 admin Passw0rd
mc alias set ma0 http://ma-minio-0.ma-minio-svc:9000 admin Passw0rd
mc alias set ma1 http://ma-minio-1.ma-minio-svc:9000 admin Passw0rd
mc alias set mb http://mb-minio:9000 admin Passw0rd
mc alias set mb0 http://mb-minio-0.mb-minio-svc:9000 admin Passw0rd
mc alias set mb1 http://mb-minio-0.mb-minio-svc:9000 admin Passw0rd
mc mb ma0/bucket001
mc mb ma0/bucket002
mc mb ma0/bucket003
mc mb ma0/bucket004
mc mb ma0/bucket005
mc mb ma0/bucket006
mc mb ma0/bucket007
mc mb ma0/bucket008
mc mb ma0/bucket009
mc mb ma0/bucket010
mc mb ma0/bucket011
mc mb ma0/bucket012

i=0
while [ $i -ne 10000 ]
do
    echo testing $i > /tmp/test$i.txt
    i=$(($i+1))
done

mc mirror /tmp/ ma/bucket002/ || true

mc admin replicate add ma0/ mb0/ &
DELETING=true
while $DELETING;
do
    mc admin bucket remote rm ma0/bucket002 --arn $(mc admin bucket remote ls ma0/bucket002 | grep arn | tr -s ' ' | cut -d' ' -f3) && DELETING=false || DELETING=true
done
i=0
while [ $i -ne 5000 ]
do
    echo testing $i > /tmp/test$i.txt
    i=$(($i+1))
done
mc admin service restart ma0/


