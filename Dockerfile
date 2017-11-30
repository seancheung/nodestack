FROM seancheung/nodestack:bare
LABEL maintainer="Sean Cheung <theoxuanx@gmail.com>"

COPY supervisord.conf /etc/supervisor/
COPY entrypoint.sh /entrypoint.sh

VOLUME [ "/var/opt/mysql" ]

ENTRYPOINT ["/entrypoint.sh"]

CMD ["/usr/bin/supervisord","-c", "/etc/supervisor/supervisord.conf"]