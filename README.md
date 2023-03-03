# bad s2s

```bash
# https://github.com/moovweb/gvm
> gvm install go1.17.13
> gvm use go17.13

> go build

# update image.tag in helm/minio/values.yaml accordingly
> docker build -t minio:0.4 .

# https://github.com/helmfile/helmfile
> helmfile apply

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



