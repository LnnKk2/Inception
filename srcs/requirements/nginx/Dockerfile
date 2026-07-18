FROM debian:12

RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends nginx openssl && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/nginx/ssl

RUN mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -nodes \
    -out /etc/nginx/ssl/aandreo42.crt \
    -keyout /etc/nginx/ssl/aandreo42.key \
    -subj "/C=FR/ST=Seine-Maritime/L=Le-Havre/O=42/CN=aandreo42.42.fr"

COPY conf/nginx.conf /etc/nginx/conf.d/default.conf

RUN rm -f /etc/nginx/sites-enabled/default

EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]