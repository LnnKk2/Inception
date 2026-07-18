# Inception — Developer Documentation

## 1. Prerequisites

- A Linux virtual machine (the project is developed and evaluated inside a VM) with `sudo` rights.
- Docker Engine and the Docker Compose v2 plugin (`docker compose version` must work).
- `make` and `git`.

## 2. Repository layout

```
.
├── Makefile                              # entry point: drives docker compose
├── secrets/                              # ⚠ not in git — password files (see 3.3)
└── srcs/
    ├── docker-compose.yml                # 3 services, 1 network, 2 named volumes, 5 secrets
    ├── .env                              # ⚠ not in git — configuration (see 3.2)
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile                # debian:12 + mariadb-server
        │   ├── conf/99-server.cnf        # bind-address = 0.0.0.0
        │   └── tools/setup.sh            # first-boot init, then exec mysqld (PID 1)
        ├── nginx/
        │   ├── Dockerfile                # debian:12 + nginx + openssl (self-signed cert at build)
        │   └── conf/nginx.conf           # 443 ssl, TLSv1.2/1.3, fastcgi_pass wordpress:9000
        └── wordpress/
            ├── Dockerfile                # debian:12 + php8.2-fpm + WP-CLI
            ├── conf/www.conf             # php-fpm pool, listen = 9000
            └── tools/setup.sh            # waits for DB, installs WP once, exec php-fpm (PID 1)
```

`srcs/.env`, `secrets/` and the data directory are listed in `.gitignore` and must be created locally before the first run.

## 3. Setting up the environment from scratch

### 3.1 Clone

```bash
git clone https://github.com/LnnKk2/Inception.git && cd Inception
```

### 3.2 Create `srcs/.env`

All non-sensitive configuration. Example (adapt the values):

```env
DOMAIN_NAME=aandreo42.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wp_user
WEBSITE_NAME=Inception
ADMIN_NAME=aandreo
ADMIN_EMAIL=aandreo@student.42.fr
SCND_USER_NAME=jdoe
SCND_USER_EMAIL=jdoe@student.42.fr
```

Constraints: `ADMIN_NAME` is the WordPress administrator and **must not contain `admin` or `administrator` in any form** (subject requirement). `MYSQL_USER` must not be `root`.

### 3.3 Create the secrets

Five files, each containing a single password on one line:

```bash
mkdir -p secrets
echo 'CHANGE_ME_root'  > secrets/db_root_password.txt
echo 'CHANGE_ME_db'    > secrets/db_user_password.txt
echo 'CHANGE_ME_db'    > secrets/wordpress_db_password.txt
echo 'CHANGE_ME_wpadm' > secrets/wordpress_admin_password.txt
echo 'CHANGE_ME_user'  > secrets/wordpress_scnduser_password.txt
chmod 600 secrets/*.txt
```

| File                          | Consumed by | Purpose                                        |
|-------------------------------|-------------|------------------------------------------------|
| `db_root_password.txt`        | mariadb     | Password set on `root@localhost`               |
| `db_user_password.txt`        | mariadb     | Password set on the `$MYSQL_USER` account      |
| `wordpress_db_password.txt`   | wordpress   | Password WordPress uses to connect as `$MYSQL_USER` |
| `wordpress_admin_password.txt`| wordpress   | WordPress administrator account                |
| `wordpress_scnduser_password.txt` | wordpress | Second WordPress user (author role)          |

> **Important:** `db_user_password.txt` and `wordpress_db_password.txt` are two sides of the same credential (MariaDB sets it, WordPress uses it). **They must contain exactly the same value**, otherwise WordPress can never connect to the database.

### 3.4 Domain resolution

```bash
echo "127.0.0.1 aandreo42.42.fr" | sudo tee -a /etc/hosts
```

## 4. Building and launching (Makefile + Docker Compose)

Everything goes through `docker compose -p inception -f srcs/docker-compose.yml`, wrapped by the Makefile:

| Target        | Effect                                                                              |
|---------------|-------------------------------------------------------------------------------------|
| `make` / `make up` | Creates `/home/aandreo42/data/{mariadb,wordpress}` then `compose up -d --build` |
| `make build`  | Builds the three images without starting them                                        |
| `make down`   | Stops and removes containers + network (volumes and data untouched)                  |
| `make clean`  | Same as `down`, also removing orphan containers                                      |
| `make fclean` | `down -v --rmi all` + `sudo rm -rf` of the host data directories — full wipe         |
| `make re`     | `fclean` then `up`                                                                   |
| `make ps`     | Compose status of the three services                                                 |

For manual commands, define once:

```bash
COMPOSE="docker compose -p inception -f srcs/docker-compose.yml"
```

**What happens on the first `make`:** the three images are built from `debian:12`; `mariadb` bootstraps its datadir, creates the database, the application user and the root password from the secrets, then re-executes `mysqld` in the foreground; `wordpress` waits for the database, downloads WordPress with WP-CLI, generates `wp-config.php`, installs the site and creates the two users, then executes `php-fpm8.2 -F`; `nginx` serves `https://$DOMAIN_NAME` and forwards `.php` requests to `wordpress:9000`. Subsequent starts skip every installation step (init scripts are idempotent).

## 5. Managing containers and volumes

Container names are fixed (`nginx`, `wordpress`, `mariadb`), so plain `docker` commands work directly:

```bash
$COMPOSE ps                              # status
docker logs -f wordpress                 # follow a service's logs
$COMPOSE up -d --build nginx             # rebuild and restart a single service
docker exec -it wordpress bash           # shell inside a container
docker exec -it wordpress wp user list --allow-root          # WP-CLI (workdir is /var/www/html)
docker exec -it mariadb mysql -u root -p"$(cat secrets/db_root_password.txt)" "$MYSQL_DATABASE"
docker volume ls --filter name=inception # inception_db_data, inception_wp_data
docker volume inspect inception_wp_data  # shows the bind device under /home/aandreo42/data
docker network inspect inception_inception
```

(Compose prefixes volume and network names with the project name `inception`.)

**Testing the restart policy:** `restart: always` reacts to crashes, not to manual stops — `docker stop`/`docker kill` go through the Docker API and deliberately cancel the restart. To simulate a real crash:

```bash
sudo kill -9 "$(docker inspect -f '{{.State.Pid}}' wordpress)"
docker ps        # the container is back Up with a fresh uptime
```

## 6. Where the data is stored and how it persists

Two **named volumes** are declared in `docker-compose.yml`, using the `local` driver with bind options so their data lives at the location required by the subject:

| Volume (Compose name)      | Host location                    | Mounted in container(s)                     |
|----------------------------|----------------------------------|---------------------------------------------|
| `db_data` (`inception_db_data`) | `/home/aandreo42/data/mariadb`   | `mariadb` → `/var/lib/mysql`                |
| `wp_data` (`inception_wp_data`) | `/home/aandreo42/data/wordpress` | `wordpress` and `nginx` → `/var/www/html`   |

`nginx` shares `wp_data` so it can serve static files directly while `php-fpm` executes the PHP in the same tree. Secrets are mounted read-only at `/run/secrets/<name>` inside the services that declare them.

Persistence rules:

- `make down`, a VM reboot or a container crash **never** touch the data: on restart, the init scripts detect the existing state (`/var/lib/mysql/mysql` for MariaDB, `wp-config.php` for WordPress) and skip installation.
- The host directories must exist before `up` — the Makefile creates them, which is why the stack should always be started through `make`.
- Only `make fclean` destroys the data: it removes the named volumes **and** deletes `/home/aandreo42/data/{mariadb,wordpress}` on the host.