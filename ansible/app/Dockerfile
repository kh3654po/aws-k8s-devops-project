# syntax=docker/dockerfile:1

FROM golang:1.26-alpine AS builder

WORKDIR /src

COPY go.mod ./

COPY main.go ./

ARG VERSION=dev
ARG COMMIT=unknown
ARG BUILD_TIME=unknown

RUN CGO_ENABLED=0 \
    GOOS=linux \
    go build \
    -trimpath \
    -ldflags="-s -w \
      -X main.version=${VERSION} \
      -X main.commit=${COMMIT} \
      -X main.buildTime=${BUILD_TIME}" \
    -o /out/ksh-devops-demo \
    .

FROM scratch

COPY --from=builder \
    /out/ksh-devops-demo \
    /ksh-devops-demo

USER 65532:65532

EXPOSE 8080

ENTRYPOINT ["/ksh-devops-demo"]