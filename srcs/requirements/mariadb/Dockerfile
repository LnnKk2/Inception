FROM debian:12

RUN DEBIAN_FRONTED=noninteractive apt-get update && apt-get install -y --no-install-recommends mariadb-server && apt-get clean && rm -rf /var/lib/apt/lists/*