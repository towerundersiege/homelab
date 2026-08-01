#!/usr/bin/env bash
# Export the live database and wp-content from Chertsey. SSH sudo is requested
# on the remote terminal; the exported files are created only on this machine.
set -euo pipefail

destination=${1:-"/private/tmp/londonkerry-export-$(date +%Y%m%d-%H%M%S)"}
mkdir -p "$destination"
chmod 700 "$destination"

echo 'Chertsey may prompt for its sudo password twice. The site remains online.'
ssh -tt chertsey \
  'sudo docker exec londonkerry-db sh -ec '\''exec mariadb-dump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --quick --routines --triggers wordpress'\''' \
  > "$destination/wordpress.sql"

ssh -tt chertsey \
  'sudo docker cp londonkerry-wordpress:/var/www/html/londonkerry/wp-content -' \
  | tar -x -C "$destination"

tar -C "$destination" -czf "$destination/wp-content.tar.gz" wp-content
rm -rf "$destination/wp-content"
chmod 600 "$destination/wordpress.sql" "$destination/wp-content.tar.gz"
echo "Export completed: $destination"
