FROM debian:12

RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends mariadb-server && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY conf/99-server.cnf /etc/mysql/mariadb.conf.d/

COPY tools/setup.sh /usr/local/bin/

RUN chmod +X /usr/local/bin/setup.sh

EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/setup.sh"]
