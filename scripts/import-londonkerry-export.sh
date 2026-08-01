#!/usr/bin/env bash
# Restore an export made by export-londonkerry-chertsey.sh into the already
# Flux-deployed LondonKerry PVCs. This is intentionally not a Flux workload.
set -euo pipefail

export_dir=${1:?Usage: $0 /path/to/londonkerry-export-YYYYMMDD-HHMMSS}
for file in "$export_dir/wordpress.sql" "$export_dir/wp-content.tar.gz"; do
  [[ -f "$file" ]] || { echo "Missing export file: $file" >&2; exit 1; }
done

db_pod=$(kubectl -n londonkerry get pod -l app.kubernetes.io/name=mariadb \
  -o jsonpath='{.items[0].metadata.name}')
wp_pod=$(kubectl -n londonkerry get pod -l app.kubernetes.io/name=wordpress \
  -o jsonpath='{.items[0].metadata.name}')
kubectl -n londonkerry wait --for=condition=Ready "pod/$db_pod" "pod/$wp_pod" --timeout=10m

kubectl -n londonkerry cp "$export_dir/wordpress.sql" "$db_pod:/tmp/wordpress.sql"
kubectl -n londonkerry exec "$db_pod" -- sh -ec \
  'mariadb -u"$MARIADB_USER" -p"$MARIADB_PASSWORD" "$MARIADB_DATABASE" < /tmp/wordpress.sql; rm -f /tmp/wordpress.sql'

kubectl -n londonkerry cp "$export_dir/wp-content.tar.gz" "$wp_pod:/tmp/wp-content.tar.gz"
kubectl -n londonkerry exec "$wp_pod" -- sh -ec \
  'rm -rf /var/www/html/wp-content; tar -xzf /tmp/wp-content.tar.gz -C /var/www/html; chown -R www-data:www-data /var/www/html/wp-content; rm -f /tmp/wp-content.tar.gz'
kubectl -n londonkerry rollout restart deployment/wordpress
kubectl -n londonkerry rollout status deployment/wordpress --timeout=10m
echo 'Import completed. Test through port-forward before adding the Cloudflare Tunnel route.'
