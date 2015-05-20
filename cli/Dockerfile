FROM gliderlabs/alpine:edge
MAINTAINER jari@kontena.io

RUN apk update && \
  apk --update add ruby ruby-json ca-certificates libssl1.0 openssl libstdc++ && \
  gem install kontena-cli --no-rdoc --no-ri


RUN adduser kontena -D -h /home/kontena -s /bin/sh
RUN chown -R kontena.kontena /home/kontena


VOLUME ["/home/kontena"]
WORKDIR /home/kontena
USER kontena
ENTRYPOINT ["/usr/bin/kontena"]
