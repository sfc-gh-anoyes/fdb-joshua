FROM centos:7
# this is joshua-agent

RUN yum repolist && \
    yum install -y \
        centos-release-scl-rh \
        epel-release \
        scl-utils \
        yum-utils && \
    yum -y install \
        devtoolset-8 \
        devtoolset-8-libasan-devel \
        devtoolset-8-liblsan-devel \
        devtoolset-8-libtsan-devel \
        devtoolset-8-libubsan-devel \
        devtoolset-8-valgrind-devel \
        gettext \
        golang \
        java-11-openjdk-devel \
        mono-core \
        net-tools \
        rh-python38 \
        rh-python38-python-devel \
        rh-python38-python-pip \
        rh-ruby27 \
        rh-ruby27-ruby-devel && \
    source /opt/rh/devtoolset-8/enable && \
    source /opt/rh/rh-python38/enable && \
    source /opt/rh/rh-ruby27/enable && \
    pip3 install \
        python-dateutil \
        subprocess32 \
        psutil && \
    gem install ffi --platform=ruby && \
    groupadd -r joshua -g 4060 && \
    useradd \
        -rm \
        -d /home/joshua \
        -s /bin/bash \
        -u 4060 \
        -g joshua \
        joshua && \
    mkdir -p /var/joshua && \
    chown -R joshua:joshua /var/joshua && \
    rm -rf /tmp/*

COPY childsubreaper/ /opt/joshua/install/childsubreaper
COPY joshua/ /opt/joshua/install/joshua
COPY setup.py /opt/joshua/install/

RUN source /opt/rh/devtoolset-8/enable && \
    source /opt/rh/rh-python38/enable && \
    source /opt/rh/rh-ruby27/enable && \
    pip3 install /opt/joshua/install && \
    rm -rf /opt/joshua/install

ARG OLD_FDB_BINARY_DIR=/app/deploy/global_data/oldBinaries/
ARG OLD_TLS_LIBRARY_DIR=/app/deploy/runtime/.tls_5_1/
ARG FDB_VERSION="6.2.29"
RUN if [ "$(uname -p)" == "x86_64" ]; then \
        mkdir -p ${OLD_FDB_BINARY_DIR} \
                 ${OLD_TLS_LIBRARY_DIR} \
                 /usr/lib/foundationdb/plugins && \
        curl -Ls https://www.foundationdb.org/downloads/misc/fdbservers-${FDB_VERSION}.tar.gz | tar -xz -C ${OLD_FDB_BINARY_DIR} && \
        rm -f ${OLD_FDB_BINARY_DIR}/*.sha256 && \
        chmod +x ${OLD_FDB_BINARY_DIR}/* && \
        curl -Ls https://www.foundationdb.org/downloads/misc/joshua_tls_library.tar.gz | tar -xz -C ${OLD_TLS_LIBRARY_DIR} --strip-components=1 && \
        curl -Ls https://www.foundationdb.org/downloads/${FDB_VERSION}/linux/libfdb_c_${FDB_VERSION}.so -o /usr/lib64/libfdb_c_${FDB_VERSION}.so && \
        ln -s /usr/lib64/libfdb_c_${FDB_VERSION}.so /usr/lib64/libfdb_c.so && \
        ln -s ${OLD_TLS_LIBRARY_DIR}/FDBGnuTLS.so /usr/lib/foundationdb/plugins/fdb-libressl-plugin.so && \
        ln -s ${OLD_TLS_LIBRARY_DIR}/FDBGnuTLS.so /usr/lib/foundationdb/plugins/FDBGnuTLS.so; \
        fi

ENV FDB_CLUSTER_FILE=/etc/foundationdb/fdb.cluster
ENV AGENT_TIMEOUT=300

USER joshua
CMD source /opt/rh/devtoolset-8/enable && \
    source /opt/rh/rh-python38/enable && \
    source /opt/rh/rh-ruby27/enable && \
    python3 -m joshua.joshua_agent \
        -C ${FDB_CLUSTER_FILE} \
        --work_dir /var/joshua \
        --agent-idle-timeout ${AGENT_TIMEOUT}

