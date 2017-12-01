FROM seancheung/nodestack:bare
LABEL maintainer="Sean Cheung <theoxuanx@gmail.com>"

COPY supervisord.conf /etc/supervisor/
COPY entrypoint.sh /entrypoint.sh

VOLUME [ "/var/opt/mysql", "/var/opt/redis", "/var/opt/mongodb", "/var/opt/elasticsearch", "/var/opt/logstash"]
EXPOSE 3306 6379 27017 9200 9300 5601 

ENTRYPOINT ["/entrypoint.sh"]

CMD ["/usr/bin/supervisord","-c", "/etc/supervisor/supervisord.conf"]