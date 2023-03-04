# bad s2s

## Environment setup

`helmfile.yaml` defined 2 minio clusters, each with 2 pods x 2 disks. An extra pod for mc CLI.


```bash
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

## Building from source

```
# https://github.com/moovweb/gvm
> gvm install go1.17.13
> gvm use go17.13

> go build

# update image.tag in helm/minio/values.yaml accordingly
> docker build -t minio/minio:patched-0.1
> kind load docker-image minio/minio:patched-0.1
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


## Reproducing broken site replication

A script is included in `/mc/scripts/setup.sh` in `deployments/mc` pod which can be used to create a broken site replication from a fresh environment.

```bash
> kubectl exec deployments/mc -- /mc/scripts/setup.sh

mc: Configuration written to `/root/.mc/config.json`. Please update your access credentials.
mc: Successfully created `/root/.mc/share`.
mc: Initialized share uploads `/root/.mc/share/uploads.json` file.
mc: Initialized share downloads `/root/.mc/share/downloads.json` file.
Added `ma0` successfully.
Added `ma1` successfully.
Added `mb0` successfully.
Added `mb1` successfully.
Bucket created successfully `ma0/bucket1`.
Bucket created successfully `ma0/bucket002`.
Bucket created successfully `ma0/bucket003`.
Bucket created successfully `ma0/bucket004`.
Bucket created successfully `ma0/bucket005`.
Bucket created successfully `ma0/bucket006`.
Bucket created successfully `ma0/bucket007`.
Bucket created successfully `ma0/bucket008`.
Bucket created successfully `ma0/bucket009`.
Bucket created successfully `ma0/bucket010`.
Bucket created successfully `ma0/bucket011`.
Bucket created successfully `ma0/bucket012`.
/tmp/test999.txt:            63.36 KiB / 63.36 KiB ┃▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓┃ 4.83 KiB/s 13sNAME:
  mc admin bucket remote rm - remove configured remote target

USAGE:
  mc admin bucket remote rm TARGET
...

Removed remote target for `bucket002` bucket successfully.
Restart command successfully sent to `ma0/`. Type Ctrl-C to quit or wait to follow the status of the restart process.
.....Requested sites were configured for replication successfully.
Site replication error(s): Site ma0/ (2711a13c-c0fd-4e97-8ecc-d13649a64aeb): Site replication error(s): Site mb0/ (6ab2ccf8-628e-417c-b450-80b16cc69f59): Remote service endpoint or target bucket not available: bucket005
        context canceled; Site mb0/ (6ab2ccf8-628e-417c-b450-80b16cc69f59): context canceled

Restarted `ma0/` successfully in 3 seconds


# Verify cluster status
# should be same output for ma0, ma1, mb0, mb1

> mc admin replicate info ma0/
SiteReplication enabled for:

Deployment ID                        | Site Name       | Endpoint
2711a13c-c0fd-4e97-8ecc-d13649a64aeb | ma0/            | http://ma-minio-0.ma-minio-svc:9000
6ab2ccf8-628e-417c-b450-80b16cc69f59 | mb0/            | http://mb-minio-0.mb-minio-svc:9000

> mc admin replicate status ma0/
Bucket replication status:
●  4/12 Buckets in sync

Bucket          | MA0/            | MB0/
bucket007       | ✗  in-sync      |   Bucket

bucket008       | ✗  in-sync      |   Bucket

bucket009       | ✗  in-sync      |   Bucket

bucket010       | ✗  in-sync      |   Bucket

bucket011       | ✗  in-sync      |   Bucket

bucket012       | ✗  in-sync      |   Bucket

bucket1         | ✗  in-sync      |   Bucket

bucket006       | ✗  in-sync      |   Bucket

Policy replication status:
●  5/5 Policies in sync

User replication status:
No Users present

Group replication status:
No Groups present


# remote bucket info is lost in ma, but still in bm
> mc admin bucket remote ls ma0/
Remote URL                           Source   ->Target    ARN                                                                   SYNC PROXY
http://mb-minio-0.mb-minio-svc:9000  bucket004->bucket004 arn:minio:replication::0046a1f0-0f97-4b15-9079-489cecb612e8:bucket004      proxy
http://mb-minio-0.mb-minio-svc:9000  bucket003->bucket003 arn:minio:replication::81be9cd8-db31-4287-a8c3-fcfcc6a770e3:bucket003      proxy

> mc admin bucket remote ls ma1/
Remote URL                           Source   ->Target    ARN                                                                   SYNC PROXY
http://mb-minio-0.mb-minio-svc:9000  bucket004->bucket004 arn:minio:replication::0046a1f0-0f97-4b15-9079-489cecb612e8:bucket004      proxy
http://mb-minio-0.mb-minio-svc:9000  bucket003->bucket003 arn:minio:replication::81be9cd8-db31-4287-a8c3-fcfcc6a770e3:bucket003      proxy

> mc admin bucket remote ls mb0/
Remote URL                           Source   ->Target    ARN                                                                   SYNC PROXY
http://ma-minio-0.ma-minio-svc:9000  bucket002->bucket002 arn:minio:replication::000c5420-2f29-48c7-906f-6a46b8213c5e:bucket002      proxy
http://ma-minio-0.ma-minio-svc:9000  bucket003->bucket003 arn:minio:replication::d56ff62b-8243-4484-aece-b1752db1c089:bucket003      proxy
http://ma-minio-0.ma-minio-svc:9000  bucket004->bucket004 arn:minio:replication::ad344e33-c0d2-4fee-a749-dd57ec10a87a:bucket004      proxy

> mc admin bucket remote ls mb1/
Remote URL                           Source   ->Target    ARN                                                                   SYNC PROXY
http://ma-minio-0.ma-minio-svc:9000  bucket002->bucket002 arn:minio:replication::000c5420-2f29-48c7-906f-6a46b8213c5e:bucket002      proxy
http://ma-minio-0.ma-minio-svc:9000  bucket003->bucket003 arn:minio:replication::d56ff62b-8243-4484-aece-b1752db1c089:bucket003      proxy
http://ma-minio-0.ma-minio-svc:9000  bucket004->bucket004 arn:minio:replication::ad344e33-c0d2-4fee-a749-dd57ec10a87a:bucket004      proxy


# bucket replication configurations are incomplete and inconsistent between ma and mb.
> mc replicate ls ma0/bucket002
mc: <ERROR> Unable to list replication configuration: replication configuration not set.

> mc replicate ls ma0/bucket003
ID                   | Priority | Status   | Prefix                    | Tags                      | DestBucket           | StorageClass
site-repl-6ab2ccf... | 10       | Enabled  |

> mc replicate ls mb0/bucket002
ID                   | Priority | Status   | Prefix                    | Tags                      | DestBucket           | StorageClass
site-repl-2711a13... | 10       | Enabled  |

> mc replicate ls mb0/bucket003
ID                   | Priority | Status   | Prefix                    | Tags                      | DestBucket           | StorageClass
site-repl-2711a13... | 10       | Enabled  |                           |                           | arn:minio:replica... |


```

