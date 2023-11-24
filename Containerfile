# The builder is UBI because I trust the source and we're going to steal
# ssh, git, and their shared libraries later for the scratch container

FROM registry.access.redhat.com/ubi9/ubi as builder
ARG GO_VERSION=1.21.4
ARG COREDNS_VERSION=1.11.1
ENV GO_VERSION=${GO_VERSION}
ENV COREDNS_VERSION=${COREDNS_VERSION}

RUN dnf -y update
RUN dnf -y install git
RUN curl -o /root/go${GO_VERSION}.linux-amd64.tar.gz -L https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
WORKDIR /root
RUN tar zxf go${GO_VERSION}.linux-amd64.tar.gz
RUN ln -s /root/go/bin/go /usr/local/bin/go
WORKDIR /root
RUN git clone --depth 1 --branch v${COREDNS_VERSION} https://github.com/coredns/coredns.git
# Our plugin is greatly reduced to minimize the footprint
ADD plugin.cfg /root/coredns/plugin.cfg
WORKDIR /root/coredns
RUN go get github.com/miekg/coredns-git \
  && go generate && GOOS=linux GOARCH=amd64 go build


RUN mkdir /root/zones

FROM scratch
COPY --from=builder /root/coredns/coredns /sbin/coredns
COPY --from=builder /usr/bin/git /bin/git
COPY --from=builder /usr/bin/ssh /bin/ssh

# We need shared libraries since we're using stock UBI git and ssh binaries
COPY --from=builder /lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2
COPY --from=builder /lib64/libcom_err.so.2 /lib64/libcom_err.so.2
COPY --from=builder /lib64/libcrypto.so.3 /lib64/libcrypto.so.3
COPY --from=builder /lib64/libcrypt.so.2 /lib64/libcrypt.so.2
COPY --from=builder /lib64/libc.so.6 /lib64/libc.so.6
COPY --from=builder /lib64/libdl.so.2 /lib64/libdl.so.2
COPY --from=builder /lib64/libgssapi_krb5.so.2 /lib64/libgssapi_krb5.so.2
COPY --from=builder /lib64/libk5crypto.so.3 /lib64/libk5crypto.so.3
COPY --from=builder /lib64/libkeyutils.so.1 /lib64/libkeyutils.so.1
COPY --from=builder /lib64/libkrb5.so.3 /lib64/libkrb5.so.3
COPY --from=builder /lib64/libkrb5support.so.0 /lib64/libkrb5support.so.0
COPY --from=builder /lib64/libpcre2-8.so.0 /lib64/libpcre2-8.so.0
COPY --from=builder /lib64/libpthread.so.0 /lib64/libpthread.so.0
COPY --from=builder /lib64/libresolv.so.2 /lib64/libresolv.so.2
COPY --from=builder /lib64/librt.so.1 /lib64/librt.so.1
COPY --from=builder /lib64/libselinux.so.1 /lib64/libselinux.so.1
COPY --from=builder /lib64/libutil.so.1 /lib64/libutil.so.1
COPY --from=builder /lib64/libz.so.1 /lib64/libz.so.1
COPY --from=builder /lib64/libnss_files.so.2 /lib64/libnss_files.so.2
COPY --from=builder /lib64/libnss_dns.so.2 /lib64/libnss_dns.so.2

# If you need bash for debug, then uncomment these
#COPY --from=builder /usr/bin/bash /bin/bash
#COPY --from=builder /lib64/libtinfo.so.6 /lib64/libtinfo.so.6

# Config files specific to this container
COPY --from=builder /root/zones /etc/coredns/zones
ADD Corefile /etc/coredns/Corefile

# Configs needed because we're using scratch
ADD ssh_config /etc/ssh/ssh_config
ADD passwd /etc/passwd
ADD group /etc/group
ADD shadow /etc/shadow
ADD nsswitch.conf /etc/nsswitch.conf

# not adding services right now to keep the file size down
#ADD services /etc/services

# Ports that are exposed from Corefile
EXPOSE 53/udp

# ENVs that are used in the Corefile
ENV FORWARDER1="1.1.1.1"
ENV FORWARDER2="1.0.0.1"
ENV GIT_URL=""
ENV GIT_INT=900

ENTRYPOINT ["/sbin/coredns", "-conf", "/etc/coredns/Corefile"]
