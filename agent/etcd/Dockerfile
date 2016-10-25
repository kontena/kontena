FROM alpine:3.4
RUN apk --update add ca-certificates openssl
ENV ETCD_RELEASE=2.3.7
ADD https://github.com/coreos/etcd/releases/download/v${ETCD_RELEASE}/etcd-v${ETCD_RELEASE}-linux-amd64.tar.gz \
    etcd-v${ETCD_RELEASE}-linux-amd64.tar.gz
RUN tar xzvf etcd-v${ETCD_RELEASE}-linux-amd64.tar.gz && \
    mv etcd-v${ETCD_RELEASE}-linux-amd64/etcd /usr/bin && \
    mv etcd-v${ETCD_RELEASE}-linux-amd64/etcdctl /usr/bin && \
    rm etcd-v${ETCD_RELEASE}-linux-amd64.tar.gz && \
    rm -Rf etcd-v${ETCD_RELEASE}-linux-amd64*
VOLUME /data
EXPOSE 2379 2380
ENTRYPOINT ["/usr/bin/etcd"]
