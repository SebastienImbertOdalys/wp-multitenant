#!/bin/bash

set -e

PLUGIN_SLUG=${1:-mon-bloc}
PLUGIN_DIR="./wordpress/wp-content/plugins/${PLUGIN_SLUG}"

if [ ! -d "./wordpress/wp-content/plugins" ]; then
  echo "wordpress/wp-content/plugins n'existe pas encore. Lancez d'abord ./deploy.sh"
  exit 1
fi

if [ ! -d "${PLUGIN_DIR}" ]; then
  echo "Scaffolding du plugin ${PLUGIN_SLUG} avec @wordpress/create-block..."
  npx --yes @wordpress/create-block@latest "${PLUGIN_SLUG}" --variant dynamic --target-dir "${PLUGIN_DIR}"
fi

echo "Installation des dependances npm du bloc..."
if [ ! -f "${PLUGIN_DIR}/package.json" ]; then
  echo "Erreur: ${PLUGIN_DIR}/package.json introuvable"
  exit 1
fi

cd "${PLUGIN_DIR}"
npm install

echo "Activation du plugin via WP-CLI..."
cd /Users/Admin/Sites/wp-multitenant
docker-compose exec -T wpcli wp --allow-root plugin activate "${PLUGIN_SLUG}" || true

echo "OK: plugin ${PLUGIN_SLUG} pret."
echo "Lancez le watcher: cd ${PLUGIN_DIR} && npm start"
