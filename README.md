# WordPress 7 Multisite Docker Deployment

Configuration Docker complète pour un réseau WordPress 7 multisite avec support des sous-domaines.

## 📋 Prérequis

- Docker & Docker Compose (v3.8+)
- macOS, Linux ou WSL2
- Python 3.9+ (optionnel, pour utilitaires)
- Minimum 4 GB RAM disponible

## 🚀 Démarrage rapide

### 1. Configuration initiale

```bash
# Copier le fichier d'environnement
cp .env.example .env

# Éditer les paramètres (optionnel)
# Personnalisez les identifiants de base de données, port, etc.
```

### 2. Lancer le déploiement

```bash
# Rendre le script exécutable (une seule fois)
chmod +x deploy.sh

# Exécuter le déploiement
./deploy.sh
```

Le script va :
- ✓ Démarrer les conteneurs (MariaDB, WordPress, Nginx, WP-CLI)
- ✓ Initialiser WordPress
- ✓ Activer le mode multisite (sous-domaines)
- ✓ Créer les sites initiaux configurés dans `NETWORK_SITES`
- ✓ Afficher les URLs et identifiants d'accès

### 3. Configuration DNS locale (macOS)

```bash
# Éditer le fichier hosts
sudo nano /etc/hosts

# Ajouter les lignes suivantes (adapter les domaines selon config)
127.0.0.1 boom.local
127.0.0.1 odalys-vacances.boom.local
127.0.0.1 odalys-city.boom.local
```

Puis appuyer sur `Ctrl+X`, `Y`, `Entrée` pour enregistrer.

### 4. Accès

- **Super Admin Dashboard (recommandé)** : `http://boom.local/wp-admin/`
- **Site 1 (recommandé)** : `http://odalys-vacances.boom.local/`
- **Site 2 (recommandé)** : `http://odalys-city.boom.local/`
- **Accès alternatif** : les URLs avec `:8080` restent disponibles.

### 5. Données WordPress locales

Le dossier local `wordpress/` est un bind mount vers `/var/www/html`.
WordPress y est donc visible et éditable depuis VS Code (dont `wp-content/plugins`).

## 📁 Structure du projet

```
wp-multitenant/
├── docker-compose.yml       # Orchestration des conteneurs
├── deploy.sh               # Script d'initialisation
├── .env                    # Variables d'environnement (local)
├── .env.example            # Modèle de configuration
├── nginx/
│   ├── nginx.conf          # Configuration Nginx principale
│   └── conf.d/
│       └── wordpress.conf  # Configuration multisite
└── README.md               # Ce fichier
```

## 🔧 Gestion de la multisite

### Développement de bloc Gutenberg (mon-bloc)

```bash
# 1) Déployer la stack (génère ./wordpress au premier boot)
./deploy.sh

# 2) Créer/installer le bloc sur l'hôte puis l'activer via WP-CLI
chmod +x setup-block.sh
./setup-block.sh mon-bloc

# 3) Lancer le watcher pour hot reload
cd wordpress/wp-content/plugins/mon-bloc
npm start
```

Les fichiers source du bloc sont éditables ici:

```bash
wordpress/wp-content/plugins/mon-bloc/src/
```

### Créer un nouveau site réseau

```bash
docker-compose exec wpcli wp --allow-root site create \
    --slug=newsite \
    --title="Mon Nouveau Site" \
    --email="admin@boom.local"
```

### Lister tous les sites du réseau

```bash
docker-compose exec wpcli wp --allow-root site list
```

### Accéder à WP-CLI directement

```bash
docker-compose exec wpcli wp --allow-root [commande]
```

### Activer un plugin au niveau réseau

```bash
docker-compose exec wpcli wp --allow-root plugin activate [plugin-slug] --network
```

## 📦 Services inclus

| Service | Image | Port | Utilité |
|---------|-------|------|---------|
| **MariaDB** | `mariadb:11` | 3306 | Base de données |
| **WordPress** | `wordpress:7-php8.2-fpm` | 9000 | Moteur PHP-FPM |
| **Nginx** | `nginx:latest` | 8080 | Serveur web & proxy inverse |
| **WP-CLI** | `wordpress:cli-php8.2` | N/A | Gestion en ligne de commande |

## 🛠️ Commandes utiles

### Arrêter le déploiement

```bash
docker-compose stop
```

### Redémarrer les services

```bash
docker-compose restart
```

