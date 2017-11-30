FROM alpine:3.6
LABEL maintainer="Sean Cheung <theoxuanx@gmail.com>"

ENV ELK_VERSION 6.0.0

RUN echo "Install Dependencies..." \
    && apk add nodejs mysql mysql-client redis --no-cache --repository=http://dl-3.alpinelinux.org/alpine/edge/main/ \
    && apk add mongodb openjdk8-jre --no-cache --repository=http://dl-3.alpinelinux.org/alpine/edge/community/ \
    && apk add --no-cache bash git openssl supervisor nginx apache2-utils libzmq python make g++ \
    && mkdir -p /usr/local/lib \
    && ln -s /usr/lib/*/libzmq.so.3 /usr/local/lib/libzmq.so \
    && for path in \
		/var/log/mysql \
		/var/run/mysql \
		/var/opt/mysql \
	; do \
	mkdir -p "$path"; \
	chown mysql:mysql "$path"; \
	done \
    && apk add --no-cache -t .build-deps wget ca-certificates \
    && set -x \
    && cd /tmp \
    && echo "Download [Elasticsearch]..." \
    && wget --progress=bar:force -O elasticsearch-$ELK_VERSION.tar.gz https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-$ELK_VERSION.tar.gz \
    && tar -xzf elasticsearch-$ELK_VERSION.tar.gz \
    && mv elasticsearch-$ELK_VERSION /usr/share/elasticsearch \
    && echo "Download [Logstash]..." \
    && wget --progress=bar:force -O logstash-$ELK_VERSION.tar.gz https://artifacts.elastic.co/downloads/logstash/logstash-$ELK_VERSION.tar.gz \
    && tar -xzf logstash-$ELK_VERSION.tar.gz \
    && mv logstash-$ELK_VERSION /usr/share/logstash \
    && echo "Download [Kibana]..." \
    && wget --progress=bar:force -O kibana-$ELK_VERSION.tar.gz https://artifacts.elastic.co/downloads/kibana/kibana-$ELK_VERSION-linux-x86_64.tar.gz \
    && tar -xzf kibana-$ELK_VERSION.tar.gz \
    && mv kibana-$ELK_VERSION-linux-x86_64 /usr/share/kibana \
    && echo "Configure [Elasticsearch] ===================================================" \
    && for path in \
		/usr/share/elasticsearch/data \
		/usr/share/elasticsearch/logs \
		/usr/share/elasticsearch/config \
		/usr/share/elasticsearch/config/scripts \
		/usr/share/elasticsearch/plugins \
	; do \
	mkdir -p "$path"; \
	done \
    && echo "Configure [Logstash] ========================================================" \
    && bundled='NODE="${DIR}/node/bin/node"' \
	&& apline_node='NODE="/usr/bin/node"' \
	&& sed -i "s|$bundled|$apline_node|g" /usr/share/kibana/bin/kibana-plugin \
	&& sed -i "s|$bundled|$apline_node|g" /usr/share/kibana/bin/kibana \
    && rm -rf /usr/share/kibana/node \
    && echo "Clean Up..." \
	&& rm -rf /tmp/* \
	&& apk del --purge .build-deps

ENV PATH /usr/share/elasticsearch/bin:$PATH
ENV PATH /usr/share/logstash/bin:$PATH
ENV PATH /usr/share/kibana/bin:$PATH
ENV JAVA_HOME /usr/lib/jvm/java-1.8-openjdk
