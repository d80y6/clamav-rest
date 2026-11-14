FROM clamav/clamav:latest

# Switch to root to install packages and build
USER root

# Update and install build dependencies, git, tzdata, and Go
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    tzdata \
    make \
    musl-dev \
    golang-go \
    && rm -rf /var/lib/apt/lists/*

# Set timezone to Europe/Zurich
RUN ln -sf /usr/share/zoneinfo/Europe/Zurich /etc/localtime

# Configure Go environment
ENV GOROOT=/usr/lib/go
ENV GOPATH=/go
ENV PATH=/go/bin:$PATH

RUN mkdir -p ${GOPATH}/src ${GOPATH}/bin

# Configure ClamAV daemon
RUN sed -i 's/^#Foreground .*$/Foreground true/g' /etc/clamav/clamd.conf \
    && sed -i 's/^#TCPSocket .*$/TCPSocket 3310/g' /etc/clamav/clamd.conf \
    && sed -i 's/^#Foreground .*$/Foreground true/g' /etc/clamav/freshclam.conf \
    && mkdir -p /run/clamav \
    && chown clamav:clamav /run/clamav

# Download initial virus definitions (optional: can be skipped to avoid build timeouts)
# RUN freshclam --quiet --no-dns || true

# Build go package
WORKDIR /go/src/clamav-rest
ADD . /go/src/clamav-rest/

RUN go mod init clamav-rest || true
RUN go mod tidy
RUN go build -v -o clamav-rest .

# Copy assets and entrypoint
RUN mkdir -p /etc/ssl/clamav-rest/
RUN cp ./server.* /etc/ssl/clamav-rest/ 2>/dev/null || true

COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh \
    && mv /go/src/clamav-rest/clamav-rest /usr/bin/ \
    && rm -Rf /go/src/clamav-rest

EXPOSE 9000
EXPOSE 9443

ENV MAX_SCAN_SIZE=100M
ENV MAX_FILE_SIZE=25M
ENV MAX_RECURSION=16
ENV MAX_FILES=10000
ENV MAX_EMBEDDEDPE=10M
ENV MAX_HTMLNORMALIZE=10M
ENV MAX_HTMLNOTAGS=2M
ENV MAX_SCRIPTNORMALIZE=5M
ENV MAX_ZIPTYPERCG=1M
ENV MAX_PARTITIONS=50
ENV MAX_ICONSPE=100
ENV PCRE_MATCHLIMIT=100000
ENV PCRE_RECMATCHLIMIT=2000
ENV SIGNATURE_CHECKS=2

ENTRYPOINT [ "entrypoint.sh" ]
