# bad s2s

## environment

`helmfile.yaml` defined 2 minio clusters, each with 2 pods x 2 disks. An extra pod for mc CLI.


```bash
# https://github.com/moovweb/gvm
> gvm install go1.17.13
> gvm use go17.13

> go build

# update image.tag in helm/minio/values.yaml accordingly
> docker build -t minio:0.4 .
> kind load docker-image minio:0.4

# https://github.com/helmfile/helmfile
> helmfile apply

> helm ls
NAME    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART           APP VERSION
ma      minio           1               2023-03-04 12:42:45.135646216 +0800 CST deployed        minio-3.6.2     RELEASE.2022-03-17T06-34-49Z
mb      minio           1               2023-03-04 12:42:45.124420229 +0800 CST deployed        minio-3.6.2     RELEASE.2022-03-17T06-34-49Z
mc      minio           1               2023-03-04 12:42:45.145694776 +0800 CST deployed        mc-0.1.0        RELEASE.2022-03-17T20-25-06Z

# wait until both ma and mb ready.
> kubectl logs -f ma-minio-0

# try to setup S2S, and then break it
> kubectl exec deployments/mc -- /mc/scripts/setup.sh
```

To start over:

```bash
> helmfile destroy
> kubectl delete pvc --all
> helmfile apply
```

## BASELINE: verify behaviours of site replication BEFORE patching

VERSION: RELEASE.2022-03-22T02-05-10Z


setup mc client:

```bash
mc alias set ma0 http://ma-minio-0.ma-minio-svc:9000 admin Passw0rd
mc alias set ma1 http://ma-minio-1.ma-minio-svc:9000 admin Passw0rd
mc alias set mb0 http://mb-minio-0.mb-minio-svc:9000 admin Passw0rd
mc alias set mb1 http://mb-minio-0.mb-minio-svc:9000 admin Passw0rd
```

before enabling site replication, check status of relevant commands:

```bash
> mc admin replicate info ma0
SiteReplication is not enabled

> mc admin replicate status ma0
SiteReplication is not enabled
```

create some buckets, then enable site replication:

```bash
> mc mb ma0/bucket1
Bucket created successfully `ma0/bucket1`.
> mc mb ma0/bucket2
Bucket created successfully `ma0/bucket2`.
> mc mb ma0/bucket3
Bucket created successfully `ma0/bucket3`.
> mc admin replicate add ma0 mb0
Requested sites were configured for replication successfully.
```

verify status of relevant commands:

```bash

# same results for ma0, ma1, mb0, mb1
> mc admin replicate info ma0/
SiteReplication enabled for:

Deployment ID                        | Site Name       | Endpoint
a714f667-80c6-4990-8577-5854aaacf74a | ma0             | http://ma-minio-0.ma-minio-svc:9000
121670b3-8276-47bb-86e6-ad937a02899e | mb0             | http://mb-minio-0.mb-minio-svc:9000

# same results for ma0, ma1, mb0, mb1
> mc admin replicate status ma0/
Bucket replication status:
●  3/3 Buckets in sync

Policy replication status:
●  5/5 Policies in sync

User replication status:
No Users present

Group replication status:
No Groups present

# same results for ma0, ma1, mb0, mb1
> mc admin bucket remote ls ma0/
Remote URL                           Source ->Target  ARN                                                                 SYNC PROXY
http://mb-minio-0.mb-minio-svc:9000  bucket1->bucket1 arn:minio:replication::44611d7b-896a-4a4a-9977-8f9878e1f2fe:bucket1      proxy
http://mb-minio-0.mb-minio-svc:9000  bucket2->bucket2 arn:minio:replication::e1030d83-cffe-49d8-b38b-9a3fdb916042:bucket2      proxy
http://mb-minio-0.mb-minio-svc:9000  bucket3->bucket3 arn:minio:replication::880eebb8-ecd4-467f-9ad4-bc080cce26dd:bucket3      proxy


# same results for 4 pods and 3 buckets
> mc replicate ls ma0/bucket1
ID                   | Priority | Status   | Prefix                    | Tags                      | DestBucket           | StorageClass
site-repl-121670b... | 10       | Enabled  |                           |                           | arn:minio:replica... |
```


Now remove site replication:

