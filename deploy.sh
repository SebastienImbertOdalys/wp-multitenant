#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}WordPress 7 Multisite Deployment${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Load environment variables
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

source .env

# Step 1: Start containers
echo -e "\n${YELLOW}[1/5]${NC} Starting Docker containers..."
docker-compose down 2>/dev/null || true
docker-compose up -d

# Step 2: Wait for services to be ready
echo -e "\n${YELLOW}[2/5]${NC} Waiting for services to be ready..."
sleep 15
for i in {1..30}; do
    if docker-compose exec -T mysql mariadb -u root --password="${DB_ROOT_PASSWORD}" -e "SELECT 1;" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ MySQL is ready${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}MySQL failed to start${NC}"
        exit 1
    fi
    sleep 2
done

# Wait for WordPress FPM to be ready
sleep 10

# Step 3: Check if multisite is already activated
echo -e "\n${YELLOW}[3/5]${NC} Checking multisite activation..."
MULTISITE_ACTIVE=$(docker-compose exec -T wpcli wp --allow-root core is-installed --network 2>/dev/null || echo "0")

if [ "$MULTISITE_ACTIVE" != "1" ]; then
    echo "Installing WordPress multisite..."
    
    # Make wp-config.php writable for multisite setup
    docker-compose exec -T wordpress chmod 666 /var/www/html/wp-config.php
    
    # Install multisite
    docker-compose exec -T wpcli wp --allow-root core multisite-install \
        --url="http://${DOMAIN_CURRENT_SITE}" \
        --subdomains \
        --title="WordPress Multisite Network" \
        --admin_user="${WORDPRESS_ADMIN_USER}" \
        --admin_password="${WORDPRESS_ADMIN_PASSWORD}" \
        --admin_email="${WORDPRESS_ADMIN_EMAIL}" \
        --skip-email 2>&1 | grep -v "Could not be written"
    
    # Ensure multisite constants are present with the expected values
    docker-compose exec -T wpcli wp --allow-root config set WP_ALLOW_MULTISITE true --raw >/dev/null 2>&1 || true
    docker-compose exec -T wpcli wp --allow-root config set MULTISITE true --raw >/dev/null 2>&1 || true
    docker-compose exec -T wpcli wp --allow-root config set SUBDOMAIN_INSTALL true --raw >/dev/null 2>&1 || true
    docker-compose exec -T wpcli wp --allow-root config set DOMAIN_CURRENT_SITE "${DOMAIN_CURRENT_SITE}" >/dev/null 2>&1 || true
    docker-compose exec -T wpcli wp --allow-root config set PATH_CURRENT_SITE / >/dev/null 2>&1 || true
    docker-compose exec -T wpcli wp --allow-root config set SITE_ID_CURRENT_SITE 1 --raw >/dev/null 2>&1 || true
    docker-compose exec -T wpcli wp --allow-root config set BLOG_ID_CURRENT_SITE 1 --raw >/dev/null 2>&1 || true
    
    echo -e "${GREEN}✓ Multisite installed${NC}"
else
    echo -e "${GREEN}✓ Multisite already active${NC}"
fi

# Step 4: Create network sites
echo -e "\n${YELLOW}[4/5]${NC} Creating network sites..."

IFS=',' read -ra SITES <<< "$NETWORK_SITES"
for SITE in "${SITES[@]}"; do
    SITE=$(echo $SITE | xargs) # trim whitespace
    
    # Check if site already exists
    if docker-compose exec -T wpcli wp --allow-root site list --field=url | grep -q "${SITE}.${DOMAIN_CURRENT_SITE}"; then
        echo "Site ${SITE}.${DOMAIN_CURRENT_SITE} already exists"
    else
        echo "Creating site: ${SITE}.${DOMAIN_CURRENT_SITE}"
        docker-compose exec -T wpcli wp --allow-root site create \
            --slug="${SITE}" \
            --title="Site ${SITE}" \
            --email="${WORDPRESS_ADMIN_EMAIL}"
        echo -e "${GREEN}✓ Created ${SITE}.${DOMAIN_CURRENT_SITE}${NC}"
    fi
done

# Step 4b: Activate local Gutenberg plugin if available
if [ -d "./wordpress/wp-content/plugins/mon-bloc" ]; then
    echo -e "\n${YELLOW}[4b/5]${NC} Activating plugin mon-bloc..."
    docker-compose exec -T wpcli wp --allow-root plugin activate mon-bloc >/dev/null 2>&1 || true
    echo -e "${GREEN}✓ Plugin mon-bloc activated${NC}"
fi

# Step 5: Display deployment information
echo -e "\n${YELLOW}[5/5]${NC} Deployment complete!"
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ WordPress 7 Multisite Network${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${YELLOW}Super Admin Dashboard:${NC}"
echo -e "  ${GREEN}http://${DOMAIN_CURRENT_SITE}:${HTTP_PORT}/wp-admin/${NC}"

echo -e "\n${YELLOW}Network Sites:${NC}"
IFS=',' read -ra SITES <<< "$NETWORK_SITES"
for SITE in "${SITES[@]}"; do
    SITE=$(echo $SITE | xargs)
    echo -e "  ${GREEN}http://${SITE}.${DOMAIN_CURRENT_SITE}:${HTTP_PORT}/${NC}"
done

echo -e "\n${YELLOW}Admin Credentials:${NC}"
echo -e "  Username: ${GREEN}${WORDPRESS_ADMIN_USER}${NC}"
echo -e "  Password: ${GREEN}${WORDPRESS_ADMIN_PASSWORD}${NC}"

echo -e "\n${YELLOW}Database Info:${NC}"
echo -e "  Host: ${GREEN}mysql:3306${NC}"
echo -e "  Database: ${GREEN}${DB_NAME}${NC}"
echo -e "  User: ${GREEN}${DB_USER}${NC}"
echo -e "  Root Password: ${GREEN}${DB_ROOT_PASSWORD}${NC}"

echo -e "\n${YELLOW}Local DNS Setup (macOS):${NC}"
echo -e "  ${BLUE}sudo nano /etc/hosts${NC}"
echo -e "  Add the following lines:"
echo -e "  ${GREEN}127.0.0.1 ${DOMAIN_CURRENT_SITE}${NC}"
IFS=',' read -ra SITES <<< "$NETWORK_SITES"
for SITE in "${SITES[@]}"; do
    SITE=$(echo $SITE | xargs)
    echo -e "  ${GREEN}127.0.0.1 ${SITE}.${DOMAIN_CURRENT_SITE}${NC}"
done

echo -e "\n${YELLOW}Useful Commands:${NC}"
echo -e "  View logs:          ${BLUE}docker-compose logs -f${NC}"
echo -e "  List network sites: ${BLUE}docker-compose exec wpcli wp --allow-root site list${NC}"
echo -e "  Create new site:    ${BLUE}docker-compose exec wpcli wp --allow-root site create --slug=newsite --title='New Site'${NC}"
echo -e "  Stop containers:    ${BLUE}docker-compose stop${NC}"
echo -e "  Remove all data:    ${BLUE}docker-compose down -v${NC}"

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
