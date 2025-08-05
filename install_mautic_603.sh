#!/bin/bash

set -e

# 1. System Update & Core Packages
sudo apt update && sudo apt upgrade -y
sudo apt install -y software-properties-common lsb-release ca-certificates apt-transport-https gnupg curl unzip git zip

# 2. PHP 8.1
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update
sudo apt install -y php8.1 php8.1-cli php8.1-imap php8.1-fpm php8.1-mysql php8.1-curl php8.1-gd \
php8.1-mbstring php8.1-xml php8.1-zip php8.1-bcmath php8.1-intl libapache2-mod-php8.1

# 3. Apache
sudo apt install -y apache2
sudo a2enmod rewrite php8.1
sudo systemctl enable apache2

# 4. MariaDB
sudo apt install -y mariadb-server
sudo systemctl enable mariadb
sudo systemctl start mariadb

# 5. Database setup
sudo mysql -e "DROP DATABASE IF EXISTS mautic_db;
CREATE DATABASE mautic_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
DROP USER IF EXISTS 'mamghar001'@'localhost';
CREATE USER 'mamghar001'@'localhost' IDENTIFIED BY 'MoeScale123';
GRANT ALL PRIVILEGES ON mautic_db.* TO 'mamghar001'@'localhost';
FLUSH PRIVILEGES;"

# 6. Node.js (for assets)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# 7. Composer (for Mautic deps)
cd ~
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php --install-dir=/usr/local/bin --filename=composer
rm composer-setup.php

# 8. Clone Mautic
sudo git clone https://github.com/mautic/mautic.git /var/www/html/mautic
cd /var/www/html/mautic
sudo git checkout tags/6.0.3 -b v6.0.3




# 10. Set permissions
sudo chown -R www-data:www-data /var/www/html/mautic
sudo find /var/www/html/mautic -type f -exec chmod 644 {} \;
sudo find /var/www/html/mautic -type d -exec chmod 755 {} \;
chmod +x /var/www/html/mautic/bin/console
# Set ownership recursively (fast and safe)
chown -R www-data:www-data /var/www/html/mautic

# Set directories to 755 and files to 644 (much faster with xargs)
find /var/www/html/mautic -type d -print0 | xargs -0 chmod 755
find /var/www/html/mautic -type f -print0 | xargs -0 chmod 644

# Clean cache quickly
rm -rf /var/www/html/mautic/var/cache/prod/*


# 9. Composer install
cd /var/www/html/mautic && composer install 

# 11. Apache VirtualHost
sudo bash -c 'cat > /etc/apache2/sites-available/000-default.conf' <<EOF
<VirtualHost *:80>
    ServerAdmin admin@localhost
    DocumentRoot /var/www/html/mautic
    <Directory /var/www/html/mautic>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# 12. Remove PHP block in .htaccess
sudo sed -i '/<FilesMatch "\\.php\$">/,/<\/FilesMatch>/ s/^/#/' /var/www/html/mautic/.htaccess || true

# 13. PHP settings
PHPINI="/etc/php/8.1/apache2/php.ini"
sudo sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 64M/' $PHPINI
sudo sed -i 's/^post_max_size = .*/post_max_size = 64M/' $PHPINI
sudo sed -i 's/^memory_limit = .*/memory_limit = -1/' $PHPINI
sudo sed -i 's/^max_execution_time = .*/max_execution_time = 300/' $PHPINI
sudo sed -i 's/^max_input_time = .*/max_input_time = 300/' $PHPINI

# 14. Restart Apache
sudo systemctl restart apache2

# 15. Final Reminder
echo "✅ Mautic v6.0.3 is installed."
echo "👉 Go to: http://$(curl -s ifconfig.me) and complete the setup in the browser."

