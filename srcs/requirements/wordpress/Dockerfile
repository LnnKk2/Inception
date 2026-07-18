FROM debian:12

RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends php8.2-mysql php8.2-fpm curl tar && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar &&  chmod +x wp-cli.phar &&  mv wp-cli.phar /usr/local/bin/wp

RUN mkdir -p /run/php

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

COPY tools/setup.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/setup.sh

WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/setup.sh"]