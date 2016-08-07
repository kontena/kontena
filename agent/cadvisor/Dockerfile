FROM gliderlabs/alpine:3.2
MAINTAINER Kontena, Inc. <info@kontena.io>

RUN apk add --update ca-certificates util-linux && \
    rm -rf /var/cache/apk/*

ADD https://github.com/google/cadvisor/releases/download/v0.23.2/cadvisor /usr/bin/cadvisor
RUN chmod +x /usr/bin/cadvisor
ADD entrypoint.sh /

EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
