# Inception — User Documentation

This guide explains how to use the Inception stack as an end user or administrator. No Docker knowledge is required — every action goes through the browser or a single `make` command run from the root of the repository, inside the virtual machine.

## 1. What services does the stack provide?

The project runs a complete WordPress website, served securely over HTTPS. It is made of three cooperating services:

| Service     | What it does                                                        |
|-------------|---------------------------------------------------------------------|
| `nginx`     | The front door: receives your HTTPS requests on port 443            |
| `wordpress` | The website itself (WordPress running on PHP-FPM)                   |
| `mariadb`   | The database where all posts, pages, users and settings are stored  |

Only `nginx` is reachable from outside; the other two services are internal.

## 2. Starting and stopping the project

All commands are run from the root of the repository:

| Action                          | Command       | Notes                                                        |
|---------------------------------|---------------|--------------------------------------------------------------|
| Start (or restart) everything   | `make`        | The first start takes a few minutes: images are built and WordPress installs itself |
| Stop                            | `make down`   | Containers stop; **your data is kept**                       |
| Rebuild from scratch            | `make re`     | ⚠️ Deletes all data, then rebuilds and reinstalls            |
| Stop and delete everything      | `make fclean` | ⚠️ Removes containers, images **and all website/database data** |

After `make down`, running `make` again brings the site back exactly as you left it.

## 3. Accessing the website and the administration panel

- **Website**: open `https://aandreo42.42.fr` in a browser **inside the VM**.
  The certificate is self-signed, so the browser shows a security warning — this is expected for this project. Click "Advanced" and proceed to the site.
- **Administration panel**: `https://aandreo42.42.fr/wp-admin`
  Log in with the administrator account: the username is the `ADMIN_NAME` value from `srcs/.env`, and the password is the content of `secrets/wordpress_admin_password.txt`.
- A second, non-administrator account also exists (username `SCND_USER_NAME` from `srcs/.env`, password in `secrets/wordpress_scnduser_password.txt`). It can write posts but cannot manage the site.

If the address does not load at all, check that `/etc/hosts` contains the line `127.0.0.1 aandreo42.42.fr`.

## 4. Locating and managing credentials

Credentials are **never stored in git**. They live in two places at the root of the repository:

- `srcs/.env` — non-sensitive values: domain name, database name, usernames and email addresses.
- `secrets/` — one file per password:

| File                                      | Password for                                  |
|-------------------------------------------|-----------------------------------------------|
| `secrets/wordpress_admin_password.txt`    | The WordPress administrator account           |
| `secrets/wordpress_scnduser_password.txt` | The second WordPress user                     |
| `secrets/db_root_password.txt`            | The MariaDB `root` account (internal use)     |
| `secrets/db_user_password.txt`            | The database user WordPress connects with     |
| `secrets/wordpress_db_password.txt`       | Same value as above, read by the WordPress side |

To change a **WordPress** password after installation, use the admin panel (Users → Profile → New password) — this is the recommended way. The files in `secrets/` are read once, during the very first installation: editing them afterwards does not change an already-installed site. To start over with brand-new credentials, edit the files and run `make fclean` followed by `make` (this erases all content).

## 5. Checking that the services are running correctly

- `make ps` — the three services (`nginx`, `wordpress`, `mariadb`) must show an `Up` status.
- `docker logs nginx` (or `wordpress`, or `mariadb`) — shows what a service is doing; recent errors appear at the bottom.
- `curl -kI https://aandreo42.42.fr` — must answer with an HTTP success response.
- Open the website: if the WordPress home page loads and you can log in to `/wp-admin`, the whole chain (nginx → wordpress → mariadb) is working.

The containers are configured to restart automatically if they ever crash, so a service that disappears from `make ps` should come back on its own within seconds. If something stays broken, `make re` rebuilds a clean environment (at the cost of the stored data).