#!/bin/sh
set -eu

# On a volume without an installed instance the entrypoint would start Apache with the web installer open to every client.
if [ "$(basename "$(dirname "$0")")" = before-starting ] \
    && ! php -r 'include "/var/www/html/config/config.php"; exit(($CONFIG["installed"] ?? false) === true ? 0 : 1);' >/dev/null 2>&1; then
  echo "Nextcloud is not installed on this volume. After a loss: restore the volume from the backup."
  echo "For a first install: set NEXTCLOUD_ADMIN_USER and NEXTCLOUD_ADMIN_PASSWORD, and remove version.php."
  exit 1
fi

# The next hook and the first requests need the database and the cache.
until php -r 'new PDO("pgsql:host=" . getenv("POSTGRES_HOST") . ";dbname=" . getenv("POSTGRES_DB"), getenv("POSTGRES_USER"), getenv("POSTGRES_PASSWORD"));' >/dev/null 2>&1; do
  echo "Waiting for the database"
  sleep 5
done
until php -r '$r = new Redis(); $r->connect(getenv("VALKEY_HOST"), 6379, 3) || exit(1); $r->auth(getenv("VALKEY_PASSWORD")) || exit(1);' >/dev/null 2>&1; do
  echo "Waiting for Valkey"
  sleep 5
done

# A file mounted into config/ would make the directory root-owned and stop the image from seeding its own config files.
install -m 0640 "$(dirname "$0")/cluster.config.php" /var/www/html/config/zz-cluster.config.php
