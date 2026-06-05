#!/bin/bash

set -e

# Load environment
source /Users/Admin/Sites/wp-multitenant/.env

echo "Installing WordPress..."
docker-compose -f /Users/Admin/Sites/wp-multitenant/docker-compose.yml exec -T wpcli wp --allow-root core install \
  --url="http://${DOMAIN_CURRENT_SITE}:${HTTP_PORT}" \
  --title="WordPress Multisite Network" \
  --admin_user="${WORDPRESS_ADMIN_USER}" \
  --admin_password="${WORDPRESS_ADMIN_PASSWORD}" \
  --admin_email="${WORDPRESS_ADMIN_EMAIL}" \
  --skip-email

echo "Converting to multisite..."
docker-compose -f /Users/Admin/Sites/wp-multitenant/docker-compose.yml exec -T wpcli wp --allow-root multisite-convert --subdomains

echo "Creating network sites..."
IFS=',' read -ra SITES <<< "${NETWORK_SITES}"
for SITE in "${SITES[@]}"; do
  SITE=$(echo $SITE | xargs)
  echo "Creating ${SITE}..."
  docker-compose -f /Users/Admin/Sites/wp-multitenant/docker-compose.yml exec -T wpcli wp --allow-root site create \
    --slug="${SITE}" \
    --title="Site ${SITE}" \
    --email="${WORDPRESS_ADMIN_EMAIL}"
done

echo "Done!"