```bash
> mc admin replicate remove ma0 --all --force
All site(s) were removed successfully

# mc admin replicate info
# NOTE: not all 4 pods have same status.
> mc admin replicate info ma0/
SiteReplication is not enabled

> mc admin replicate info ma1/
SiteReplication enabled for:

Deployment ID                        | Site Name       | Endpoint

> mc admin replicate info mb0/
SiteReplication is not enabled

> mc admin replicate info mb1/
SiteReplication is not enabled

# mc admin replicate status
# NOTE: not all 4 pods have same status

# ma0, mb0, mb1
> mc admin replicate status ma0/
SiteReplication is not enabled

> mc admin replicate status ma1/
Bucket replication status:
No Buckets present

Policy replication status:
No Policies present

User replication status:
No Users present

Group replication status:
No Groups present

# mc admin bucket remote ls
# NOTE: not all 4 pods have same status

# ma0, mb0, mb1
> mc admin bucket remote ls ma0/
No remote targets found for `ma0`.

> mc admin bucket remote ls ma1/
Remote URL                           Source ->Target  ARN                                                                 SYNC PROXY
http://mb-minio-0.mb-minio-svc:9000  bucket3->bucket3 arn:minio:replication::880eebb8-ecd4-467f-9ad4-bc080cce26dd:bucket3      proxy
http://mb-minio-0.mb-minio-svc:9000  bucket1->bucket1 arn:minio:replication::44611d7b-896a-4a4a-9977-8f9878e1f2fe:bucket1      proxy
http://mb-minio-0.mb-minio-svc:9000  bucket2->bucket2 arn:minio:replication::e1030d83-cffe-49d8-b38b-9a3fdb916042:bucket2      proxy

# same for ma0, ma1, mb0, mb1 for 3 buckets
> mc replicate ls ma0/bucket1
mc: <ERROR> Unable to list replication configuration: replication configuration not set.

```

Restart all services, then check status again

```bash
> mc admin service restart ma0/
Restart command successfully sent to `ma0/`. Type Ctrl-C to quit or wait to follow the status of the restart process.
...
Restarted `ma0/` successfully in 1 seconds

# same for ma0, ma1
> mc admin replicate info ma0/
SiteReplication enabled for:

Deployment ID                        | Site Name       | Endpoint

# same for ma0, ma1
> mc admin replicate status ma0/
Bucket replication status:
No Buckets present

Policy replication status:
No Policies present

User replication status:
No Users present

Group replication status:
No Groups present

# same for ma0, ma1
> mc admin bucket remote ls ma0/
Remote URL                           Source ->Target  ARN                                                                 SYNC PROXY
http://mb-minio-0.mb-minio-svc:9000  bucket2->bucket2 arn:minio:replication::e1030d83-cffe-49d8-b38b-9a3fdb916042:bucket2      proxy
http://mb-minio-0.mb-minio-svc:9000  bucket1->bucket1 arn:minio:replication::44611d7b-896a-4a4a-9977-8f9878e1f2fe:bucket1      proxy
http://mb-minio-0.mb-minio-svc:9000  bucket3->bucket3 arn:minio:replication::880eebb8-ecd4-467f-9ad4-bc080cce26dd:bucket3      proxy


# same for ma0, ma1, mb0, mb1 for 3 buckets
> mc replicate ls ma0/bucket1
mc: <ERROR> Unable to list replication configuration: replication configuration not set.

```

Finally try to remove site replication again and see what happens:

```bash
> mc admin replicate remove ma0/ --force --all
All site(s) were removed successfully

> mc admin replicate status ma0/
SiteReplication is not enabled

> mc admin replicate status ma1/
Bucket replication status:
No Buckets present

Policy replication status:
No Policies present

User replication status:
No Users present

Group replication status:
No Groups present

> mc admin replicate info ma0/
SiteReplication is not enabled

> mc admin replicate info ma1/
SiteReplication enabled for:

Deployment ID                        | Site Name       | Endpoint

# try running same command on the other pod
> mc admin replicate remove ma1/ --force --all
All site(s) were removed successfully

> mc admin replicate info ma1/
SiteReplication is not enabled

> mc admin replicate info ma0/
SiteReplication enabled for:

Deployment ID                        | Site Name       | Endpoint

```

Finding:

1. The exact pod that runs remove command, and all pods in remote cluster, will become "not enabled".
2. The other pods in thes cluster will become "enabled without any sites".
3. After restart, all pods become "enabled without any sites".

