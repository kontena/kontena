FROM gliderlabs/alpine:3.2
RUN apk-install ca-certificates openssl
ADD https://github.com/coreos/etcd/releases/download/v2.1.2/etcd-v2.1.2-linux-amd64.tar.gz etcd-v2.1.2-linux-amd64.tar.gz
RUN tar xzvf etcd-v2.1.2-linux-amd64.tar.gz
RUN mv etcd-v2.1.2-linux-amd64/etcd /usr/bin && mv etcd-v2.1.2-linux-amd64/etcdctl /usr/bin && rm -Rf etcd-v2.1.2-linux-amd64*
VOLUME /data
EXPOSE 2379 2380
ENTRYPOINT ["/usr/bin/etcd"]
