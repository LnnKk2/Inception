*This project has been created as part of the 42 curriculum by aandreo.*

# Inception

## Description

Inception is a system administration exercise about virtualizing a small web infrastructure with Docker, inside a personal virtual machine. Nothing is pulled ready-made: every service is built from its own Dockerfile on top of a bare Debian base image, and the whole stack is orchestrated with Docker Compose through a single Makefile.

The infrastructure is composed of three services, each running in its own dedicated container:

| Service     | Role                                                       | Exposure                          |
|-------------|------------------------------------------------------------|-----------------------------------|
| `nginx`     | Web server and TLS termination (TLSv1.2 / TLSv1.3 only)    | Port `443` — the only public entry |
| `wordpress` | WordPress + `php-fpm` (no web server inside the container) | Port `9000`, internal network only |
| `mariadb`   | Database server                                            | Port `3306`, internal network only |

NGINX is the single entry point: it serves the WordPress site over HTTPS at `https://aandreo42.42.fr` with a self-signed certificate and forwards PHP requests to the `wordpress` container over FastCGI. WordPress stores its content in MariaDB. The three containers communicate over a dedicated bridge network, two named volumes persist the database and the website files under `/home/aandreo42/data` on the host, and every container automatically restarts in case of a crash (`restart: always`).

### How Docker is used and what the repository contains

```
.
├── Makefile                     # builds and runs the whole stack through Docker Compose
├── secrets/                     # password files used as Docker secrets (ignored by git)
└── srcs/
    ├── docker-compose.yml       # services, network, named volumes, secrets
    ├── .env                     # non-sensitive configuration (ignored by git)
    └── requirements/
        ├── mariadb/             # Dockerfile, conf/99-server.cnf, tools/setup.sh
        ├── nginx/               # Dockerfile, conf/nginx.conf
        └── wordpress/           # Dockerfile, conf/www.conf, tools/setup.sh
```

Each service has its own Dockerfile (no pre-built application image is used), its configuration files in `conf/` and, when needed, an initialization script in `tools/`. The Dockerfiles are referenced by `docker-compose.yml`, which is itself driven by the Makefile. The exact contents expected in `srcs/.env` and `secrets/` are documented in [DEV_DOC.md](DEV_DOC.md).

### Main design choices

- **Debian 12 (bookworm) as base image** — the penultimate stable release as required by the subject (the current stable is Debian 13), pinned by version, never `latest`.
- **One service per container, one foreground process as PID 1.** The entrypoint scripts end with `exec mysqld` / `exec php-fpm8.2 -F`, and NGINX runs with `daemon off;`. The main process therefore receives signals correctly, shuts down cleanly, and Docker's restart policy reacts to real crashes — no `tail -f` / `sleep infinity` style hacks.
- **Idempotent initialization.** MariaDB is bootstrapped (database, users, passwords) only if its data directory is empty; WordPress is downloaded and installed with WP-CLI only if `wp-config.php` does not exist. Containers can be restarted or recreated without touching existing data.
- **Least exposure.** Only NGINX publishes a port (443). The MariaDB `root` account is restricted to `localhost` inside its container; WordPress uses a dedicated, limited database user over the internal network.
- **Separation of secrets and configuration.** Passwords live in Docker secrets (mounted read-only under `/run/secrets/`), non-sensitive settings live in `srcs/.env`. Both are ignored by git.

### Virtual Machines vs Docker

A virtual machine emulates a full computer: a hypervisor runs a complete guest operating system with its own kernel. This gives very strong isolation, at the cost of gigabytes of disk, significant RAM, and boot times measured in minutes. A Docker container, on the other hand, is just an isolated group of processes sharing the host's kernel (using Linux namespaces and cgroups): it starts in seconds, weighs a few hundred megabytes at most, and is easy to rebuild identically from a Dockerfile. Isolation is weaker than a VM's, which is why this project combines both: the VM provides a safe, disposable host system, and containers provide lightweight, reproducible packaging for each service inside it.

### Secrets vs Environment Variables

