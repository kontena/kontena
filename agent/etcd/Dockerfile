FROM gliderlabs/alpine:3.2
RUN apk-install ca-certificates openssl
ENV ETCD_VERSION=2.2.1
ADD https://github.com/coreos/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz \
    etcd-v${ETCD_VERSION}-linux-amd64.tar.gz
RUN tar xzvf etcd-v${ETCD_VERSION}-linux-amd64.tar.gz && \
    mv etcd-v${ETCD_VERSION}-linux-amd64/etcd /usr/bin && \
    mv etcd-v${ETCD_VERSION}-linux-amd64/etcdctl /usr/bin && \
    rm etcd-v${ETCD_VERSION}-linux-amd64.tar.gz && \
    rm -Rf etcd-v${ETCD_VERSION}-linux-amd64*
VOLUME /data
EXPOSE 2379 2380
ENTRYPOINT ["/usr/bin/etcd"]
