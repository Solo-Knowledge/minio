FROM --platform=$BUILDPLATFORM golang:1.24-alpine AS builder

ARG TARGETOS
ARG TARGETARCH
ARG RELEASE_TAG
ARG COMMIT_ID

WORKDIR /src

RUN apk add --no-cache ca-certificates git

COPY . .

ENV CGO_ENABLED=0 \
    GO111MODULE=on

RUN if [ -z "${RELEASE_TAG}" ]; then \
        RELEASE_TAG="RELEASE.$(date -u +'%Y-%m-%dT%H-%M-%SZ')"; \
    fi && \
    if [ -z "${COMMIT_ID}" ]; then \
        COMMIT_ID="$(git rev-parse HEAD 2>/dev/null || echo 'unknown')"; \
    fi && \
    LDFLAGS="-s -w \
        -X github.com/minio/minio/cmd.Version=${RELEASE_TAG} \
        -X github.com/minio/minio/cmd.ReleaseTag=${RELEASE_TAG} \
        -X github.com/minio/minio/cmd.CommitID=${COMMIT_ID} \
        -X github.com/minio/minio/cmd.ShortCommitID=${COMMIT_ID:0:12}" && \
    GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH:-amd64} go build -tags kqueue -trimpath --ldflags "${LDFLAGS}" -o /out/minio .

FROM alpine:3.21

RUN apk add --no-cache ca-certificates curl

COPY --from=builder /out/minio /usr/local/bin/minio
COPY dockerscripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

RUN mkdir -p /data

EXPOSE 9000 9001
VOLUME ["/data"]

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["minio", "server", "/data", "--console-address", ":9001"]
