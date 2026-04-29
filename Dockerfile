FROM golang:1.24-alpine AS build

ARG TARGETARCH
ARG RELEASE
ARG COMMIT_ID

ENV GOPATH=/go
ENV CGO_ENABLED=0

WORKDIR /build

RUN apk add -U --no-cache ca-certificates

COPY . .

RUN GOARCH=${TARGETARCH} go build -tags kqueue -trimpath \
    --ldflags "-s -w \
    -X github.com/minio/minio/cmd.Version=${RELEASE} \
    -X github.com/minio/minio/cmd.CopyrightYear=$(echo ${RELEASE} | cut -c1-4) \
    -X github.com/minio/minio/cmd.ReleaseTag=RELEASE.${RELEASE} \
    -X github.com/minio/minio/cmd.CommitID=${COMMIT_ID} \
    -X github.com/minio/minio/cmd.ShortCommitID=${COMMIT_ID} \
    -X github.com/minio/minio/cmd.GOPATH=${GOPATH} \
    -X github.com/minio/minio/cmd.GOROOT=$(go env GOROOT)" \
    -o /go/bin/minio .

FROM ghcr.io/rophy/mc:20260423-fcc2cb6 AS mc

FROM debian:bookworm-slim

ARG RELEASE

LABEL name="MinIO" \
      vendor="MinIO Inc <dev@min.io>" \
      maintainer="MinIO Inc <dev@min.io>" \
      version="${RELEASE}" \
      release="${RELEASE}" \
      summary="MinIO is a High Performance Object Storage, API compatible with Amazon S3 cloud storage service." \
      description="MinIO object storage is fundamentally different. Designed for performance and the S3 API, it is 100% open-source. MinIO is ideal for large, private cloud environments with stringent security requirements and delivers mission-critical availability across a diverse range of workloads."

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /go/bin/minio /usr/bin/minio
COPY --from=mc /usr/bin/mc /usr/bin/mc
COPY dockerscripts/docker-entrypoint.sh /usr/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]

VOLUME ["/data"]

CMD ["minio"]