Environment variables are convenient for configuration but are a poor place for passwords: they are visible in `docker inspect`, in `/proc/<pid>/environ`, are inherited by every child process, and easily end up in logs. Docker secrets are instead mounted as in-memory files under `/run/secrets/<name>`, only inside the services that explicitly declare them, and do not appear in `docker inspect`. This project therefore uses secrets for every password (database root, database user, the two WordPress accounts) and keeps only non-sensitive values (domain name, database name, usernames, emails) in the `.env` file.

### Docker Network vs Host Network

With `network_mode: host`, a container shares the host's network stack directly: no isolation, every listening port is instantly exposed on the host, and containers cannot be addressed by name. A user-defined bridge network — as used here — gives each container its own network namespace, an embedded DNS server (containers reach each other by service name, e.g. `fastcgi_pass wordpress:9000`, `--dbhost=mariadb`), and only explicitly published ports are reachable from outside. In this project only `nginx` publishes `443`; `wordpress` and `mariadb` are unreachable from the host, which enforces the "NGINX is the sole entry point" rule. Host networking (and legacy `links:`) is forbidden by the subject anyway.

### Docker Volumes vs Bind Mounts

A bind mount maps an arbitrary host path into a container: simple, but entirely dependent on the host's directory layout and permissions, and invisible to Docker's own management. A named volume is created and managed by Docker (`docker volume ls / inspect`), referenced by name in the Compose file, and independent of where the data physically sits. The subject requires named volumes for the two persistent stores *and* requires the data to live in `/home/aandreo42/data`; both constraints are met by declaring named volumes (`db_data`, `wp_data`) that use the `local` driver with bind options pointing to that directory — they remain managed, named volumes while storing their data at the required host location.

## Instructions

The project must be run inside a virtual machine with Docker Engine, the Docker Compose v2 plugin, `make` and `sudo` available.

1. Clone the repository and enter it.
2. Create `srcs/.env` and the `secrets/` directory — both are ignored by git; their exact format is described in [DEV_DOC.md](DEV_DOC.md).
3. Make the domain resolve locally:
   ```bash
   echo "127.0.0.1 aandreo42.42.fr" | sudo tee -a /etc/hosts
   ```
4. Build and start everything:
   ```bash
   make
   ```
5. Open `https://aandreo42.42.fr` and accept the self-signed certificate.

Main Makefile targets: `make` (build + start), `make down` (stop, keep data), `make re` (full rebuild), `make fclean` (stop and **delete all data**), `make ps` (status). Day-to-day usage is covered in [USER_DOC.md](USER_DOC.md), development details in [DEV_DOC.md](DEV_DOC.md).

## Resources

- Dockerfile best practices — https://docs.docker.com/build/building/best-practices/
- Compose file reference — https://docs.docker.com/reference/compose-file/
- Docker volumes — https://docs.docker.com/engine/storage/volumes/
- Docker networking — https://docs.docker.com/engine/network/
- Secrets in Compose — https://docs.docker.com/compose/how-tos/use-secrets/
- NGINX: configuring HTTPS servers — https://nginx.org/en/docs/http/configuring_https_servers.html
- PHP-FPM documentation — https://www.php.net/manual/en/install.fpm.php
- MariaDB: `mariadb-install-db` — https://mariadb.com/kb/en/mariadb-install-db/
- WP-CLI commands — https://developer.wordpress.org/cli/commands/
- Docker and the PID 1 zombie reaping problem — https://blog.phusion.nl/2015/01/20/docker-and-the-pid-1-zombie-reaping-problem/

### How AI was used

AI assistance (Anthropic's Claude) was used at specific points of the project, always as a support tool rather than a code generator:

- **Understanding concepts**: PID 1 and signal handling in containers, how Docker restart policies behave, the difference between named volumes and bind mounts, and how Docker secrets work.
- **Debugging help**: for example, understanding why `docker kill` does not trigger `restart: always` (a manual stop through the Docker API deliberately bypasses the restart policy) while a real process crash does.
- **Compliance review**: once the stack was working, the repository was reviewed against the subject's requirements (base image version, forbidden patterns, TLS configuration, volume placement, absence of credentials in the git history).
- **Documentation**: drafting and structuring this README, `USER_DOC.md` and `DEV_DOC.md`.

All Dockerfiles, shell scripts and configuration files in this repository were written, tested and debugged by the author; AI output was systematically reviewed, tested and understood before any of it was used, in line with the school's AI guidelines.