### Voir les logs en temps réel

```bash
docker-compose logs -f [service]
# Par exemple : docker-compose logs -f wordpress
```

### Supprimer toutes les données

```bash
docker-compose down -v
```

Note: `./deploy.sh` est non-destructif pour les volumes. La commande ci-dessus reste la commande de reset complet.

### Accéder à la base de données

```bash
docker-compose exec mysql mariadb -u wp_user -p wordpress_multisite
# Mot de passe : WpDbPass2024! (ou celui dans .env)
```

## 🌐 Configuration multisite avancée

### Mode sous-domaines (actuellement actif)

- **Structure** : `odalys-vacances.boom.local`, `odalys-city.boom.local`
- **Avantage** : Meilleure séparation, SEO simplifié, cookies partagés possibles
- **Nginx** : Règles wildcard activées

### Configuration Nginx appliquée

- Réécriture d'URLs multisite configurée
- Compression gzip activée
- Cache HTTP pour les fichiers statiques (365 jours)
- Headers de sécurité (X-Frame-Options, X-Content-Type-Options, etc.)
- Limite de taille upload : 20 MB
- Timeout PHP : 300s

## 🔒 Sécurité

- Variables sensibles stockées dans `.env` (non commitées)
- MariaDB accès local uniquement (port 3306 non exposé)
- FPM sur socket privée (non exposé)
- Headers de sécurité activés
- Accès aux fichiers sensibles bloqués (wp-config.php, .htaccess, etc.)

### À faire en production

- [ ] Utiliser des secrets Docker au lieu de `.env`
- [ ] Activer HTTPS/SSL (Let's Encrypt)
- [ ] Configurer des sauvegardes automatiques
- [ ] Implémenter une stratégie de logs centralisées
- [ ] Activer le WAF/IDS
- [ ] Restreindre les ports exposés

## 🐛 Dépannage

### Multisite n'est pas activé

```bash
# Vérifier le statut
docker-compose exec wpcli wp --allow-root core is-installed --network

# Réinstaller proprement le réseau (recommandé)
./deploy.sh
```

### Les sous-domaines ne résolvent pas

1. Vérifier `/etc/hosts` (macOS/Linux)
2. Vérifier que vous utilisez bien les URLs avec `:8080`
3. Vérifier le domaine demandé: ex. `newsite.boom.local` (et pas `newsite.local:8080`)
4. Relancer Nginx : `docker-compose restart nginx`

### Redirection vers `wp-signup.php?new=...:8080`

- Cause: en multisite, si PHP reçoit un host avec `:8080`, WordPress peut considérer que le site n'existe pas.
- Correctif appliqué: Nginx envoie désormais `HTTP_HOST` sans port vers PHP-FPM.
- Vérification rapide: `curl -I http://boom.local:8080/` doit retourner `HTTP/1.1 200 OK`.

### WordPress lent au premier accès

- Normal (premier démarrage PHP-FPM, migrations DB)
- Attendre 30-60 secondes
- Vérifier les logs : `docker-compose logs wordpress`

### Erreur de permission sur wp-content

```bash
# Corriger les permissions
docker-compose exec wordpress chown -R www-data:www-data /var/www/html
```

## 📝 Variables d'environnement

Voir `.env.example` pour la liste complète. Principales :

| Variable | Défaut | Description |
|----------|--------|-------------|
| `WORDPRESS_ADMIN_USER` | `admin` | Identifiant super-admin |
| `WORDPRESS_ADMIN_PASSWORD` | `WpMultisite2024!` | Mot de passe super-admin |
| `DB_NAME` | `wordpress_multisite` | Nom de la base |
| `DOMAIN_CURRENT_SITE` | `boom.local` | Domaine principal |
| `HTTP_PORT` | `8080` | Port HTTP local |
| `DEBUG` | `false` | Mode debug WordPress |
| `NETWORK_SITES` | `odalys-vacances,odalys-city` | Sites réseau à créer |

## 🧱 Bind Mounts et Persistance

- WordPress: bind mount `./wordpress:/var/www/html` (code visible sur l'hôte)
- Base de données: volume nommé `mysql_data` (persistance DB)

## 🤝 Support & Contributions

Pour les problèmes, consultez les logs ou ouvrez une issue.

## 📄 Licence

MIT

---

**Créé avec** WordPress 7 (Armstrong), PHP 8.2, Docker & Compose ❤️
