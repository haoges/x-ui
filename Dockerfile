# Build stage
FROM golang:1.23-alpine AS builder

ARG XUI_REPO="https://github.com/haoges/x-ui"

# Install build dependencies
RUN apk add --no-cache --update \
    build-base \
    gcc \
    git \
    && git clone ${XUI_REPO} --depth=1 /go/x-ui

WORKDIR /go/x-ui

# Build with proper flags and optimizations
ENV CGO_ENABLED=1 \
    CGO_CFLAGS="-D_LARGEFILE64_SOURCE" \
    GO111MODULE=on \
    GOOS=linux

RUN go build -a -trimpath \
    -ldflags "-s -w -linkmode external -extldflags '-static'" \
    -o x-ui

# Final stage
FROM alpine:latest

LABEL org.opencontainers.image.authors="https://github.com/haoges"

# Set timezone and install necessary packages
ENV TZ=Asia/Shanghai

RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    && cp /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo "${TZ}" > /etc/timezone \
    && rm -rf /var/cache/apk/*

# Copy binary from builder
COPY --from=builder /go/x-ui/x-ui /usr/local/bin/x-ui

# Copy Xray binary and resources based on architecture
ARG TARGETARCH
COPY --from=teddysun/xray /usr/bin/xray /usr/local/bin/bin/xray-linux-${TARGETARCH}
COPY --from=teddysun/xray /usr/share/xray/ /usr/local/bin/bin/

# Set up volume and working directory
VOLUME ["/etc/x-ui"]
WORKDIR /usr/local/bin

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
    CMD wget --no-verbose --tries=1 --spider http://localhost:54321 || exit 1

# Expose necessary ports (customize as needed)
EXPOSE 54321

CMD ["x-ui"]
