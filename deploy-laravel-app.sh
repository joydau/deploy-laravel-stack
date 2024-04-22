#!/bin/bash

##########################################
# Author: Joy Daudu
# Cloud Engineering Track
#
##########################################

# Variables Needed
DB_USER="user_laravel"
DB_PASSWORD="password"
DB_NAME="db_laravel"
PROJECT_NAME="laravel"
DOCUMENT_ROOT="/var/www/html/$PROJECT_NAME/public"

# Check if running as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root"
    exit 1
fi

install_packages() {
    # Define the packages to install
    local packages=("apache2" "mysql-server" "php" "git" "unzip" "php-zip" "php-mysql" "php-xml" "php-curl" "php-mbstring")

    echo "Updating package lists..."
    if ! sudo apt update; then
        echo "Failed to update package lists. Aborting installation."
        return 1
    fi

    # Loop through each package and install it
    for package in "${packages[@]}"; do
        echo "Installing $package..."
        if ! sudo apt -y install "$package"; then
            echo "Failed to install $package. Aborting installation."
            return 1
        fi
    done

    echo "Installation completed successfully."
    return 0
}

# Function to install Composer
install_composer() {
    php -r "copy('http://getcomposer.org/installer', 'composer-setup.php');" &&
    php composer-setup.php &&
    sudo mv composer.phar /usr/local/bin/composer
    return 0
}

# Function to clone Laravel project
clone_laravel_project() {
    sudo rm -rf /var/www/html/*
    sudo chown -R $USER:$USER /var/www/html
    git clone https://github.com/laravel/laravel.git "/var/www/html/$PROJECT_NAME"
    return 0
}

# Function to install Laravel project dependencies
install_dependencies() {
    cd "/var/www/html/$PROJECT_NAME" || return 1
    composer install
    return 0
}

# Function to configure Laravel environment
configure_environment() {
    cp .env.example .env
    php artisan key:generate --no-interaction
    return 0
}

# Function to set permissions
set_permissions() {
    sudo chown -R www-data:www-data "/var/www/html/$PROJECT_NAME/storage"
    return 0
}

# Function to create MySQL database and user
create_database() {
    sudo mysql -uroot <<EOF
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON *.* TO '$DB_USER'@'localhost';
CREATE DATABASE $DB_NAME;
EOF
    return 0
}

# Function to configure database in the .env file
configure_database() {
    sed -i "s/DB_CONNECTION=sqlite/DB_CONNECTION=mysql\nDB_HOST=127.0.0.1\nDB_PORT=3306\nDB_DATABASE=$DB_NAME\nDB_USERNAME=$DB_USER\nDB_PASSWORD=$DB_PASSWORD/" .env
    return 0
}

# Function to run database migrations
run_migrations() {
    cd "/var/www/html/$PROJECT_NAME" || return 1
    php artisan migrate --no-interaction
    return 0
}

# Function to configure Apache
configure_apache() {
    echo "Configuring Apache..."
    if ! sudo bash -c "cat > /etc/apache2/sites-available/$PROJECT_NAME.conf <<EOF
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot $DOCUMENT_ROOT

    <Directory $DOCUMENT_ROOT>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF"; then
        echo "Failed to configure Apache. Aborting setup."
        return 1
    fi

    echo "Disabling default Apache site..."
    if ! sudo a2dissite 000-default.conf; then
        echo "Failed to disable default Apache site. Aborting setup."
        return 1
    fi

    echo "Enabling project Apache site..."
    if ! sudo a2ensite $PROJECT_NAME.conf; then
        echo "Failed to enable project Apache site. Aborting setup."
        return 1
    fi

    echo "Reloading Apache..."
    if ! sudo systemctl reload apache2; then
        echo "Failed to reload Apache. Aborting setup."
        return 1
    fi

    echo "Apache configuration completed successfully."
    return 0
}

# Main function
main() {
    if install_packages && setup_laravel && configure_apache; then
        echo "Installation and configuration completed successfully."
    else
        echo "Installation failed."
        return 1
    fi
}

# Execute main function
main
