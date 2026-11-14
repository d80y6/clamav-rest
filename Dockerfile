FROM clamav/clamav

# Update packages safely
RUN apk update && apk upgrade

# Install git and tzdata
RUN apk add --no-cache git tzdata make musl-dev go

# Set timezone to Europe/Zurich
RUN ln -sf /usr/share/zoneinfo/Europe/Zurich /etc/localtime

# Configure Go environment
ENV GOROOT=/usr/lib/go
ENV GOPATH=/go
ENV PATH=/go/bin:$PATH

RUN mkdir -p ${GOPATH}/src ${GOPATH}/bin

WORKDIR $GOPATH

# Install ClamAV utilities if not already present in the base image
RUN apk --no-cache add clamav clamav-libunrar \
    && mkdir -p /run/clamav \
    && chown clamav:clamav /run/clamav

# Configure ClamAV to run in foreground with port 3310
RUN sed -i 's/^#Foreground .*$/Foreground true/g' /etc/clamav/clamd.conf \
    && sed -i 's/^#TCPSocket .*$/TCPSocket 3310/g' /etc/clamav/clamd.conf \
    && sed -i 's/^#Foreground .*$/Foreground true/g' /etc/clamav/freshclam.conf

# Optional: run freshclam during build (can be skipped or allowed to fail gracefully if network blocks it)
RUN freshclam --quiet --no-dns || true

# Build go package
ADD . /go/src/clamav-rest/
WORKDIR /go/src/clamav-rest

# Initialize module and fetch dependencies cleanly using modern Go syntax
RUN go mod init clamav-rest || true
RUN go get github.com/lyimmi/go-clamd
RUN go get github.com/prometheus/client_golang/prometheus/promhttp
RUN go mod vendor
RUN go build -v -o clamav-rest .

# Copy SSL certificates and entrypoint
RUN mkdir -p /etc/ssl/clamav-rest/
ADD ./server.* /etc/ssl/clamav-rest/

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
